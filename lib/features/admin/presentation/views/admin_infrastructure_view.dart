import 'package:flutter/material.dart';

import '../../../../core/design_system/motion_system.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ancora_charts.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../data/admin_telemetry_service.dart';
import '../widgets/admin_live_toolbar.dart';
import 'admin_telemetry_helpers.dart';

/// Painel de Monitoramento da Infraestrutura: CPU, RAM, JVM, Armazenamento, Rede e Processo.
class AdminInfrastructureView extends StatelessWidget {
  const AdminInfrastructureView({
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
                'Não foi possível carregar a telemetria de infraestrutura.',
            onRetry: () => telemetry.refreshSnapshot(),
          );
        }

        final infra = AdminTelemetryHelpers.asMap(snap['infrastructure']);
        final cpu = AdminTelemetryHelpers.asMap(infra['cpu']);
        final ram = AdminTelemetryHelpers.asMap(infra['ram']);
        final jvm = AdminTelemetryHelpers.asMap(infra['jvm']);
        final disk = AdminTelemetryHelpers.asMap(infra['disk']);
        final network = AdminTelemetryHelpers.asMap(infra['network']);
        final series = AdminTelemetryHelpers.asMapList(snap['timeSeries']);
        final xLabels = AdminTelemetryHelpers.extractTimeLabels(series);

        final sysCpu = AdminTelemetryHelpers.asDouble(cpu['systemPercent']);
        final procCpu = AdminTelemetryHelpers.asDouble(cpu['processPercent']);
        final avgCpu = AdminTelemetryHelpers.asDouble(cpu['systemAvgPercent']);
        final peakCpu = AdminTelemetryHelpers.asDouble(cpu['systemPeakPercent']);
        final cores = AdminTelemetryHelpers.asInt(cpu['availableProcessors']);

        final ramTotalMb = AdminTelemetryHelpers.asInt(ram['totalMb']);
        final ramUsedMb = AdminTelemetryHelpers.asInt(ram['usedMb']);
        final ramFreeMb = AdminTelemetryHelpers.asInt(ram['freeMb']);
        final ramPercent = AdminTelemetryHelpers.asDouble(ram['usagePercent']);

        final heapUsedMb = AdminTelemetryHelpers.asInt(jvm['heapUsedMb']);
        final heapMaxMb = AdminTelemetryHelpers.asInt(jvm['heapMaxMb']);
        final heapPercent = AdminTelemetryHelpers.asDouble(jvm['heapUsagePercent']);
        final nonHeapMb = AdminTelemetryHelpers.asInt(jvm['nonHeapUsedMb']);
        final threads = AdminTelemetryHelpers.asInt(jvm['threadCount']);
        final peakThreads = AdminTelemetryHelpers.asInt(jvm['peakThreadCount']);
        final uptimeSec = AdminTelemetryHelpers.asInt(jvm['uptimeSeconds']);
        final gcCount = AdminTelemetryHelpers.asInt(jvm['gcCount']);
        final gcTimeMs = AdminTelemetryHelpers.asInt(jvm['gcTimeMs']);

        final diskTotalMb = AdminTelemetryHelpers.asInt(disk['totalMb']);
        final diskUsedMb = AdminTelemetryHelpers.asInt(disk['usedMb']);
        final diskFreeMb = AdminTelemetryHelpers.asInt(disk['freeMb']);
        final diskPercent = AdminTelemetryHelpers.asDouble(disk['usagePercent']);
        final lowDisk = disk['lowSpaceAlert'] == true;

        final bytesIn = AdminTelemetryHelpers.asInt(network['bytesReceived']);
        final bytesOut = AdminTelemetryHelpers.asInt(network['bytesSent']);
        final rpm = AdminTelemetryHelpers.asInt(network['requestsPerMinute']);
        final sseActive = AdminTelemetryHelpers.asInt(network['activeSseConnections']);
        final nicAvailable = network['osNicCountersAvailable'] == true;

        final cpuSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'systemCpuPercent',
        );
        final procCpuSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'processCpuPercent',
        );
        final ramSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'ramUsagePercent',
        );
        final heapSeries = AdminTelemetryHelpers.extractSeries(
          series,
          'heapUsagePercent',
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
              AncoraEntrance(
                child: SaaSMetricGrid(
                  items: [
                  SaaSMetricCard(
                    title: 'CPU do Servidor',
                    value: '${sysCpu.toStringAsFixed(1)}%',
                    icon: Icons.memory_rounded,
                    iconColor: sysCpu >= 80
                        ? tokens.danger
                        : AncoraChartPalette.indigo,
                    trend: 'JVM ${procCpu.toStringAsFixed(1)}%',
                    trendPositive: sysCpu < 80,
                    subtitle:
                        'Média ${avgCpu.toStringAsFixed(1)}% • Pico ${peakCpu.toStringAsFixed(1)}% • $cores vCPU',
                    sparklineValues: cpuSeries,
                  ),
                  SaaSMetricCard(
                    title: 'Memória RAM Física',
                    value: ramTotalMb > 0
                        ? '${ramPercent.toStringAsFixed(1)}%'
                        : '${heapPercent.toStringAsFixed(1)}% JVM',
                    icon: Icons.sd_storage_outlined,
                    iconColor: ramPercent >= 85
                        ? tokens.danger
                        : AncoraChartPalette.emerald,
                    subtitle: ramTotalMb > 0
                        ? '${AdminTelemetryHelpers.formatMb(ramUsedMb)} / ${AdminTelemetryHelpers.formatMb(ramTotalMb)} (${AdminTelemetryHelpers.formatMb(ramFreeMb)} livre)'
                        : 'Heap ${heapUsedMb}MB / ${heapMaxMb}MB',
                    sparklineValues: ramSeries.isNotEmpty ? ramSeries : heapSeries,
                  ),
                  SaaSMetricCard(
                    title: 'Armazenamento em Disco',
                    value: '${diskPercent.toStringAsFixed(1)}%',
                    icon: Icons.storage_rounded,
                    iconColor: lowDisk
                        ? tokens.danger
                        : AncoraChartPalette.violet,
                    trend: lowDisk ? 'Pouco espaço' : 'Saudável',
                    trendPositive: !lowDisk,
                    subtitle:
                        '${AdminTelemetryHelpers.formatMb(diskUsedMb)} usado • ${AdminTelemetryHelpers.formatMb(diskFreeMb)} livre de ${AdminTelemetryHelpers.formatMb(diskTotalMb)}',
                  ),
                  SaaSMetricCard(
                    title: 'Processo da Aplicação',
                    value: AdminTelemetryHelpers.formatUptime(uptimeSec),
                    icon: Icons.developer_board_rounded,
                    iconColor: AncoraChartPalette.cyan,
                    trend: '$threads threads',
                    subtitle:
                        'Heap ${heapUsedMb}MB (${heapPercent.toStringAsFixed(1)}%) • GC $gcCount ($gcTimeMs ms)',
                    sparklineValues: heapSeries,
                  ),
                ],
                ),
              ),
              const SizedBox(height: 16),
              AdminTelemetryHelpers.responsiveTwoColumn(
                context: context,
                left: AncoraChartCard(
                  title: 'Utilização de CPU ao Longo do Tempo',
                  subtitle: 'Carga total do sistema operacional vs processo Spring Boot',
                  unit: '%',
                  legendItems: const [
                    (label: 'CPU Sistema (%)', color: AncoraChartPalette.indigo),
                    (label: 'CPU Processo JVM (%)', color: AncoraChartPalette.cyan),
                  ],
                  isEmpty: cpuSeries.isEmpty,
                  semanticsSummary:
                      'CPU atual do sistema em ${sysCpu.toStringAsFixed(1)} por cento e processo em ${procCpu.toStringAsFixed(1)} por cento.',
                  child: AncoraLineAreaChart(
                    unitSuffix: '%',
                    maxYOverride: 100,
                    xLabels: xLabels,
                    thresholds: const [
                      AncoraChartThreshold(
                        value: 80,
                        label: 'Alerta 80%',
                        color: AncoraChartPalette.amber,
                      ),
                      AncoraChartThreshold(
                        value: 92,
                        label: 'Crítico 92%',
                        color: AncoraChartPalette.rose,
                      ),
                    ],
                    series: [
                      AncoraChartSeries(
                        label: 'CPU Sistema',
                        values: cpuSeries,
                        color: AncoraChartPalette.indigo,
                        fillArea: true,
                      ),
                      AncoraChartSeries(
                        label: 'CPU JVM',
                        values: procCpuSeries,
                        color: AncoraChartPalette.cyan,
                      ),
                    ],
                  ),
                ),
                right: AncoraChartCard(
                  title: 'Evolução de Memória RAM e JVM Heap',
                  subtitle: 'Consumo percentual de memória física e heap da aplicação',
                  unit: '%',
                  legendItems: const [
                    (label: 'RAM Sistema (%)', color: AncoraChartPalette.emerald),
                    (label: 'JVM Heap (%)', color: AncoraChartPalette.violet),
                  ],
                  isEmpty: heapSeries.isEmpty,
                  child: AncoraLineAreaChart(
                    unitSuffix: '%',
                    maxYOverride: 100,
                    xLabels: xLabels,
                    thresholds: const [
                      AncoraChartThreshold(
                        value: 85,
                        label: 'Limite 85%',
                        color: AncoraChartPalette.amber,
                      ),
                    ],
                    series: [
                      if (ramTotalMb > 0)
                        AncoraChartSeries(
                          label: 'RAM Física',
                          values: ramSeries,
                          color: AncoraChartPalette.emerald,
                          fillArea: true,
                        ),
                      AncoraChartSeries(
                        label: 'JVM Heap',
                        values: heapSeries,
                        color: AncoraChartPalette.violet,
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
                  title: 'Ocupação de Armazenamento',
                  subtitle: 'Espaço em disco na partição da aplicação',
                  unit: 'MB',
                  height: 200,
                  child: AncoraDonutChart(
                    centerLabel: 'Ocupado',
                    centerValue: '${diskPercent.toStringAsFixed(1)}%',
                    valueSuffix: ' MB',
                    slices: [
                      AncoraDonutSlice(
                        label: 'Espaço Utilizado',
                        value: diskUsedMb.toDouble(),
                        color: lowDisk
                            ? AncoraChartPalette.rose
                            : AncoraChartPalette.violet,
                      ),
                      AncoraDonutSlice(
                        label: 'Espaço Disponível',
                        value: diskFreeMb.toDouble(),
                        color: AncoraChartPalette.emerald,
                      ),
                    ],
                  ),
                ),
                right: SaaSGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SaaSSectionHeader(
                        title: 'Rede & Detalhes do Processo JVM',
                        subtitle:
                            'Tráfego HTTP medido na aplicação, SSE e threads ativas',
                        action: SaaSBadge(
                          label: 'Java ${jvm['javaVersion'] ?? '17'}',
                          variant: SaaSBadgeVariant.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _kvRow(
                        tokens,
                        'Dados Recebidos (HTTP In)',
                        AdminTelemetryHelpers.formatBytes(bytesIn),
                      ),
                      _kvRow(
                        tokens,
                        'Dados Transmitidos (HTTP Out)',
                        AdminTelemetryHelpers.formatBytes(bytesOut),
                      ),
                      _kvRow(tokens, 'Requisições / Minuto (RPM)', '$rpm'),
                      _kvRow(tokens, 'Conexões SSE Ativas', '$sseActive'),
                      _kvRow(
                        tokens,
                        'Threads (Ativas / Pico)',
                        '$threads / $peakThreads',
                      ),
                      _kvRow(
                        tokens,
                        'Memória Non-Heap JVM',
                        '$nonHeapMb MB',
                      ),
                      _kvRow(
                        tokens,
                        'Sistema Operacional',
                        '${jvm['osName'] ?? '-'} (${jvm['osArch'] ?? '-'})',
                      ),
                      if (!nicAvailable) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Nota: Contadores físicos de placa de rede do SO (NIC rx/tx) não são expostos pela JVM padrão; exibindo tráfego HTTP real instrumentado pela aplicação.',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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

  Widget _kvRow(AncoraThemeTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
