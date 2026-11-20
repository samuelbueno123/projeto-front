import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../design_system/test_env_stub.dart'
    if (dart.library.io) '../design_system/test_env_io.dart';
import 'realtime_transport.dart';

enum RealtimeConnectionState { disconnected, connecting, connected }

class RealtimeEvent {
  final String type;
  final int? condominiumId;
  final dynamic data;
  final DateTime? timestamp;

  RealtimeEvent({
    required this.type,
    this.condominiumId,
    this.data,
    this.timestamp,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      type: json['type']?.toString() ?? 'UNKNOWN',
      condominiumId: json['condominiumId'] is num
          ? (json['condominiumId'] as num).toInt()
          : int.tryParse(json['condominiumId']?.toString() ?? ''),
      data: json['data'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }
}

/// Serviço Singleton para consumo de eventos SSE (Server-Sent Events) em tempo real
/// no Web (via Fetch ReadableStream) e Mobile/Desktop (via http.Client stream).
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  final StreamController<RealtimeEvent> _eventController =
      StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventController.stream;

  final StreamController<RealtimeConnectionState> _stateController =
      StreamController<RealtimeConnectionState>.broadcast();
  Stream<RealtimeConnectionState> get connectionState =>
      _stateController.stream;

  RealtimeConnectionState _currentState = RealtimeConnectionState.disconnected;
  RealtimeConnectionState get currentState => _currentState;
  RealtimeConnectionState get state => _currentState;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  String? _token;
  String? _lastEventId;
  SseTransportConnection? _connection;
  StreamSubscription<String>? _streamSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatWatchdog;
  final Random _jitterRandom = Random();
  int _retryCount = 0;
  bool _manualDisconnect = false;
  bool _disposed = false;
  int _connectionGeneration = 0;

  void setToken(String? token) {
    final cleanToken = token?.trim();
    if (_token == cleanToken &&
        _currentState == RealtimeConnectionState.connected) {
      return;
    }
    _token = cleanToken;
    _lastEventId = null;
    if (_token != null && _token!.isNotEmpty) {
      _manualDisconnect = false;
      connect();
    } else {
      disconnect();
    }
  }

  void connect() {
    if (_disposed || _token == null || _token!.isEmpty) return;
    if (_currentState == RealtimeConnectionState.connecting ||
        _currentState == RealtimeConnectionState.connected) {
      return;
    }
    _manualDisconnect = false;
    unawaited(_startSseStream());
  }

  Future<void> _startSseStream() async {
    if (isFlutterTestEnvironment()) return;
    final generation = ++_connectionGeneration;
    _cleanupConnectionOnly();
    _setState(RealtimeConnectionState.connecting);

    try {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/realtime/subscribe');
      final headers = <String, String>{
        'Authorization': 'Bearer $_token',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        if (_lastEventId != null && _lastEventId!.isNotEmpty)
          'Last-Event-ID': _lastEventId!,
      };

      final connection = await openSseConnection(uri: uri, headers: headers);
      if (_disposed ||
          _manualDisconnect ||
          generation != _connectionGeneration) {
        connection.close();
        return;
      }

      _connection = connection;
      _retryCount = 0;
      _setState(RealtimeConnectionState.connected);
      _resetHeartbeatWatchdog(generation);

      String currentEventName = '';
      final dataLines = <String>[];
      String? pendingEventId;

      void dispatchCurrentFrame() {
        if (dataLines.isEmpty) {
          currentEventName = '';
          return;
        }
        final payload = dataLines.join('\n');
        dataLines.clear();
        if (pendingEventId != null && pendingEventId!.isNotEmpty) {
          _lastEventId = pendingEventId;
        }
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final evt = RealtimeEvent.fromJson(decoded);
            if (!_disposed && !_eventController.isClosed) {
              _eventController.add(evt);
            }
          } else if (currentEventName.isNotEmpty) {
            if (!_disposed && !_eventController.isClosed) {
              _eventController.add(
                RealtimeEvent(type: currentEventName, data: decoded),
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('RealtimeService parse error: $e');
          }
        }
        currentEventName = '';
      }

      _streamSub = connection.byteStream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (rawLine) {
              if (generation != _connectionGeneration) return;
              _resetHeartbeatWatchdog(generation);

              final line = rawLine.endsWith('\r')
                  ? rawLine.substring(0, rawLine.length - 1)
                  : rawLine;

              if (line.isEmpty) {
                dispatchCurrentFrame();
                return;
              }
              if (line.startsWith(':')) {
                return;
              }
              if (line.startsWith('event:')) {
                currentEventName = line.substring(6).trim();
              } else if (line.startsWith('id:')) {
                final candidateId = line.substring(3).trim();
                if (!candidateId.contains('\u0000')) {
                  pendingEventId = candidateId;
                }
              } else if (line.startsWith('data:')) {
                var val = line.substring(5);
                if (val.startsWith(' ')) val = val.substring(1);
                dataLines.add(val);
              }
            },
            onError: (Object error) {
              if (generation != _connectionGeneration) return;
              if (kDebugMode) {
                debugPrint('RealtimeService SSE stream error: $error');
              }
              _setState(RealtimeConnectionState.disconnected);
              _scheduleReconnect();
            },
            onDone: () {
              if (generation != _connectionGeneration) return;
              dispatchCurrentFrame();
              _setState(RealtimeConnectionState.disconnected);
              _scheduleReconnect();
            },
            cancelOnError: true,
          );
    } on HttpStatusException catch (e) {
      if (generation != _connectionGeneration) return;
      _setState(RealtimeConnectionState.disconnected);
      if (e.statusCode != 401 && e.statusCode != 403) {
        _scheduleReconnect();
      }
    } catch (e) {
      if (generation != _connectionGeneration) return;
      if (kDebugMode) {
        debugPrint('RealtimeService connection error: $e');
      }
      _setState(RealtimeConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _resetHeartbeatWatchdog(int generation) {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = Timer(const Duration(seconds: 65), () {
      if (_disposed ||
          _manualDisconnect ||
          generation != _connectionGeneration) {
        return;
      }
      if (kDebugMode) {
        debugPrint('RealtimeService heartbeat timeout — reconnecting');
      }
      _cleanupConnectionOnly();
      _setState(RealtimeConnectionState.disconnected);
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    if (_disposed || _manualDisconnect || _token == null || _token!.isEmpty) {
      return;
    }
    _reconnectTimer?.cancel();

    final baseSeconds = min(30, 1 << min(_retryCount, 5));
    final jitterMs = _jitterRandom.nextInt(700);
    _retryCount++;

    _reconnectTimer = Timer(
      Duration(seconds: baseSeconds, milliseconds: jitterMs),
      () {
        if (!_disposed && !_manualDisconnect) {
          unawaited(_startSseStream());
        }
      },
    );
  }

  void _setState(RealtimeConnectionState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    if (!_disposed && !_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _cleanupConnectionOnly() {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = null;
    _streamSub?.cancel();
    _streamSub = null;
    _connection?.close();
    _connection = null;
  }

  void disconnect({bool clearToken = true}) {
    _manualDisconnect = true;
    _connectionGeneration++;
    if (clearToken) {
      _token = null;
      _lastEventId = null;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnectionOnly();
    _setState(RealtimeConnectionState.disconnected);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}
