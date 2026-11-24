import 'package:flutter/material.dart';

import '../../../../core/design_system/motion_system.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ancora_charts.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../data/admin_telemetry_service.dart';
import '../widgets/admin_live_toolbar.dart';
import 'admin_telemetry_helpers.dart';

/// Painel de Monitoramento do Banco de Dados: HikariCP, PostgreSQL/H2, Tabelas e Consultas Lentas.
class AdminDatabaseView extends StatelessWidget {
  const AdminDatabaseView({
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
                'Não foi possível carregar métricas do banco de dados.',
            onRetry: () => telemetry.refreshSnapshot(),
          );
        }

        final db = AdminTelemetryHelpers.asMap(snap['database']);
        final app = AdminTelemetryHelpers.asMap(snap['application']);
        final series = AdminTelemetryHelpers.asMapList(snap['timeSeries']);
        final xLabels = AdminTelemetryHelpers.extractTimeLabels(series);

        final status = db['status']?.toString() ?? 'UP';
        final engine = db['engine']?.toString() ?? 'Database';
        final latencyMs = AdminTelemetryHelpers.asInt(db['latencyMs']);
        final connErrors = AdminTelemetryHelpers.asInt(db['connectionErrors']);
        final poolAvailable = db['poolAvailable'] == true;
        final activeConns = AdminTelemetryHelpers.asInt(db['activeConnections']);
        final idleConns = AdminTelemetryHelpers.asInt(db['idleConnections']);
        final availableConns = AdminTelemetryHelpers.asInt(
          db['availableConnections'],
        );
        final maxPool = AdminTelemetryHelpers.asInt(db['maxPoolSize']);
        final poolPct = AdminTelemetryHelpers.asDouble(db['poolUsagePercent']);
        final dbSizeAvail = db['databaseSizeAvailable'] == true;
        final dbSizeMb = AdminTelemetryHelpers.asDouble(db['databaseSizeMb']);
        final qps = AdminTelemetryHelpers.asInt(db['queriesPerSecond']);
        final cacheHit = AdminTelemetryHelpers.asDouble(
          db['cacheHitRatioPercent'],
        );
        final commits = AdminTelemetryHelpers.asInt(db['commits']);
        final rollbacks = AdminTelemetryHelpers.asInt(db['rollbacks']);

        final topTables = AdminTelemetryHelpers.asMapList(db['topTables']);
        final slowQueries = AdminTelemetryHelpers.asMapList(db['slowQueries']);
        final slowHttpOps = AdminTelemetryHelpers.asMapList(
          app['slowOperations'],
        );

        final connSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'dbActiveConnections',
        );
        final dbLatSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'dbLatencyMs',
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
                    title: 'Estado & Latência ($engine)',
                    value: '${latencyMs}ms',
                    icon: Icons.storage_rounded,
                    iconColor: status == 'UP' ? tokens.success : tokens.danger,
                    trend: status,
                    trendPositive: status == 'UP',
                    subtitle: '$connErrors erro(s) de conexão • Ping SELECT 1',
                    sparklineValues: dbLatSeries,
                  ),
                  SaaSMetricCard(
                    title: 'Conexões HikariCP',
                    value: poolAvailable ? '$activeConns / $maxPool' : 'N/D',
                    icon: Icons.hub_outlined,
                    iconColor: poolPct >= 80
                        ? tokens.warning
                        : AncoraChartPalette.indigo,
                    trend: poolAvailable
                        ? '${poolPct.toStringAsFixed(1)}% uso'
                        : null,
                    trendPositive: poolPct < 80,
                    subtitle: poolAvailable
                        ? '$idleConns ociosas • $availableConns disponíveis'
                        : 'Pool gerenciado externamente',
                    sparklineValues: connSeries,
                  ),
                  SaaSMetricCard(
                    title: 'Tamanho do Banco',
                    value: dbSizeAvail
                        ? '${dbSizeMb.toStringAsFixed(1)} MB'
                        : engine,
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: AncoraChartPalette.violet,
                    subtitle: dbSizeAvail
                        ? 'Cache Hit ${cacheHit.toStringAsFixed(1)}% • $commits commits'
                        : 'Tamanho em disco disponível apenas em PostgreSQL',
                  ),
                  SaaSMetricCard(
                    title: 'Transações / Vazão',
                    value: '$qps tx/s',
                    icon: Icons.bolt_rounded,
                    iconColor: AncoraChartPalette.cyan,
                    subtitle: '$commits commits • $rollbacks rollbacks',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminTelemetryHelpers.responsiveTwoColumn(
                context: context,
                left: AncoraChartCard(
                  title: 'Latência e Conexões Ativas no Banco',
                  subtitle: 'Evolução de ping (ms) e conexões em uso no pool',
                  legendItems: const [
                    (label: 'Latência (ms)', color: AncoraChartPalette.indigo),
                    (label: 'Conexões Ativas', color: AncoraChartPalette.emerald),
                  ],
                  isEmpty: dbLatSeries.isEmpty,
                  child: AncoraLineAreaChart(
                    xLabels: xLabels,
                    series: [
                      AncoraChartSeries(
                        label: 'Latência (ms)',
                        values: dbLatSeries,
                        color: AncoraChartPalette.indigo,
                        fillArea: true,
                      ),
                      AncoraChartSeries(
                        label: 'Conexões Ativas',
                        values: connSeries,
                        color: AncoraChartPalette.emerald,
                      ),
                    ],
                  ),
                ),
                right: AncoraChartCard(
                  title: 'Pool de Conexões HikariCP',
                  subtitle: 'Distribuição entre conexões ativas, ociosas e livres',
                  height: 240,
                  isEmpty: !poolAvailable || maxPool <= 0,
                  emptyMessage: 'Métricas do pool HikariCP indisponíveis.',
                  child: AncoraDonutChart(
                    centerLabel: 'Máximo',
                    centerValue: '$maxPool',
                    slices: [
                      AncoraDonutSlice(
                        label: 'Ativas',
                        value: activeConns.toDouble(),
                        color: AncoraChartPalette.indigo,
                      ),
                      AncoraDonutSlice(
                        label: 'Ociosas (Idle)',
                        value: idleConns.toDouble(),
                        color: AncoraChartPalette.emerald,
                      ),
                      AncoraDonutSlice(
                        label: 'Disponíveis para crescer',
                        value: (maxPool - activeConns - idleConns)
                            .clamp(0, maxPool)
                            .toDouble(),
                        color: AncoraChartPalette.slate,
                      ),
                    ],
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
                        title: 'Tabelas com Maior Quantidade de Registros',
                        subtitle:
                            'Volume real por tabela (com tamanho em MB no PostgreSQL)',
                      ),
                      const SizedBox(height: 12),
                      AncoraHorizontalRankingChart(
                        defaultColor: AncoraChartPalette.violet,
                        items: topTables.map((t) {
                          final name = t['table_name']?.toString() ?? '';
                          final rows = AdminTelemetryHelpers.asInt(
                            t['row_count'],
                          );
                          final sizeMb = t['size_mb'];
                          return AncoraRankingItem(
                            label: name,
                            value: rows.toDouble(),
                            displayValue: '$rows reg',
                            subtitle: sizeMb != null
                                ? 'Tamanho total em disco: $sizeMb MB'
                                : null,
                          );
                        }).toList(),
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
                        title: 'Consultas & Operações Lentas (> 300ms)',
                        subtitle:
                            'Gargalos detectados no PostgreSQL ou endpoints persistentes',
                      ),
                      const SizedBox(height: 12),
                      if (slowQueries.isNotEmpty)
                        AncoraDataTable<Map<String, dynamic>>(
                          pageSize: 5,
                          rows: slowQueries,
                          columns: [
                            AncoraTableColumn(
                              label: 'PID',
                              numeric: true,
                              cellBuilder: (r) => Text('${r['pid'] ?? '-'}'),
                            ),
                            AncoraTableColumn(
                              label: 'Duração',
                              numeric: true,
                              cellBuilder: (r) => SaaSBadge(
                                label: '${r['duration_ms'] ?? 0} ms',
                                variant: SaaSBadgeVariant.warning,
                              ),
                            ),
                            AncoraTableColumn(
                              label: 'Query (resumo)',
                              cellBuilder: (r) => SizedBox(
                                width: 220,
                                child: Text(
                                  r['query_preview']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (slowHttpOps.isNotEmpty)
                        AncoraDataTable<Map<String, dynamic>>(
                          pageSize: 5,
                          rows: slowHttpOps,
                          columns: [
                            AncoraTableColumn(
                              label: 'Operação',
                              cellBuilder: (r) => Text(
                                '${r['method']} ${r['endpoint']}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            AncoraTableColumn(
                              label: 'Status',
                              numeric: true,
                              cellBuilder: (r) => Text('${r['status']}'),
                            ),
                            AncoraTableColumn(
                              label: 'Duração',
                              numeric: true,
                              cellBuilder: (r) => SaaSBadge(
                                label: '${r['durationMs']} ms',
                                variant: SaaSBadgeVariant.warning,
                              ),
                            ),
                          ],
                        )
                      else
                        const SaaSEmptyState(
                          icon: Icons.speed_rounded,
                          title: 'Nenhum gargalo detectado',
                          description:
                              'Nenhuma consulta SQL ou operação acima de 300ms registrada no momento.',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
