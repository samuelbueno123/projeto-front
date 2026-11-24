import 'package:flutter/material.dart';

import '../../../../core/design_system/motion_system.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ancora_charts.dart';
import '../../../../core/widgets/custom_menus.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../data/admin_telemetry_service.dart';
import 'admin_telemetry_helpers.dart';

/// Painel Analítico de Negócio e Utilização da Plataforma com filtros por período, condomínio e categoria.
class AdminAnalyticsView extends StatefulWidget {
  const AdminAnalyticsView({
    super.key,
    required this.telemetry,
    this.condominiums = const [],
  });

  final AdminTelemetryService telemetry;
  final List<Map<String, dynamic>> condominiums;

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> {
  String _range = '30d';
  int? _condominiumId;
  String _category = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.telemetry.business == null) {
        _reload();
      }
    });
  }

  Future<void> _reload() {
    return widget.telemetry.fetchBusinessAnalytics(
      range: _range,
      condominiumId: _condominiumId,
      category: _category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return ListenableBuilder(
      listenable: widget.telemetry,
      builder: (context, _) {
        final data = widget.telemetry.business;
        if (data == null && widget.telemetry.isLoadingBusiness) {
          return const SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: AncoraDashboardSkeleton(),
          );
        }

        final condos = AdminTelemetryHelpers.asMap(data?['condominiums']);
        final users = AdminTelemetryHelpers.asMap(data?['users']);
        final byPlan = AdminTelemetryHelpers.asMap(condos['byPlan']);
        final bySubStatus = AdminTelemetryHelpers.asMap(
          condos['bySubscriptionStatus'],
        );
        final byRole = AdminTelemetryHelpers.asMap(users['byRole']);
        final moduleUsage = AdminTelemetryHelpers.asMap(data?['moduleUsage']);
        final ranking = AdminTelemetryHelpers.asMapList(
          data?['condominiumRanking'],
        );
        final timeline = AdminTelemetryHelpers.asMapList(
          data?['activityTimeline'],
        );
        final unavailable = (data?['unavailableMetrics'] is List)
            ? (data!['unavailableMetrics'] as List)
                  .map((e) => e.toString())
                  .toList()
            : const <String>[];

        final totalCondos = AdminTelemetryHelpers.asInt(condos['total']);
        final activeCondos = AdminTelemetryHelpers.asInt(condos['active']);
        final inactiveCondos = AdminTelemetryHelpers.asInt(condos['inactive']);
        final totalUsers = AdminTelemetryHelpers.asInt(users['total']);
        final activeRealtime = AdminTelemetryHelpers.asInt(
          users['activeRealtime'],
        );

        final pkgCount = AdminTelemetryHelpers.asInt(moduleUsage['Encomendas']);
        final resCount = AdminTelemetryHelpers.asInt(moduleUsage['Reservas']);
        final visCount = AdminTelemetryHelpers.asInt(moduleUsage['Visitantes']);
        final tktCount = AdminTelemetryHelpers.asInt(
          moduleUsage['Ocorrências'],
        );

        final timelineLabels = timeline.map((d) {
          final raw = d['date']?.toString() ?? '';
          return raw.length >= 10 ? '${raw.substring(8, 10)}/${raw.substring(5, 7)}' : raw;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de filtros analíticos
              SaaSGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                borderRadius: 12,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AncoraFilterPills<String>(
                          selected: _range,
                          onSelected: (val) {
                            setState(() => _range = val);
                            _reload();
                          },
                          options: const [
                            (value: '7d', label: '7 dias'),
                            (value: '30d', label: '30 dias'),
                            (value: '90d', label: '90 dias'),
                          ],
                        ),
                        AncoraFilterPills<String>(
                          selected: _category,
                          onSelected: (val) {
                            setState(() => _category = val);
                            _reload();
                          },
                          options: const [
                            (value: 'ALL', label: 'Todos Módulos'),
                            (value: 'OPERATIONS', label: 'Portaria/Op'),
                            (value: 'FINANCE', label: 'Financeiro'),
                            (value: 'COMMUNITY', label: 'Comunidade'),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.condominiums.isNotEmpty)
                          SizedBox(
                            width: 240,
                            child: AncoraDropdown<int>(
                              value: _condominiumId ?? -1,
                              hint: 'Todos os condomínios',
                              prefixIcon: Icons.apartment_rounded,
                              searchable: widget.condominiums.length > 5,
                              compact: true,
                              items: [
                                const AncoraMenuOption<int>(
                                  value: -1,
                                  label: 'Todos os condomínios',
                                  icon: Icons.public_rounded,
                                ),
                                ...widget.condominiums
                                    .where((c) => c['id'] is num)
                                    .map(
                                      (c) => AncoraMenuOption<int>(
                                        value: (c['id'] as num).toInt(),
                                        label:
                                            c['name']?.toString() ?? 'Condomínio',
                                        icon: Icons.domain_rounded,
                                      ),
                                    ),
                              ],
                              onChanged: (val) {
                                setState(
                                  () => _condominiumId = val == -1 ? null : val,
                                );
                                _reload();
                              },
                            ),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: widget.telemetry.isLoadingBusiness
                              ? null
                              : _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SaaSMetricGrid(
                items: [
                  SaaSMetricCard(
                    title: 'Condomínios Cadastrados',
                    value: '$totalCondos',
                    icon: Icons.apartment_rounded,
                    iconColor: AncoraChartPalette.indigo,
                    trend: '$activeCondos ativos',
                    subtitle: '$inactiveCondos inativos • ${condos['subscriptionsTotal'] ?? 0} assinaturas',
                  ),
                  SaaSMetricCard(
                    title: 'Usuários da Plataforma',
                    value: '$totalUsers',
                    icon: Icons.people_alt_outlined,
                    iconColor: AncoraChartPalette.emerald,
                    trend: '$activeRealtime online',
                    subtitle: '${users['residentsTotal'] ?? 0} moradores • ${users['unitsTotal'] ?? 0} unidades',
                  ),
                  SaaSMetricCard(
                    title: 'Fluxo Operacional',
                    value: '${pkgCount + visCount}',
                    icon: Icons.inventory_2_outlined,
                    iconColor: AncoraChartPalette.cyan,
                    subtitle: '$pkgCount encomendas • $visCount visitantes',
                  ),
                  SaaSMetricCard(
                    title: 'Reservas & Ocorrências',
                    value: '${resCount + tktCount}',
                    icon: Icons.event_available_outlined,
                    iconColor: AncoraChartPalette.violet,
                    subtitle: '$resCount reservas • $tktCount chamados',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AncoraChartCard(
                title: 'Evolução de Utilização da Plataforma ($_range)',
                subtitle: 'Eventos reais diários por módulo operacional',
                unit: 'eventos/dia',
                legendItems: const [
                  (label: 'Encomendas', color: AncoraChartPalette.indigo),
                  (label: 'Reservas', color: AncoraChartPalette.emerald),
                  (label: 'Visitantes', color: AncoraChartPalette.cyan),
                  (label: 'Ocorrências', color: AncoraChartPalette.amber),
                  (label: 'Novos Vínculos', color: AncoraChartPalette.violet),
                ],
                isEmpty: timeline.isEmpty,
                child: AncoraLineAreaChart(
                  xLabels: timelineLabels,
                  series: [
                    AncoraChartSeries(
                      label: 'Encomendas',
                      values: AdminTelemetryHelpers.extractSeries(
                        timeline,
                        'packages',
                      ),
                      color: AncoraChartPalette.indigo,
                      fillArea: true,
                    ),
                    AncoraChartSeries(
                      label: 'Reservas',
                      values: AdminTelemetryHelpers.extractSeries(
                        timeline,
                        'reservations',
                      ),
                      color: AncoraChartPalette.emerald,
                    ),
                    AncoraChartSeries(
                      label: 'Visitantes',
                      values: AdminTelemetryHelpers.extractSeries(
                        timeline,
                        'visitors',
                      ),
                      color: AncoraChartPalette.cyan,
                    ),
                    AncoraChartSeries(
                      label: 'Ocorrências',
                      values: AdminTelemetryHelpers.extractSeries(
                        timeline,
                        'tickets',
                      ),
                      color: AncoraChartPalette.amber,
                    ),
                    AncoraChartSeries(
                      label: 'Vínculos',
                      values: AdminTelemetryHelpers.extractSeries(
                        timeline,
                        'memberships',
                      ),
                      color: AncoraChartPalette.violet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminTelemetryHelpers.responsiveTwoColumn(
                context: context,
                left: AncoraChartCard(
                  title: 'Usuários por Perfil de Acesso',
                  subtitle: 'Distribuição entre Admin, Síndicos, Porteiros e Moradores',
                  height: 205,
                  child: AncoraDonutChart(
                    centerLabel: 'Usuários',
                    centerValue: '$totalUsers',
                    slices: [
                      AncoraDonutSlice(
                        label: 'Moradores',
                        value: AdminTelemetryHelpers.asDouble(
                          byRole['ROLE_RESIDENT'],
                        ),
                        color: AncoraChartPalette.emerald,
                      ),
                      AncoraDonutSlice(
                        label: 'Porteiros',
                        value: AdminTelemetryHelpers.asDouble(
                          byRole['ROLE_DOORMAN'],
                        ),
                        color: AncoraChartPalette.cyan,
                      ),
                      AncoraDonutSlice(
                        label: 'Síndicos',
                        value: AdminTelemetryHelpers.asDouble(
                          byRole['ROLE_MANAGER'],
                        ),
                        color: AncoraChartPalette.indigo,
                      ),
                      AncoraDonutSlice(
                        label: 'Admins',
                        value: AdminTelemetryHelpers.asDouble(
                          byRole['ROLE_ADMIN'],
                        ),
                        color: AncoraChartPalette.violet,
                      ),
                    ],
                  ),
                ),
                right: AncoraChartCard(
                  title: 'Distribuição por Plano de Assinatura',
                  subtitle: 'Condomínios agrupados por plano contratado',
                  height: 205,
                  isEmpty: byPlan.isEmpty,
                  child: AncoraDonutChart(
                    centerLabel: 'Condomínios',
                    centerValue: '$totalCondos',
                    slices: [
                      for (int i = 0; i < byPlan.entries.length; i++)
                        AncoraDonutSlice(
                          label: byPlan.entries.elementAt(i).key,
                          value: AdminTelemetryHelpers.asDouble(
                            byPlan.entries.elementAt(i).value,
                          ),
                          color: AncoraChartPalette
                              .series[i % AncoraChartPalette.series.length],
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
                        title: 'Funcionalidades Mais Utilizadas',
                        subtitle: 'Volume total de registros por módulo',
                      ),
                      const SizedBox(height: 12),
                      AncoraHorizontalRankingChart(
                        items: moduleUsage.entries
                            .map(
                              (e) => AncoraRankingItem(
                                label: e.key,
                                value: AdminTelemetryHelpers.asDouble(e.value),
                                displayValue: '${e.value}',
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
                        title: 'Status das Assinaturas & Utilização por Condomínio',
                        subtitle: 'Atividade consolidada por empreendimento',
                      ),
                      if (bySubStatus.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: bySubStatus.entries
                              .map(
                                (e) => SaaSBadge(
                                  label: '${e.key}: ${e.value}',
                                  variant: e.key == 'ACTIVE'
                                      ? SaaSBadgeVariant.success
                                      : (e.key == 'SUSPENDED' || e.key == 'PAST_DUE'
                                            ? SaaSBadgeVariant.warning
                                            : SaaSBadgeVariant.neutral),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AncoraDataTable<Map<String, dynamic>>(
                        pageSize: 6,
                        rows: ranking,
                        emptyMessage: 'Nenhum condomínio encontrado.',
                        columns: [
                          AncoraTableColumn(
                            label: 'Condomínio',
                            sortValue: (r) => r['name']?.toString() ?? '',
                            cellBuilder: (r) => Text(
                              r['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          AncoraTableColumn(
                            label: 'Plano',
                            cellBuilder: (r) => Text(
                              r['planName']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          AncoraTableColumn(
                            label: 'Membros',
                            numeric: true,
                            sortValue: (r) =>
                                AdminTelemetryHelpers.asInt(r['members']),
                            cellBuilder: (r) => Text('${r['members'] ?? 0}'),
                          ),
                          AncoraTableColumn(
                            label: 'Atividade',
                            numeric: true,
                            sortValue: (r) =>
                                AdminTelemetryHelpers.asInt(r['totalActivity']),
                            cellBuilder: (r) => SaaSBadge(
                              label: '${r['totalActivity'] ?? 0}',
                              variant: SaaSBadgeVariant.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (unavailable.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: tokens.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          unavailable.join(' '),
                          style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                        ),
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
