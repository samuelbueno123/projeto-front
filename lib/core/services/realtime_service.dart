import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum RealtimeConnectionState { disconnected, connecting, connected }

class RealtimeEvent {
  final String type;
  final num? condominiumId;
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
      condominiumId: json['condominiumId'] as num?,
      data: json['data'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  @override
  String toString() => 'RealtimeEvent($type, condo: $condominiumId, data: $data)';
}

/// Serviço de sincronização em tempo real via Server-Sent Events (SSE).
/// Mantém uma única conexão HTTP streaming persistente e distribui eventos
/// para as telas (Chat da portaria, notificações, encomendas, avisos e reservas).
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  final _eventController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventController.stream;

  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  Stream<RealtimeConnectionState> get connectionState => _stateController.stream;

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  RealtimeConnectionState get state => _state;

  String? _token;
  bool _disposed = false;
  http.Client? _client;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  void setToken(String? token) {
    if (_token == token) return;
    _token = token;
    if (_token != null && _token!.isNotEmpty) {
      connect();
    } else {
      disconnect();
    }
  }

  void connect() {
    if (_disposed || _token == null || _token!.isEmpty) return;
    if (_state == RealtimeConnectionState.connecting || _state == RealtimeConnectionState.connected) {
      return;
    }
    _reconnectTimer?.cancel();
    _startSseStream();
  }

  Future<void> _startSseStream() async {
    _setState(RealtimeConnectionState.connecting);
    _client?.close();
    _client = http.Client();

    final url = Uri.parse('${ApiConfig.baseUrl}/realtime/events');
    final request = http.Request('GET', url);
    request.headers['Authorization'] = 'Bearer $_token';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    try {
      final response = await _client!.send(request);
      if (response.statusCode != 200) {
        _setState(RealtimeConnectionState.disconnected);
        _scheduleReconnect();
        return;
      }

      _setState(RealtimeConnectionState.connected);
      _reconnectAttempts = 0;

      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // Linha incompleta fica no buffer para o próximo chunk

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || line.startsWith(':')) {
            // Linha vazia ou heartbeat/ping do servidor
            continue;
          }
          if (line.startsWith('data:')) {
            final dataString = line.substring(5).trim();
            if (dataString.isNotEmpty) {
              try {
                final json = jsonDecode(dataString);
                if (json is Map<String, dynamic>) {
                  final event = RealtimeEvent.fromJson(json);
                  _eventController.add(event);
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Erro ao parsear SSE data: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Conexão SSE encerrada: $e');
      }
    } finally {
      if (_state == RealtimeConnectionState.connected || _state == RealtimeConnectionState.connecting) {
        _setState(RealtimeConnectionState.disconnected);
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _token == null || _token!.isEmpty) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 20);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_disposed && _token != null) {
        connect();
      }
    });
  }

  void _setState(RealtimeConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _client?.close();
    _client = null;
    _setState(RealtimeConnectionState.disconnected);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _eventController.close();
    _stateController.close();
  }
}
