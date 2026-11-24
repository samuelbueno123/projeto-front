import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto_front/core/theme/app_theme.dart';
import 'package:projeto_front/core/widgets/ancora_charts.dart';
import 'package:projeto_front/features/admin/data/admin_telemetry_service.dart';
import 'package:projeto_front/features/admin/presentation/views/admin_alerts_view.dart';
import 'package:projeto_front/features/admin/presentation/views/admin_analytics_view.dart';
import 'package:projeto_front/features/admin/presentation/views/admin_application_view.dart';
import 'package:projeto_front/features/admin/presentation/views/admin_database_view.dart';
import 'package:projeto_front/features/admin/presentation/views/admin_infrastructure_view.dart';
import 'package:projeto_front/features/admin/presentation/widgets/admin_live_toolbar.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

Map<String, dynamic> _sampleSnapshot() => {
  'timestamp': '2026-11-23T22:00:00Z',
  'window': '15m',
  'overallStatus': 'UP',
  'infrastructure': {
    'cpu': {
      'systemPercent': 34.5,
      'processPercent': 12.2,
      'systemAvgPercent': 29.8,
      'systemPeakPercent': 48.0,
      'availableProcessors': 8,
      'systemLoadAverage': 1.4,
    },
    'ram': {
      'totalMb': 16384,
      'usedMb': 8192,
      'freeMb': 8192,
      'usagePercent': 50.0,
      'available': true,
    },
    'jvm': {
      'heapUsedMb': 320,
      'heapMaxMb': 2048,
      'heapCommittedMb': 512,
      'heapUsagePercent': 15.6,
      'nonHeapUsedMb': 96,
      'gcCount': 14,
      'gcTimeMs': 210,
      'threadCount': 42,
      'peakThreadCount': 55,
      'daemonThreadCount': 31,
      'uptimeSeconds': 10800,
      'javaVersion': '17',
      'osName': 'Linux',
      'osArch': 'amd64',
    },
    'disk': {
      'totalMb': 102400,
      'usedMb': 40960,
      'freeMb': 61440,
      'usagePercent': 40.0,
      'lowSpaceAlert': false,
    },
    'network': {
      'bytesReceived': 204800,
      'bytesSent': 1048576,
      'requestsPerMinute': 64,
      'avgLatencyMs': 18.4,
      'httpErrors5xx': 0,
      'activeSseConnections': 6,
      'connectedUsers': 5,
      'osNicCountersAvailable': false,
    },
  },
  'application': {
    'http': {
      'totalRequests': 1240,
      'requestsPerMinute': 64,
      'inFlightRequests': 2,
      'status2xx': 1190,
      'status3xx': 20,
      'status4xx': 28,
      'status5xx': 2,
      'recent5xxCount': 0,
      'successRatePercent': 97.6,
      'avgLatencyMs': 18.4,
      'p50LatencyMs': 14,
      'p95LatencyMs': 62,
      'p99LatencyMs': 140,
      'maxLatencyMs': 310,
      'latencyHistogram': [
        {'label': '<25ms', 'count': 800},
        {'label': '25-50ms', 'count': 280},
        {'label': '50-100ms', 'count': 110},
        {'label': '100-250ms', 'count': 42},
        {'label': '250-500ms', 'count': 8},
        {'label': '500ms-1s', 'count': 0},
        {'label': '>1s', 'count': 0},
      ],
    },
    'topEndpoints': [
      {
        'endpoint': 'GET /users/me',
        'count': 420,
        'errorCount': 0,
        'errorRatePercent': 0.0,
        'avgMs': 9.2,
        'p95Ms': 24,
        'maxMs': 48,
      },
    ],
    'slowestEndpoints': [
      {
        'endpoint': 'GET /admin/telemetry/business',
        'count': 18,
        'errorCount': 0,
        'errorRatePercent': 0.0,
        'avgMs': 45.0,
        'p95Ms': 120,
        'maxMs': 190,
      },
    ],
    'errorEndpoints': [
      {
        'endpoint': 'POST /oauth2/token',
        'count': 50,
        'errorCount': 3,
        'errorRatePercent': 6.0,
        'avgMs': 25.0,
        'p95Ms': 60,
        'maxMs': 90,
      },
    ],
    'slowOperations': [],
    'realtime': {
      'activeConnections': 6,
      'connectedUsers': 5,
      'connectedCondominiums': 2,
      'adminTelemetryStreams': 1,
    },
  },
  'database': {
    'status': 'UP',
    'engine': 'PostgreSQL',
    'latencyMs': 3,
    'connectionErrors': 0,
    'poolAvailable': true,
    'activeConnections': 2,
    'idleConnections': 8,
    'totalConnections': 10,
    'availableConnections': 18,
    'awaitingConnections': 0,
    'maxPoolSize': 20,
    'poolUsagePercent': 10.0,
    'databaseSizeAvailable': true,
    'databaseSizeMb': 142.5,
    'commits': 9500,
    'rollbacks': 12,
    'cacheHitRatioPercent': 99.4,
    'queriesPerSecond': 14,
    'topTables': [
      {'table_name': 'tb_audit_log', 'row_count': 450, 'size_mb': 1.2},
      {'table_name': 'tb_package', 'row_count': 210, 'size_mb': 0.8},
    ],
    'slowQueries': [],
  },
  'timeSeries': [
    {
      'timestamp': '2026-11-23T21:58:00Z',
      'systemCpuPercent': 28.0,
      'processCpuPercent': 10.0,
      'ramUsagePercent': 49.0,
      'heapUsagePercent': 14.0,
      'requestsPerMinute': 52,
      'avgLatencyMs': 16.0,
      'p95LatencyMs': 55,
      'p99LatencyMs': 120,
      'dbActiveConnections': 1,
      'dbLatencyMs': 2,
    },
    {
      'timestamp': '2026-11-23T21:59:00Z',
      'systemCpuPercent': 34.5,
      'processCpuPercent': 12.2,
      'ramUsagePercent': 50.0,
      'heapUsagePercent': 15.6,
      'requestsPerMinute': 64,
      'avgLatencyMs': 18.4,
      'p95LatencyMs': 62,
      'p99LatencyMs': 140,
      'dbActiveConnections': 2,
      'dbLatencyMs': 3,
    },
  ],
  'activeAlerts': [
    {
      'id': 'al-101',
      'ruleCode': 'HIGH_LATENCY_P95',
      'severity': 'WARNING',
      'status': 'ACTIVE',
      'message': 'Latência p95 elevada (520 ms)',
      'currentValue': '520 ms',
      'threshold': '500 ms',
      'triggeredAt': '2026-11-23T21:55:00Z',
    },
  ],
  'alertsSummary': {
    'totalActive': 1,
    'critical': 0,
    'warning': 1,
    'info': 0,
    'acknowledged': 0,
    'historyTotal': 1,
  },
};

Map<String, dynamic> _sampleBusiness() => {
  'range': '30d',
  'condominiums': {
    'total': 4,
    'active': 3,
    'inactive': 1,
    'subscriptionsTotal': 4,
    'byPlan': {'ESSENCIAL': 2, 'ENTERPRISE': 2},
    'bySubscriptionStatus': {'ACTIVE': 3, 'PAST_DUE': 1},
  },
  'users': {
    'total': 150,
    'unitsTotal': 90,
    'residentsTotal': 120,
    'activeRealtime': 5,
    'byRole': {
      'ROLE_ADMIN': 1,
      'ROLE_MANAGER': 4,
      'ROLE_DOORMAN': 8,
      'ROLE_RESIDENT': 137,
    },
  },
  'moduleUsage': {
    'Encomendas': 210,
    'Reservas': 75,
    'Visitantes': 180,
    'Ocorrências': 24,
  },
  'condominiumRanking': [
    {
      'id': 1,
      'name': 'Residencial Âncora',
      'planName': 'ENTERPRISE',
      'members': 80,
      'totalActivity': 320,
    },
  ],
  'activityTimeline': [
    {
      'date': '2026-11-22',
      'packages': 12,
      'reservations': 4,
      'visitors': 9,
      'tickets': 1,
      'memberships': 2,
    },
    {
      'date': '2026-11-23',
      'packages': 18,
      'reservations': 6,
      'visitors': 14,
      'tickets': 2,
      'memberships': 3,
    },
  ],
  'unavailableMetrics': [
    'Novos usuários por período não possuem coluna created_at.',
  ],
};

void main() {
  group('Admin Telemetry Dashboard & Charts Tests', () {
    late AdminTelemetryService telemetry;
    late int ackCalls;
    late int resolveCalls;

    setUp(() {
      ackCalls = 0;
      resolveCalls = 0;
      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/admin/telemetry/snapshot')) {
          return http.Response(
            jsonEncode(_sampleSnapshot()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/admin/telemetry/business')) {
          return http.Response(
            jsonEncode(_sampleBusiness()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/admin/telemetry/alerts')) {
          return http.Response(
            jsonEncode({
              'active': _sampleSnapshot()['activeAlerts'],
              'history': _sampleSnapshot()['activeAlerts'],
              'summary': _sampleSnapshot()['alertsSummary'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('/acknowledge')) {
          ackCalls++;
          return http.Response(
            jsonEncode({'id': 'al-101', 'status': 'ACKNOWLEDGED'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('/resolve')) {
          resolveCalls++;
          return http.Response(
            jsonEncode({'id': 'al-101', 'status': 'RESOLVED'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final api = HomeService(token: 'test-token', client: client);
      telemetry = AdminTelemetryService(api: api, token: 'test-token');
    });

    tearDown(() {
      telemetry.dispose();
    });

    testWidgets('AncoraCharts handles 0, 1, and multiple points safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const AncoraChartCard(
                    title: 'Vazio',
                    isEmpty: true,
                    child: SizedBox(),
                  ),
                  const SizedBox(
                    height: 120,
                    child: AncoraLineAreaChart(
                      series: [
                        AncoraChartSeries(
                          label: 'Ponto Único',
                          values: [42.0],
                          color: AncoraChartPalette.indigo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 120,
                    child: AncoraHistogramChart(
                      buckets: [
                        (label: '<25ms', count: 10),
                        (label: '25-50ms', count: 5),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 150,
                    child: AncoraDonutChart(
                      centerLabel: 'Total',
                      centerValue: '15',
                      slices: [
                        AncoraDonutSlice(
                          label: 'A',
                          value: 10,
                          color: AncoraChartPalette.emerald,
                        ),
                        AncoraDonutSlice(
                          label: 'B',
                          value: 5,
                          color: AncoraChartPalette.amber,
                        ),
                      ],
                    ),
                  ),
                  const AncoraHorizontalRankingChart(
                    items: [
                      AncoraRankingItem(
                        label: '/users/me',
                        value: 100,
                        displayValue: '100 req',
                      ),
                    ],
                  ),
                  const AncoraSparkline(
                    values: [10, 10, 10],
                    color: AncoraChartPalette.cyan,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vazio'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('/users/me'), findsOneWidget);
    });

    testWidgets('AdminLiveToolbar toggles pause/resume and window', (
      tester,
    ) async {
      await telemetry.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminLiveToolbar(telemetry: telemetry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pausar'), findsOneWidget);
      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();
      expect(telemetry.isPaused, isTrue);
      expect(find.text('Retomar'), findsOneWidget);

      await tester.tap(find.text('1h'));
      await tester.pumpAndSettle();
      expect(telemetry.timeWindow, '1h');
    });

    testWidgets(
      'All 5 Admin Telemetry Views render on Desktop (1400x900) and Mobile (390x844) without overflow',
      (tester) async {
        await telemetry.start();
        await telemetry.fetchBusinessAnalytics();
        await telemetry.fetchAlerts();

        for (final size in const [Size(1400, 900), Size(390, 844)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          for (final view in [
            AdminInfrastructureView(telemetry: telemetry),
            AdminApplicationView(telemetry: telemetry),
            AdminDatabaseView(telemetry: telemetry),
            AdminAnalyticsView(telemetry: telemetry),
            AdminAlertsView(telemetry: telemetry),
          ]) {
            await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets('AdminAlertsView acknowledges and resolves active alerts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await telemetry.start();
      await telemetry.fetchAlerts();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminAlertsView(telemetry: telemetry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HIGH_LATENCY_P95'), findsOneWidget);
      await tester.tap(find.text('Reconhecer'));
      await tester.pumpAndSettle();
      expect(ackCalls, 1);

      await tester.tap(find.text('Resolver'));
      await tester.pumpAndSettle();
      expect(resolveCalls, 1);
    });
  });
}
