import 'package:flutter/material.dart';

import '../../../../core/design_system/motion_system.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ancora_charts.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../data/admin_telemetry_service.dart';
import '../widgets/admin_live_toolbar.dart';
import 'admin_telemetry_helpers.dart';

/// Central de Alertas de Monitoramento: severidade, reconhecimento, resolução e histórico.
class AdminAlertsView extends StatefulWidget {
  const AdminAlertsView({super.key, required this.telemetry});

  final AdminTelemetryService telemetry;

  @override
  State<AdminAlertsView> createState() => _AdminAlertsViewState();
}

class _AdminAlertsViewState extends State<AdminAlertsView> {
  String _severityFilter = 'ALL';
  String _statusFilter = 'ACTIVE_OR_ACK';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.telemetry.fetchAlerts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return ListenableBuilder(
      listenable: widget.telemetry,
      builder: (context, _) {
        final payload = widget.telemetry.alertsPayload;
        final active = AdminTelemetryHelpers.asMapList(
          payload?['active'] ?? widget.telemetry.snapshot?['activeAlerts'],
        );
        final history = AdminTelemetryHelpers.asMapList(payload?['history']);
        final summary = AdminTelemetryHelpers.asMap(
          payload?['summary'] ?? widget.telemetry.snapshot?['alertsSummary'],
        );

        final criticalCnt = AdminTelemetryHelpers.asInt(summary['critical']);
        final warningCnt = AdminTelemetryHelpers.asInt(summary['warning']);
        final infoCnt = AdminTelemetryHelpers.asInt(summary['info']);
        final ackCnt = AdminTelemetryHelpers.asInt(summary['acknowledged']);

        final sourceList = _statusFilter == 'HISTORY' ? history : active;
        final filtered = sourceList.where((a) {
          final sev = a['severity']?.toString() ?? 'INFO';
          final st = a['status']?.toString() ?? 'ACTIVE';
          if (_severityFilter != 'ALL' && sev != _severityFilter) return false;
          if (_statusFilter == 'ACTIVE_ONLY' && st != 'ACTIVE') return false;
          if (_statusFilter == 'ACK_ONLY' && st != 'ACKNOWLEDGED') return false;
          return true;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminLiveToolbar(
                telemetry: widget.telemetry,
                showWindowSelector: false,
              ),
              const SizedBox(height: 16),
              AncoraEntrance(
                child: SaaSMetricGrid(
                  items: [
                    SaaSMetricCard(
                      title: 'Alertas Críticos',
                      value: '$criticalCnt',
                      icon: Icons.error_outline_rounded,
                      iconColor: tokens.danger,
                      subtitle: 'Requerem intervenção imediata',
                    ),
                    SaaSMetricCard(
                      title: 'Avisos (Warning)',
                      value: '$warningCnt',
                      icon: Icons.warning_amber_rounded,
                      iconColor: tokens.warning,
                      subtitle: 'Limiares preventivos atingidos',
                    ),
                    SaaSMetricCard(
                      title: 'Reconhecidos',
                      value: '$ackCnt',
                      icon: Icons.visibility_outlined,
                      iconColor: tokens.info,
                      subtitle: 'Em acompanhamento pela equipe',
                    ),
                    SaaSMetricCard(
                      title: 'Histórico Total',
                      value: '${history.length}',
                      icon: Icons.history_rounded,
                      iconColor: tokens.success,
                      subtitle: '$infoCnt informativo(s) ativo(s)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminTelemetryHelpers.responsiveTwoColumn(
                context: context,
                left: AncoraChartCard(
                  title: 'Alertas Ativos por Severidade',
                  subtitle: 'Distribuição entre Críticos, Avisos e Informativos',
                  height: 195,
                  isEmpty: active.isEmpty,
                  emptyMessage: 'Nenhum alerta ativo — todos os limiares estão normais.',
                  child: AncoraDonutChart(
                    centerLabel: 'Ativos',
                    centerValue: '${active.length}',
                    slices: [
                      AncoraDonutSlice(
                        label: 'Críticos',
                        value: criticalCnt.toDouble(),
                        color: AncoraChartPalette.rose,
                      ),
                      AncoraDonutSlice(
                        label: 'Avisos',
                        value: warningCnt.toDouble(),
                        color: AncoraChartPalette.amber,
                      ),
                      AncoraDonutSlice(
                        label: 'Informativos',
                        value: infoCnt.toDouble(),
                        color: AncoraChartPalette.indigo,
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
                        title: 'Regras Monitoradas Continuamente',
                        subtitle:
                            'Avaliadas automaticamente a cada 10 segundos no backend',
                      ),
                      const SizedBox(height: 12),
                      _ruleRow(tokens, 'CPU do Servidor', 'Warning >= 80% • Crítico >= 92%'),
                      _ruleRow(tokens, 'Memória JVM Heap', 'Warning >= 80% • Crítico >= 92%'),
                      _ruleRow(tokens, 'Memória RAM Física', 'Warning >= 85% • Crítico >= 95%'),
                      _ruleRow(tokens, 'Espaço em Disco', 'Warning >= 85% • Crítico >= 95%'),
                      _ruleRow(tokens, 'Erros HTTP 5xx & Latência p95', '5+ erros/min ou p95 > 500ms'),
                      _ruleRow(tokens, 'Banco & Pool HikariCP', 'Queda de ping ou pool >= 80%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SaaSGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AncoraFilterPills<String>(
                          selected: _statusFilter,
                          onSelected: (v) => setState(() => _statusFilter = v),
                          options: const [
                            (value: 'ACTIVE_OR_ACK', label: 'Ativos'),
                            (value: 'ACTIVE_ONLY', label: 'Pendentes'),
                            (value: 'ACK_ONLY', label: 'Reconhecidos'),
                            (value: 'HISTORY', label: 'Histórico'),
                          ],
                        ),
                        AncoraFilterPills<String>(
                          selected: _severityFilter,
                          onSelected: (v) => setState(() => _severityFilter = v),
                          options: const [
                            (value: 'ALL', label: 'Todas'),
                            (value: 'CRITICAL', label: 'Críticos'),
                            (value: 'WARNING', label: 'Avisos'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      const SaaSEmptyState(
                        icon: Icons.verified_user_outlined,
                        title: 'Nenhum alerta nesta visualização',
                        description:
                            'A infraestrutura, aplicação e banco estão operando dentro dos parâmetros.',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final alert = filtered[idx];
                          final id = alert['id']?.toString() ?? '';
                          final sev = alert['severity']?.toString() ?? 'INFO';
                          final status = alert['status']?.toString() ?? 'ACTIVE';
                          final isResolved = status == 'RESOLVED';
                          final isAck = status == 'ACKNOWLEDGED';

                          final variant = switch (sev) {
                            'CRITICAL' => SaaSBadgeVariant.error,
                            'WARNING' => SaaSBadgeVariant.warning,
                            _ => SaaSBadgeVariant.primary,
                          };

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tokens.border),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 560,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          SaaSBadge(label: sev, variant: variant),
                                          SaaSBadge(
                                            label: status,
                                            variant: isResolved
                                                ? SaaSBadgeVariant.success
                                                : (isAck
                                                      ? SaaSBadgeVariant.primary
                                                      : SaaSBadgeVariant.neutral),
                                          ),
                                          Text(
                                            alert['ruleCode']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        alert['message']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Valor atual: ${alert['currentValue'] ?? '-'} • Limite: ${alert['threshold'] ?? '-'} • Disparo: ${alert['triggeredAt'] ?? '-'}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: tokens.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isResolved && _statusFilter != 'HISTORY')
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (!isAck)
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final ok = await widget.telemetry
                                                .acknowledgeAlert(id);
                                            if (context.mounted && ok) {
                                              SaaSFeedback.showSuccess(
                                                context,
                                                'Alerta reconhecido.',
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.check_outlined,
                                            size: 16,
                                          ),
                                          label: const Text('Reconhecer'),
                                        ),
                                      FilledButton.icon(
                                        onPressed: () async {
                                          final ok = await widget.telemetry
                                              .resolveAlert(id);
                                          if (context.mounted && ok) {
                                            SaaSFeedback.showSuccess(
                                              context,
                                              'Alerta resolvido.',
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.done_all_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Resolver'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ruleRow(AncoraThemeTokens tokens, String name, String rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.radar_rounded, size: 14, color: tokens.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              rule,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: tokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
