import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/report_downloader.dart';
import '../../data/community_api.dart';
import '../dialogs/plan_selection_dialog.dart';

part 'community_hub_operations_sections.dart';
part 'community_hub_property_sections.dart';
part 'community_hub_management_sections.dart';
part 'community_hub_finance_sections.dart';

class CommunityHubView extends StatefulWidget {
  const CommunityHubView({
    super.key,
    required this.api,
    required this.condominiumId,
    this.initialCategoryIndex = 0,
    this.canManage = false,
    this.enabledFeatures,
  });

  final CommunityApi api;
  final num condominiumId;
  final int initialCategoryIndex;
  final bool canManage;
  final List<String>? enabledFeatures;

  @override
  State<CommunityHubView> createState() => _CommunityHubViewState();
}

class _CommunityHubViewState extends State<CommunityHubView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = [
    'Ocorrências',
    'Visitantes',
    'Votações',
    'Classificados',
    'Veículos',
    'Pets',
    'Mudanças',
    'Documentos',
    'Multas & Notificações',
    'Smart Lockers',
    'Lista de Convidados',
    'Manutenção & O.S.',
    'Assembleias',
    'Financeiro',
    'Achados e Perdidos',
    'Relatórios & KPIs',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: widget.initialCategoryIndex.clamp(
        0,
        _categories.length - 1,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CommunityHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryIndex != widget.initialCategoryIndex) {
      final target = widget.initialCategoryIndex.clamp(
        0,
        _categories.length - 1,
      );
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPlanGatedWrapper({
    required String? requiredFeature,
    required Widget child,
    required String featureName,
  }) {
    if (requiredFeature == null || widget.enabledFeatures == null) {
      return child;
    }
    final isEnabled = widget.enabledFeatures!
        .map((e) => e.toUpperCase())
        .contains(requiredFeature.toUpperCase());
    if (isEnabled) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 36,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recurso Exclusivo de Plano',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'O recurso "$featureName" não está habilitado no plano atual deste condomínio.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Faça upgrade para os planos Profissional ou Premium para desbloquear acesso total a esta e outras funcionalidades operacionais.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
            ),
            if (widget.canManage) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('Ver Planos de Assinatura'),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => PlanSelectionDialog(
                      condominiumId: widget.condominiumId,
                      condominiumName: 'Condomínio',
                      api: widget.api,
                      onPlanSelected: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Plano atualizado com sucesso!'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Compact Category TabBar avoiding page vertical scroll
        Container(
          decoration: BoxDecoration(
            color: isDark ? SaaSColors.cardNavy : Colors.white,
            border: Border(
              bottom: BorderSide(color: SaaSColors.border(isDark)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelColor: isDark ? const Color(0xFF60A5FA) : SaaSColors.primary,
            unselectedLabelColor: SaaSColors.textSecondary(isDark),
            indicatorColor: isDark
                ? const Color(0xFF60A5FA)
                : SaaSColors.primary,
            indicatorWeight: 3,
            tabs: [
              _buildCategoryTab(0, Icons.report_problem_outlined, 'Ocorrências'),
              _buildCategoryTab(1, Icons.badge_outlined, 'Visitantes'),
              _buildCategoryTab(2, Icons.how_to_vote_outlined, 'Votações'),
              _buildCategoryTab(3, Icons.storefront_outlined, 'Classificados'),
              _buildCategoryTab(4, Icons.directions_car_outlined, 'Veículos'),
              _buildCategoryTab(5, Icons.pets_outlined, 'Pets'),
              _buildCategoryTab(6, Icons.local_shipping_outlined, 'Mudanças'),
              _buildCategoryTab(7, Icons.menu_book_outlined, 'Documentos'),
              _buildCategoryTab(8, Icons.gavel_outlined, 'Notificações & Multas'),
              _buildCategoryTab(9, Icons.lock_clock_outlined, 'Lockers'),
              _buildCategoryTab(10, Icons.people_outline_rounded, 'Convidados'),
              _buildCategoryTab(11, Icons.build_circle_outlined, 'Manutenção & O.S.'),
              _buildCategoryTab(12, Icons.groups_outlined, 'Assembleias'),
              _buildCategoryTab(13, Icons.account_balance_wallet_outlined, 'Financeiro'),
              _buildCategoryTab(14, Icons.find_in_page_outlined, 'Achados e Perdidos'),
              _buildCategoryTab(15, Icons.analytics_outlined, 'Relatórios & KPIs'),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content area sized properly
        Expanded(
          child: TabBarView(
            key: ValueKey(
              'community_${widget.condominiumId}_${widget.canManage}',
            ),
            controller: _tabController,
            children: [
              _buildPlanGatedWrapper(
                requiredFeature: 'COMMUNITY_TICKETS',
                featureName: 'Ocorrências e Chamados',
                child: _TicketsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'VISITORS',
                featureName: 'Visitantes e QR Code',
                child: _VisitorsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'POLLS',
                featureName: 'Enquetes Rápidas',
                child: _PollsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'MARKETPLACE_INTEGRATION',
                featureName: 'Classificados e Vagas',
                child: _ClassifiedsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'COMMUNITY_TICKETS',
                featureName: 'Veículos e Garagem',
                child: _VehiclesSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'COMMUNITY_TICKETS',
                featureName: 'Cadastro de Pets',
                child: _PetsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'COMMUNITY_TICKETS',
                featureName: 'Agendamento de Mudanças',
                child: _MovingSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'COMMUNITY_TICKETS',
                featureName: 'Documentos e Atas',
                child: _DocumentsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'NOTIFICATIONS',
                featureName: 'Notificações & Multas',
                child: _InfractionsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'SMART_LOCKERS',
                featureName: 'Armários Inteligentes (Lockers)',
                child: _LockersSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'VISITORS',
                featureName: 'Lista de Convidados',
                child: _GuestListsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'MAINTENANCE',
                featureName: 'Manutenção Predial & O.S.',
                child: _MaintenanceSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'ASSEMBLIES',
                featureName: 'Assembleias Virtuais',
                child: _AssembliesSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'FINANCIAL',
                featureName: 'Gestão Financeira e Orçamento',
                child: _FinancialSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'COMMUNITY_TICKETS',
                featureName: 'Achados e Perdidos',
                child: _LostFoundSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'REPORTS',
                featureName: 'Relatórios Gerenciais & KPIs',
                child: _ReportsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const Map<int, String> _categoryFeatures = {
    0: 'COMMUNITY_TICKETS',
    1: 'VISITORS',
    2: 'POLLS',
    3: 'MARKETPLACE_INTEGRATION',
    4: 'COMMUNITY_TICKETS',
    5: 'COMMUNITY_TICKETS',
    6: 'COMMUNITY_TICKETS',
    7: 'COMMUNITY_TICKETS',
    8: 'NOTIFICATIONS',
    9: 'SMART_LOCKERS',
    10: 'VISITORS',
    11: 'MAINTENANCE',
    12: 'ASSEMBLIES',
    13: 'FINANCIAL',
    14: 'COMMUNITY_TICKETS',
    15: 'REPORTS',
  };

  bool _isCategoryLocked(int index) {
    final enabled = widget.enabledFeatures;
    if (enabled == null) return false;
    final feature = _categoryFeatures[index];
    if (feature == null) return false;
    return !enabled.map((e) => e.toUpperCase()).contains(feature);
  }

  Tab _buildCategoryTab(int index, IconData icon, String text) {
    final locked = _isCategoryLocked(index);
    return Tab(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          if (locked) ...[
            const SizedBox(width: 4),
            const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFFF59E0B)),
          ],
        ],
      ),
      text: text,
    );
  }
}

// ----------------------------------------------------
