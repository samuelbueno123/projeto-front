import 'package:flutter/material.dart';

import '../../../../core/design_system/motion_system.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ancora_charts.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../data/admin_telemetry_service.dart';
import '../widgets/admin_live_toolbar.dart';
import 'admin_telemetry_helpers.dart';

/// Painel de Observabilidade da Aplicação: HTTP, RPM, Status Codes, p50/p95/p99 e Endpoints.
class AdminApplicationView extends StatelessWidget {
  const AdminApplicationView({
    super.key,
    required this.telemetry,
    this.onOpenAlerts,
  });

  final AdminTelemetryService telemetry;
  final VoidCallback? onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return ListenableBuilder(
      listenable: telemetry,
      builder: (context, _) {
        final snap = telemetry.snapshot;
        if (snap == null && telemetry.isLoadingSnapshot) {
          return const SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: AncoraDashboardSkeleton(),
          );
        }
        if (snap == null) {
          return SaaSErrorState(
            message:
                telemetry.errorMessage ??
                'Não foi possível carregar métricas de aplicação.',
            onRetry: () => telemetry.refreshSnapshot(),
          );
        }

        final app = AdminTelemetryHelpers.asMap(snap['application']);
        final httpMap = AdminTelemetryHelpers.asMap(app['http']);
        final realtime = AdminTelemetryHelpers.asMap(app['realtime']);
        final series = AdminTelemetryHelpers.asMapList(snap['timeSeries']);
        final xLabels = AdminTelemetryHelpers.extractTimeLabels(series);

        final totalReq = AdminTelemetryHelpers.asInt(httpMap['totalRequests']);
        final rpm = AdminTelemetryHelpers.asInt(httpMap['requestsPerMinute']);
        final successRate = AdminTelemetryHelpers.asDouble(
          httpMap['successRatePercent'],
          100.0,
        );
        final avgMs = AdminTelemetryHelpers.asDouble(httpMap['avgLatencyMs']);
        final p50Ms = AdminTelemetryHelpers.asInt(httpMap['p50LatencyMs']);
        final p95Ms = AdminTelemetryHelpers.asInt(httpMap['p95LatencyMs']);
        final p99Ms = AdminTelemetryHelpers.asInt(httpMap['p99LatencyMs']);
        final s2xx = AdminTelemetryHelpers.asInt(httpMap['status2xx']);
        final s3xx = AdminTelemetryHelpers.asInt(httpMap['status3xx']);
        final s4xx = AdminTelemetryHelpers.asInt(httpMap['status4xx']);
        final s5xx = AdminTelemetryHelpers.asInt(httpMap['status5xx']);
        final connectedUsers = AdminTelemetryHelpers.asInt(
          realtime['connectedUsers'],
        );
        final activeSse = AdminTelemetryHelpers.asInt(
          realtime['activeConnections'],
        );

        final histogramRaw = AdminTelemetryHelpers.asMapList(
          httpMap['latencyHistogram'],
        );
        final topEndpoints = AdminTelemetryHelpers.asMapList(
          app['topEndpoints'],
        );
        final slowestEndpoints = AdminTelemetryHelpers.asMapList(
          app['slowestEndpoints'],
        );
        final errorEndpoints = AdminTelemetryHelpers.asMapList(
          app['errorEndpoints'],
        );

        final rpmSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'requestsPerMinute',
        );
        final avgLatSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'avgLatencyMs',
        );
        final p95LatSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'p95LatencyMs',
        );
        final p99LatSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'p99LatencyMs',
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminLiveToolbar(
                telemetry: telemetry,
                onOpenAlerts: onOpenAlerts,
              ),
              const SizedBox(height: 16),
              SaaSMetricGrid(
                items: [
                  SaaSMetricCard(
                    title: 'Requisições HTTP',
                    value: '$totalReq',
                    icon: Icons.http_rounded,
                    iconColor: AncoraChartPalette.indigo,
                    trend: '$rpm req/min',
                    subtitle: '${httpMap['inFlightRequests'] ?? 0} em andamento agora',
                    sparklineValues: rpmSeries,
                  ),
                  SaaSMetricCard(
                    title: 'Taxa de Sucesso',
                    value: '${successRate.toStringAsFixed(1)}%',
                    icon: Icons.verified_rounded,
                    iconColor: successRate >= 98
                        ? tokens.success
                        : tokens.warning,
                    trend: '$s4xx 4xx • $s5xx 5xx',
                    trendPositive: s5xx == 0,
                    subtitle: '$s2xx respostas 2xx • $s3xx redirecionamentos',
                  ),
                  SaaSMetricCard(
                    title: 'Latência (p50 / p95 / p99)',
                    value: '${p95Ms}ms',
                    icon: Icons.speed_rounded,
                    iconColor: p95Ms > 500
                        ? tokens.danger
                        : AncoraChartPalette.violet,
                    trend: 'Média ${avgMs.toStringAsFixed(1)}ms',
                    trendPositive: p95Ms <= 500,
                    subtitle: 'p50: ${p50Ms}ms • p95: ${p95Ms}ms • p99: ${p99Ms}ms',
                    sparklineValues: p95LatSeries,
                  ),
                  SaaSMetricCard(
                    title: 'Sessões & Usuários Ativos',
                    value: '$connectedUsers',
                    icon: Icons.sensors_rounded,
                    iconColor: AncoraChartPalette.emerald,
                    trend: '$activeSse streams SSE',
                    subtitle: 'Usuários simultâneos conectados em tempo real',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminTelemetryHelpers.responsiveTwoColumn(
                context: context,
                left: AncoraChartCard(
                  title: 'Latência HTTP ao Longo do Tempo',
                  subtitle: 'Comparativo de latência média, p95 e p99 em milissegundos',
                  unit: 'ms',
                  legendItems: const [
                    (label: 'Média (ms)', color: AncoraChartPalette.emerald),
                    (label: 'p95 (ms)', color: AncoraChartPalette.indigo),
                    (label: 'p99 (ms)', color: AncoraChartPalette.rose),
                  ],
                  isEmpty: avgLatSeries.isEmpty,
                  child: AncoraLineAreaChart(
                    unitSuffix: 'ms',
                    xLabels: xLabels,
                    thresholds: const [
                      AncoraChartThreshold(
                        value: 500,
                        label: 'SLA 500ms',
                        color: AncoraChartPalette.amber,
                      ),
                    ],
                    series: [
                      AncoraChartSeries(
                        label: 'Média',
                        values: avgLatSeries,
                        color: AncoraChartPalette.emerald,
                      ),
                      AncoraChartSeries(
                        label: 'p95',
                        values: p95LatSeries,
                        color: AncoraChartPalette.indigo,
                        fillArea: true,
                      ),
                      AncoraChartSeries(
                        label: 'p99',
                        values: p99LatSeries,
                        color: AncoraChartPalette.rose,
                        dashed: true,
                      ),
                    ],
                  ),
                ),
                right: AncoraChartCard(
                  title: 'Vazão de Requisições por Minuto (RPM)',
                  subtitle: 'Volume recente de chamadas recebidas pela API',
                  unit: 'req/min',
                  isEmpty: rpmSeries.isEmpty,
                  child: AncoraLineAreaChart(
                    unitSuffix: ' rpm',
                    xLabels: xLabels,
                    series: [
                      AncoraChartSeries(
                        label: 'RPM',
                        values: rpmSeries,
                        color: AncoraChartPalette.cyan,
                        fillArea: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AdminTelemetryHelpers.responsiveTwoColumn(
                context: context,
                left: AncoraChartCard(
                  title: 'Distribuição de Códigos HTTP',
                  subtitle: 'Proporção entre respostas 2xx, 3xx, 4xx e 5xx',
                  height: 200,
                  child: AncoraDonutChart(
                    centerLabel: 'Total',
                    centerValue: '$totalReq',
                    slices: [
                      AncoraDonutSlice(
                        label: '2xx Sucesso',
                        value: s2xx.toDouble(),
                        color: AncoraChartPalette.emerald,
                      ),
                      AncoraDonutSlice(
                        label: '3xx Redirecionamento',
                        value: s3xx.toDouble(),
                        color: AncoraChartPalette.cyan,
                      ),
                      AncoraDonutSlice(
                        label: '4xx Erro Cliente',
                        value: s4xx.toDouble(),
                        color: AncoraChartPalette.amber,
                      ),
                      AncoraDonutSlice(
                        label: '5xx Erro Servidor',
                        value: s5xx.toDouble(),
                        color: AncoraChartPalette.rose,
                      ),
                    ],
                  ),
                ),
                right: AncoraChartCard(
                  title: 'Histograma de Latência',
                  subtitle: 'Distribuição das requisições por faixa de tempo de resposta',
                  unit: 'req',
                  height: 200,
                  isEmpty: histogramRaw.isEmpty,
                  child: AncoraHistogramChart(
                    buckets: histogramRaw
                        .map(
                          (b) => (
                            label: b['label']?.toString() ?? '',
                            count: AdminTelemetryHelpers.asDouble(b['count']),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AdminTelemetryHelpers.responsiveTwoColumn(
                context: context,
                left: SaaSGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SaaSSectionHeader(
                        title: 'Endpoints Mais Utilizados',
                        subtitle: 'Ranking por volume de chamadas normalizadas',
                      ),
                      const SizedBox(height: 12),
                      AncoraHorizontalRankingChart(
                        items: topEndpoints
                            .map(
                              (e) => AncoraRankingItem(
                                label: e['endpoint']?.toString() ?? '',
                                value: AdminTelemetryHelpers.asDouble(e['count']),
                                displayValue: '${e['count'] ?? 0} req',
                                subtitle:
                                    'Média ${e['avgMs'] ?? 0}ms • p95 ${e['p95Ms'] ?? 0}ms • ${e['errorCount'] ?? 0} erros',
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                right: SaaSGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SaaSSectionHeader(
                        title: 'Endpoints Mais Lentos (p95)',
                        subtitle: 'Rotas com maior latência no percentil 95',
                      ),
                      const SizedBox(height: 12),
                      AncoraHorizontalRankingChart(
                        defaultColor: AncoraChartPalette.amber,
                        items: slowestEndpoints
                            .map(
                              (e) => AncoraRankingItem(
                                label: e['endpoint']?.toString() ?? '',
                                value: AdminTelemetryHelpers.asDouble(e['p95Ms']),
                                displayValue: '${e['p95Ms'] ?? 0} ms',
                                color: AdminTelemetryHelpers.asInt(e['p95Ms']) > 400
                                    ? AncoraChartPalette.rose
                                    : AncoraChartPalette.amber,
                                subtitle:
                                    'Média ${e['avgMs'] ?? 0}ms • Máx ${e['maxMs'] ?? 0}ms • ${e['count'] ?? 0} chamadas',
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              if (errorEndpoints.isNotEmpty) ...[
                const SizedBox(height: 16),
                SaaSGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SaaSSectionHeader(
                        title: 'Endpoints com Maior Quantidade de Erros',
                        subtitle: 'Rotas retornando status 4xx ou 5xx',
                      ),
                      const SizedBox(height: 12),
                      AncoraDataTable<Map<String, dynamic>>(
                        pageSize: 6,
                        rows: errorEndpoints,
                        columns: [
                          AncoraTableColumn(
                            label: 'Endpoint',
                            sortValue: (r) => r['endpoint']?.toString() ?? '',
                            cellBuilder: (r) => Text(
                              r['endpoint']?.toString() ?? '',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          AncoraTableColumn(
                            label: 'Erros',
                            numeric: true,
                            sortValue: (r) =>
                                AdminTelemetryHelpers.asInt(r['errorCount']),
                            cellBuilder: (r) => SaaSBadge(
                              label: '${r['errorCount'] ?? 0}',
                              variant: SaaSBadgeVariant.error,
                            ),
                          ),
                          AncoraTableColumn(
                            label: 'Taxa Erro',
                            numeric: true,
                            sortValue: (r) => AdminTelemetryHelpers.asDouble(
                              r['errorRatePercent'],
                            ),
                            cellBuilder: (r) => Text(
                              '${r['errorRatePercent'] ?? 0}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          AncoraTableColumn(
                            label: 'Chamadas',
                            numeric: true,
                            sortValue: (r) =>
                                AdminTelemetryHelpers.asInt(r['count']),
                            cellBuilder: (r) => Text(
                              '${r['count'] ?? 0}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
