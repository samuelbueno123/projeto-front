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
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.report_problem_outlined, size: 20),
                text: 'Ocorrências',
              ),
              Tab(
                icon: Icon(Icons.badge_outlined, size: 20),
                text: 'Visitantes',
              ),
              Tab(
                icon: Icon(Icons.how_to_vote_outlined, size: 20),
                text: 'Votações',
              ),
              Tab(
                icon: Icon(Icons.storefront_outlined, size: 20),
                text: 'Classificados',
              ),
              Tab(
                icon: Icon(Icons.directions_car_outlined, size: 20),
                text: 'Veículos',
              ),
              Tab(icon: Icon(Icons.pets_outlined, size: 20), text: 'Pets'),
              Tab(
                icon: Icon(Icons.local_shipping_outlined, size: 20),
                text: 'Mudanças',
              ),
              Tab(
                icon: Icon(Icons.menu_book_outlined, size: 20),
                text: 'Documentos',
              ),
              Tab(
                icon: Icon(Icons.gavel_outlined, size: 20),
                text: 'Notificações & Multas',
              ),
              Tab(
                icon: Icon(Icons.lock_clock_outlined, size: 20),
                text: 'Lockers',
              ),
              Tab(
                icon: Icon(Icons.people_outline_rounded, size: 20),
                text: 'Convidados',
              ),
              Tab(
                icon: Icon(Icons.build_circle_outlined, size: 20),
                text: 'Manutenção & O.S.',
              ),
              Tab(
                icon: Icon(Icons.groups_outlined, size: 20),
                text: 'Assembleias',
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                text: 'Financeiro',
              ),
              Tab(
                icon: Icon(Icons.find_in_page_outlined, size: 20),
                text: 'Achados e Perdidos',
              ),
              Tab(
                icon: Icon(Icons.analytics_outlined, size: 20),
                text: 'Relatórios & KPIs',
              ),
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
              _TicketsSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _VisitorsSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _PollsSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
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
              _VehiclesSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _PetsSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _MovingSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _DocumentsSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
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
                requiredFeature: 'PACKAGES',
                featureName: 'Armários Inteligentes (Lockers)',
                child: _LockersSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'RESERVATIONS',
                featureName: 'Lista de Convidados',
                child: _GuestListsSubView(
                  api: widget.api,
                  condominiumId: widget.condominiumId,
                  canManage: widget.canManage,
                ),
              ),
              _MaintenanceSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _AssembliesSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _FinancialSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _LostFoundSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
              _ReportsSubView(
                api: widget.api,
                condominiumId: widget.condominiumId,
                canManage: widget.canManage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
