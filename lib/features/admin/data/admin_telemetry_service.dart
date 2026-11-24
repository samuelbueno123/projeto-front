import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/design_system/saas_design_system.dart';
import '../../../core/services/realtime_transport.dart';
import '../../home/data/home_service.dart';

enum AdminTelemetryLinkState {
  liveSse,
  polling,
  reconnecting,
  paused,
  error,
}

/// Gerencia telemetria administrativa em tempo real via SSE (`/admin/telemetry/stream`)
/// com fallback automático para polling inteligente, controle de janela temporal e alertas.
class AdminTelemetryService extends ChangeNotifier {
  AdminTelemetryService({
    required HomeService api,
    this.token,
  }) : _api = api;

  HomeService _api;
  String? token;

  Map<String, dynamic>? _snapshot;
  Map<String, dynamic>? _business;
  Map<String, dynamic>? _alertsPayload;

  AdminTelemetryLinkState _linkState = AdminTelemetryLinkState.polling;
  bool _isPaused = false;
  bool _isLoadingSnapshot = false;
  bool _isLoadingBusiness = false;
  bool _isLoadingAlerts = false;
  String? _errorMessage;
  String _timeWindow = '15m';
  int _refreshIntervalSeconds = 10;
  DateTime? _lastUpdatedAt;

  SseTransportConnection? _sseConnection;
  StreamSubscription<String>? _sseSub;
  Timer? _pollingTimer;
  Timer? _sseReconnectTimer;
  int _sseRetryCount = 0;
  bool _disposed = false;

  Map<String, dynamic>? get snapshot => _snapshot;
  Map<String, dynamic>? get business => _business;
  Map<String, dynamic>? get alertsPayload => _alertsPayload;
  AdminTelemetryLinkState get linkState => _linkState;
  bool get isPaused => _isPaused;
  bool get isLoadingSnapshot => _isLoadingSnapshot;
  bool get isLoadingBusiness => _isLoadingBusiness;
  bool get isLoadingAlerts => _isLoadingAlerts;
  String? get errorMessage => _errorMessage;
  String get timeWindow => _timeWindow;
  int get refreshIntervalSeconds => _refreshIntervalSeconds;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  int get activeAlertsCount {
    final summary = _snapshot?['alertsSummary'] ?? _alertsPayload?['summary'];
    if (summary is Map && summary['totalActive'] is num) {
      return (summary['totalActive'] as num).toInt();
    }
    final active = _snapshot?['activeAlerts'] ?? _alertsPayload?['active'];
    if (active is List) return active.length;
    return 0;
  }

  int get criticalAlertsCount {
    final summary = _snapshot?['alertsSummary'] ?? _alertsPayload?['summary'];
    if (summary is Map && summary['critical'] is num) {
      return (summary['critical'] as num).toInt();
    }
    return 0;
  }

  void updateCredentials({required HomeService api, String? token}) {
    _api = api;
    final tokenChanged = this.token != token;
    this.token = token;
    if (tokenChanged && !isRunningTestEnvironment && !_isPaused) {
      _closeSse();
      _openSseStream();
    }
  }

  Future<void> start() async {
    await refreshSnapshot();
    if (!isRunningTestEnvironment) {
      _startPollingTimer();
      _openSseStream();
    }
  }

  Future<void> refreshSnapshot({bool silent = false}) async {
    if (_disposed) return;
    if (!silent) {
      _isLoadingSnapshot = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final res = await _api.get('/admin/telemetry/snapshot?window=$_timeWindow');
      if (_disposed) return;
      if (res is Map<String, dynamic>) {
        _snapshot = res;
        _lastUpdatedAt = DateTime.now();
        _errorMessage = null;
        if (_linkState == AdminTelemetryLinkState.error && !_isPaused) {
          _linkState = AdminTelemetryLinkState.polling;
        }
      }
    } catch (e) {
      if (_disposed) return;
      if (!silent || _snapshot == null) {
        _errorMessage = e.toString();
        if (!_isPaused && _linkState != AdminTelemetryLinkState.liveSse) {
          _linkState = AdminTelemetryLinkState.error;
        }
      }
    } finally {
      if (!_disposed) {
        _isLoadingSnapshot = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchBusinessAnalytics({
    String range = '30d',
    int? condominiumId,
    String category = 'ALL',
  }) async {
    if (_disposed) return;
    _isLoadingBusiness = true;
    notifyListeners();
    try {
      final params = <String>[
        'range=$range',
        if (condominiumId != null) 'condominiumId=$condominiumId',
        if (category.isNotEmpty && category != 'ALL') 'category=$category',
      ];
      final res = await _api.get('/admin/telemetry/business?${params.join('&')}');
      if (!_disposed && res is Map<String, dynamic>) {
        _business = res;
      }
    } catch (_) {
      // Mantém estado anterior se falhar em mocks simplificados
    } finally {
      if (!_disposed) {
        _isLoadingBusiness = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchAlerts() async {
    if (_disposed) return;
    _isLoadingAlerts = true;
    notifyListeners();
    try {
      final res = await _api.get('/admin/telemetry/alerts');
      if (!_disposed && res is Map<String, dynamic>) {
        _alertsPayload = res;
      }
    } catch (_) {
    } finally {
      if (!_disposed) {
        _isLoadingAlerts = false;
        notifyListeners();
      }
    }
  }

  Future<bool> acknowledgeAlert(String alertId) async {
    try {
      await _api.post('/admin/telemetry/alerts/$alertId/acknowledge', {});
      await Future.wait([fetchAlerts(), refreshSnapshot(silent: true)]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resolveAlert(String alertId) async {
    try {
      await _api.post('/admin/telemetry/alerts/$alertId/resolve', {});
      await Future.wait([fetchAlerts(), refreshSnapshot(silent: true)]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setTimeWindow(String window) async {
    if (_timeWindow == window) return;
    _timeWindow = window;
    notifyListeners();
    await refreshSnapshot();
  }

  void setRefreshInterval(int seconds) {
    _refreshIntervalSeconds = seconds.clamp(5, 120);
    if (!_isPaused && !isRunningTestEnvironment) {
      _startPollingTimer();
    }
    notifyListeners();
  }

  void pause() {
    _isPaused = true;
    _linkState = AdminTelemetryLinkState.paused;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _sseReconnectTimer?.cancel();
    _sseReconnectTimer = null;
    _closeSse();
    notifyListeners();
  }

  Future<void> resume() async {
    _isPaused = false;
    _linkState = AdminTelemetryLinkState.polling;
    notifyListeners();
    await refreshSnapshot(silent: true);
    if (!isRunningTestEnvironment) {
      _startPollingTimer();
      _openSseStream();
    }
  }

  void _startPollingTimer() {
    _pollingTimer?.cancel();
    if (_isPaused || isRunningTestEnvironment) return;
    _pollingTimer = Timer.periodic(
      Duration(seconds: _refreshIntervalSeconds),
      (_) {
        if (!_disposed && !_isPaused) {
          // Quando SSE está ativo, faz refresh completo mais esparso para atualizar tabelas de endpoints/tabelas DB
          if (_linkState != AdminTelemetryLinkState.liveSse ||
              _lastUpdatedAt == null ||
              DateTime.now().difference(_lastUpdatedAt!).inSeconds >=
                  max(20, _refreshIntervalSeconds * 2)) {
            unawaited(refreshSnapshot(silent: true));
          }
        }
      },
    );
  }

  Future<void> _openSseStream() async {
    if (_disposed || _isPaused || isRunningTestEnvironment) return;
    final tok = token?.trim();
    if (tok == null || tok.isEmpty) return;

    _closeSse();
    try {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/admin/telemetry/stream');
      final conn = await openSseConnection(
        uri: uri,
        headers: {
          'Authorization': 'Bearer $tok',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      );
      if (_disposed || _isPaused) {
        conn.close();
        return;
      }
      _sseConnection = conn;
      _sseRetryCount = 0;
      _linkState = AdminTelemetryLinkState.liveSse;
      notifyListeners();

      final dataLines = <String>[];
      _sseSub = conn.byteStream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (rawLine) {
              if (_disposed || _isPaused) return;
              final line = rawLine.endsWith('\r')
                  ? rawLine.substring(0, rawLine.length - 1)
                  : rawLine;
              if (line.isEmpty) {
                if (dataLines.isNotEmpty) {
                  _handleSsePayload(dataLines.join('\n'));
                  dataLines.clear();
                }
                return;
              }
              if (line.startsWith('data:')) {
                var val = line.substring(5);
                if (val.startsWith(' ')) val = val.substring(1);
                dataLines.add(val);
              }
            },
            onError: (_) => _handleSseDisconnect(),
            onDone: _handleSseDisconnect,
            cancelOnError: true,
          );
    } catch (_) {
      _handleSseDisconnect();
    }
  }

  void _handleSsePayload(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        // Mescla com snapshot detalhado anterior para preservar listas de endpoints e tabelas DB
        final prev = _snapshot;
        if (prev != null) {
          final prevApp = prev['application'];
          final newApp = decoded['application'];
          if (prevApp is Map && newApp is Map) {
            newApp['topEndpoints'] ??= prevApp['topEndpoints'];
            if ((newApp['topEndpoints'] as List?)?.isEmpty ?? true) {
              newApp['topEndpoints'] = prevApp['topEndpoints'];
            }
            if ((newApp['slowestEndpoints'] as List?)?.isEmpty ?? true) {
              newApp['slowestEndpoints'] = prevApp['slowestEndpoints'];
            }
            if ((newApp['errorEndpoints'] as List?)?.isEmpty ?? true) {
              newApp['errorEndpoints'] = prevApp['errorEndpoints'];
            }
            if ((newApp['slowOperations'] as List?)?.isEmpty ?? true) {
              newApp['slowOperations'] = prevApp['slowOperations'];
            }
            if ((newApp['caches'] as List?)?.isEmpty ?? true) {
              newApp['caches'] = prevApp['caches'];
            }
          }
          final prevDb = prev['database'];
          final newDb = decoded['database'];
          if (prevDb is Map && newDb is Map) {
            if ((newDb['topTables'] as List?)?.isEmpty ?? true) {
              newDb['topTables'] = prevDb['topTables'];
            }
            if ((newDb['slowQueries'] as List?)?.isEmpty ?? true) {
              newDb['slowQueries'] = prevDb['slowQueries'];
            }
          }
        }
        _snapshot = decoded;
        _lastUpdatedAt = DateTime.now();
        _linkState = AdminTelemetryLinkState.liveSse;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _handleSseDisconnect() {
    if (_disposed || _isPaused) return;
    _closeSse();
    _linkState = AdminTelemetryLinkState.reconnecting;
    notifyListeners();

    _sseReconnectTimer?.cancel();
    final delaySec = min(30, 2 << min(_sseRetryCount, 4));
    _sseRetryCount++;
    _sseReconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_disposed && !_isPaused) {
        unawaited(_openSseStream());
      }
    });
  }

  void _closeSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseConnection?.close();
    _sseConnection = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _pollingTimer?.cancel();
    _sseReconnectTimer?.cancel();
    _closeSse();
    super.dispose();
  }
}
