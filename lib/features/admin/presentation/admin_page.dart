import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_system/motion_system.dart';
import '../../../core/design_system/saas_design_system.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ancora_charts.dart';
import '../../../core/widgets/command_palette.dart';
import '../../../core/widgets/custom_menus.dart';
import '../../../core/widgets/enter_search_field.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/role_switcher_pill.dart';
import '../../../core/widgets/saas_dashboard_widgets.dart';
import '../../../core/widgets/smart_image.dart';
import '../../home/data/home_service.dart';
import '../../auth/presentation/pages/user_profile_page.dart';
import '../../manager/presentation/membership_management_page.dart';
import '../data/admin_telemetry_service.dart';
import 'admin_create_dialogs.dart';
import 'system_announcement_page.dart';
import 'admin_command_center_views.dart';
import 'views/admin_alerts_view.dart';
import 'views/admin_analytics_view.dart';
import 'views/admin_application_view.dart';
import 'views/admin_database_view.dart';
import 'views/admin_infrastructure_view.dart';
import 'views/admin_telemetry_helpers.dart';
import 'widgets/admin_live_toolbar.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.token,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
    this.authProvider = 'password',
    required this.reauthenticateWithGoogle,
    required this.refreshWithCredentials,
    required this.refreshGoogleSession,
    this.currentRole,
    this.availableRoles = const [],
    this.onSwitchRole,
    this.api,
  });

  final String? token;
  final String? userName;
  final String? userEmail;
  final Future<void> Function() onLogout;
  final String authProvider;
  final Future<String> Function() reauthenticateWithGoogle;
  final Future<void> Function(String email, String password)
  refreshWithCredentials;
  final Future<void> Function() refreshGoogleSession;
  final String? currentRole;
  final List<String> availableRoles;
  final ValueChanged<String>? onSwitchRole;
  final HomeService? api;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late HomeService _api = widget.api ?? HomeService(token: widget.token);
  late final AdminTelemetryService _telemetry;
  Map<String, dynamic> _profile = {};
  late Future<Map<String, dynamic>> _summary;
  String _activeTab = 'overview';
  String? _selectedResourceKey;
  String? _selectedResourceTitle;
  bool _showAllEntities = false;
  bool _sidebarCollapsed = false;

  static const _resources = <(String, String, IconData)>[
    ('Usuários', 'users', Icons.people_alt_outlined),
    ('Condomínios', 'condominiums', Icons.apartment_outlined),
    ('Vínculos', 'memberships', Icons.admin_panel_settings_outlined),
    ('Setores', 'sectors', Icons.domain_outlined),
    ('Unidades', 'units', Icons.home_work_outlined),
    ('Moradores', 'residents', Icons.groups_outlined),
    ('Encomendas', 'packages', Icons.inventory_2_outlined),
    ('Histórico Encomendas', 'package-history', Icons.history_outlined),
    ('Comunicados', 'announcements', Icons.campaign_outlined),
    ('Reservas', 'reservations', Icons.event_available_outlined),
    ('Áreas comuns', 'common-areas', Icons.deck_outlined),
    ('Notificações', 'notifications', Icons.notifications_none_outlined),
    ('Planos', 'billing-plans', Icons.receipt_long_outlined),
    ('Assinaturas', 'condominium-subscriptions', Icons.subscriptions_outlined),
    ('Histórico Assinaturas', 'subscription-history', Icons.history_rounded),
    ('Recursos do sistema', 'features', Icons.extension_outlined),
    ('Chamados / Ocorrências', 'tickets', Icons.report_problem_outlined),
    ('Acesso Visitantes', 'visitors', Icons.badge_outlined),
    ('Achados e Perdidos', 'lost-found', Icons.search_outlined),
    ('Classificados', 'classifieds', Icons.storefront_outlined),
    ('Veículos', 'vehicles', Icons.directions_car_outlined),
    ('Pets', 'pets', Icons.pets_outlined),
    ('Mudanças', 'moving-requests', Icons.local_shipping_outlined),
    ('Documentos', 'documents', Icons.description_outlined),
    ('Armários Inteligentes', 'lockers', Icons.lock_clock_outlined),
    ('Listas de Convidados', 'guest-lists', Icons.checklist_outlined),
    ('Infrações e Multas', 'infractions', Icons.gavel_outlined),
    ('Assembleias Virtuais', 'assemblies', Icons.how_to_vote_outlined),
    ('Manutenções', 'maintenance-orders', Icons.build_circle_outlined),
    ('Despesas', 'expenses', Icons.attach_money_outlined),
    ('Boletos e Pagamentos', 'unit-payments', Icons.receipt_outlined),
    ('Alertas de Pânico (SOS)', 'emergency-alerts', Icons.emergency_outlined),
    ('Livro de Plantão', 'shift-logs', Icons.menu_book_outlined),
    (
      'Reformas (NBR 16.280)',
      'renovation-requests',
      Icons.construction_outlined,
    ),
    ('Livro de Chaves', 'key-registry', Icons.key_outlined),
    ('Leituras de Água/Gás', 'utility-readings', Icons.speed_outlined),
    ('Vagas de Garagem', 'parking-spots', Icons.local_parking_outlined),
    ('Enquetes', 'polls', Icons.poll_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _telemetry = AdminTelemetryService(api: _api, token: widget.token);
    _telemetry.start();
    _summary = _loadSummary();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.api != widget.api) {
      if (oldWidget.api == null && widget.api == null) {
        _api.dispose();
      }
      _api = widget.api ?? HomeService(token: widget.token);
      _telemetry.updateCredentials(api: _api, token: widget.token);
      _summary = _loadSummary();
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _telemetry.dispose();
    if (widget.api == null) {
      _api.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.get('/users/me');
      if (mounted && data is Map<String, dynamic>) {
        setState(() => _profile = data);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _loadSummary() async {
    Map<String, dynamic>? merged;
    try {
      final overview = await _api.get('/admin/overview');
      if (overview is Map<String, dynamic>) {
        final moduleVolumes = (overview['moduleVolumes'] as Map?) ?? {};
        merged = Map<String, dynamic>.from(overview);
        moduleVolumes.forEach((k, v) {
          merged![k.toString()] = v;
        });
      }
    } catch (_) {}

    if (merged == null) {
      final result = await _api.get('/admin/dashboard');
      if (result is! Map<String, dynamic>) {
        throw const FormatException(
          'Resposta inválida do painel administrativo.',
        );
      }
      merged = Map<String, dynamic>.from(result);
    }

    try {
      final results = await Future.wait<dynamic>([
        _safeGet('/admin/diagnostics'),
        _safeGet('/admin/data/condominiums?page=0&size=50'),
      ]);
      final diagnostics = results[0];
      if (diagnostics is Map<String, dynamic> && diagnostics.isNotEmpty) {
        merged['diagnostics'] = diagnostics;
      }
      final condos = results[1];
      if (condos is Map && condos['content'] is List) {
        merged['condominiumList'] = (condos['content'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}

    return merged;
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await _api.get(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async => setState(() => _summary = _loadSummary());

  Future<void> _openCreateCondominium() async {
    final created = await showCreateCondominiumDialog(
      context: context,
      api: _api,
    );
    if (created != null && mounted) {
      _refresh();
      final condoId = (created['id'] as num?)?.toInt();
      final condoName = created['name']?.toString() ?? 'Condomínio';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$condoName criado com sucesso!'),
          action: condoId != null
              ? SnackBarAction(
                  label: 'Síndicos',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MembershipManagementPage(
                          api: _api,
                          condominiumId: condoId,
                          isSystemAdmin: true,
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _openCreateAnyEntityMenu() async {
    final selected = await showModalBottomSheet<(String, String, IconData)>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Criar entrada no banco de dados',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                subtitle: Text(
                  'Escolha a entidade que deseja cadastrar (com seleção da entidade pai)',
                ),
              ),
              const Divider(height: 1),
              ...kAdminCreatableResources.map(
                (entry) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8ECFF),
                    child: Icon(entry.$3, color: const Color(0xFF2F3FB0)),
                  ),
                  title: Text(
                    entry.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.pop(sheetContext, entry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final created = await showCreateAdminResourceDialog(
      context: context,
      api: _api,
      resource: selected.$2,
      title: selected.$1,
    );
    if (created != null && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Novo registro em "${selected.$1}" criado com sucesso!',
          ),
        ),
      );
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          token: widget.token,
          userName: widget.userName,
          userEmail: widget.userEmail,
          provider: widget.authProvider,
          onLogout: widget.onLogout,
          onClose: () {
            Navigator.of(context).pop();
            _loadProfile();
          },
          reauthenticateWithGoogle: widget.reauthenticateWithGoogle,
          refreshWithCredentials: widget.refreshWithCredentials,
          refreshGoogleSession: widget.refreshGoogleSession,
        ),
      ),
    );
  }

  List<AncoraCommandAction> _commandActions(BuildContext context) => [
    AncoraCommandAction(
      id: 'admin-overview',
      title: 'Visão Geral do Console',
      subtitle: 'Métricas globais e tabelas do sistema',
      category: 'Navegação',
      icon: Icons.dashboard_outlined,
      onExecute: () => setState(() {
        _activeTab = 'overview';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-infrastructure',
      title: 'Infraestrutura & Servidor',
      subtitle: 'CPU, RAM, JVM, Disco, Rede e Threads',
      category: 'Navegação',
      icon: Icons.memory_rounded,
      onExecute: () => setState(() {
        _activeTab = 'infrastructure';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-application',
      title: 'Aplicação & API',
      subtitle: 'RPM, p50/p95/p99, Status HTTP e Endpoints',
      category: 'Navegação',
      icon: Icons.speed_rounded,
      onExecute: () => setState(() {
        _activeTab = 'application';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-database',
      title: 'Banco de Dados',
      subtitle: 'Pool HikariCP, Tabelas e Consultas Lentas',
      category: 'Navegação',
      icon: Icons.storage_rounded,
      onExecute: () => setState(() {
        _activeTab = 'database';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-analytics',
      title: 'Analytics & Negócio',
      subtitle: 'Condomínios, Planos, Usuários e Uso por Módulo',
      category: 'Navegação',
      icon: Icons.insights_rounded,
      onExecute: () => setState(() {
        _activeTab = 'analytics';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-alerts',
      title: 'Central de Alertas',
      subtitle: 'Incidentes ativos, reconhecimento e resolução',
      category: 'Navegação',
      icon: Icons.notifications_active_outlined,
      onExecute: () => setState(() {
        _activeTab = 'alerts';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-audit',
      title: 'Logs e Auditoria',
      subtitle: 'Trilha imutável de operações',
      category: 'Navegação',
      icon: Icons.shield_outlined,
      onExecute: () => setState(() {
        _activeTab = 'auditLogs';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-diagnostics',
      title: 'Saúde e Diagnóstico',
      subtitle: 'Status do cluster, banco e JVM',
      category: 'Navegação',
      icon: Icons.monitor_heart_outlined,
      onExecute: () => setState(() {
        _activeTab = 'diagnostics';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-permissions',
      title: 'Permissões e Papéis (RBAC)',
      subtitle: 'Perfis e matriz de acesso',
      category: 'Navegação',
      icon: Icons.lock_person_outlined,
      onExecute: () => setState(() {
        _activeTab = 'permissions';
        _selectedResourceKey = null;
        _selectedResourceTitle = null;
      }),
    ),
    AncoraCommandAction(
      id: 'admin-new-condo',
      title: 'Novo Condomínio',
      subtitle: 'Cadastrar condomínio e vincular síndico',
      category: 'Ações Rápidas',
      icon: Icons.domain_add_outlined,
      onExecute: _openCreateCondominium,
    ),
    AncoraCommandAction(
      id: 'admin-new-record',
      title: 'Criar Registro',
      subtitle: 'Inserir entidade no banco de dados',
      category: 'Ações Rápidas',
      icon: Icons.add_circle_outline,
      onExecute: _openCreateAnyEntityMenu,
    ),
    ..._resources.take(12).map(
      (res) => AncoraCommandAction(
        id: 'entity-${res.$2}',
        title: res.$1,
        subtitle: 'Gerenciar registros de ${res.$1.toLowerCase()}',
        category: 'Entidades',
        icon: res.$3,
        onExecute: () => _openResource(res.$1, res.$2),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AncoraCommandShortcutWrapper(
      actions: _commandActions(context),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? SaaSColors.deepNavy
                  : const Color(0xFFF8FAFC),
              body: const Center(
                child: SaaSLoadingState(
                  message: 'Carregando painel administrativo global...',
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SaaSErrorState(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  ),
                ),
              ),
            );
          }
          final data = snapshot.data!;
          if (ResponsiveLayout.isDesktop(context)) {
            return _buildDesktopAdminLayout(context, data);
          }
          return _buildMobileAdminLayout(context, data);
        },
      ),
    );
  }

  Widget _buildDesktopAdminLayout(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? SaaSColors.deepNavy : const Color(0xFFF8FAFC);
    final sidebarBg = isDark ? SaaSColors.cardNavy : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // 1. Collapsible Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: _sidebarCollapsed ? 76 : 270,
            decoration: BoxDecoration(
              color: sidebarBg,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: LayoutBuilder(
              builder: (sidebarCtx, sidebarConstraints) {
                final effectiveCollapsed =
                    _sidebarCollapsed || sidebarConstraints.maxWidth < 190;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sidebar Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        effectiveCollapsed ? 12 : 16,
                        18,
                        effectiveCollapsed ? 12 : 12,
                        14,
                      ),
                      child: Row(
                        mainAxisAlignment: effectiveCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _sidebarCollapsed
                                ? () =>
                                      setState(() => _sidebarCollapsed = false)
                                : null,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF1D4ED8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          if (!effectiveCollapsed) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Âncora Admin',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'CONSOLE GLOBAL',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: SaaSColors.muted(context),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Recolher menu',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _sidebarCollapsed = true),
                              icon: Icon(
                                Icons.keyboard_double_arrow_left_rounded,
                                size: 18,
                                color: SaaSColors.muted(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Navigation List (Expanded with internal scroll)
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: effectiveCollapsed ? 8 : 12,
                          vertical: 12,
                        ),
                        children: [
                          if (!effectiveCollapsed)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                bottom: 6,
                              ),
                              child: Text(
                                'CENTRAL DE COMANDO',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: SaaSColors.muted(context),
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                          _buildSidebarItem(
                            icon: Icons.dashboard_outlined,
                            label: 'Visão Geral',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'overview' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'overview';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.memory_rounded,
                            label: 'Infraestrutura & Servidor',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'infrastructure' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'infrastructure';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.speed_rounded,
                            label: 'Aplicação & API',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'application' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'application';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.storage_rounded,
                            label: 'Banco de Dados',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'database' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'database';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.insights_rounded,
                            label: 'Analytics & Negócio',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'analytics' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'analytics';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.notifications_active_outlined,
                            label: 'Central de Alertas',
                            count: _telemetry.activeAlertsCount > 0
                                ? _telemetry.activeAlertsCount
                                : null,
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'alerts' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'alerts';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.shield_outlined,
                            label: 'Logs e Auditoria',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'auditLogs' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'auditLogs';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.monitor_heart_outlined,
                            label: 'Saúde e Diagnóstico',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'diagnostics' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'diagnostics';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          _buildSidebarItem(
                            icon: Icons.lock_person_outlined,
                            label: 'Permissões e Papéis',
                            collapsed: effectiveCollapsed,
                            isSelected:
                                _activeTab == 'permissions' &&
                                _selectedResourceKey == null,
                            onTap: () => setState(() {
                              _activeTab = 'permissions';
                              _selectedResourceKey = null;
                              _selectedResourceTitle = null;
                            }),
                          ),
                          const SizedBox(height: 14),
                          if (!effectiveCollapsed)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                bottom: 6,
                              ),
                              child: Text(
                                'ENTIDADES DO BANCO',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: SaaSColors.muted(context),
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                          ..._resources.map((res) {
                            final count = data[_countKey(res.$2)] ?? 0;
                            final isSelected = _selectedResourceKey == res.$2;
                            return _buildSidebarItem(
                              icon: res.$3,
                              label: res.$1,
                              count: count,
                              collapsed: effectiveCollapsed,
                              isSelected: isSelected,
                              onTap: () => setState(() {
                                _selectedResourceKey = res.$2;
                                _selectedResourceTitle = res.$1;
                              }),
                            );
                          }),
                        ],
                      ),
                    ),

                    const Divider(height: 1),
                    // Admin account footer
                    Padding(
                      padding: EdgeInsets.all(effectiveCollapsed ? 8 : 12),
                      child: InkWell(
                        onTap: _openProfile,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: effectiveCollapsed
                              ? Center(
                                  child: Tooltip(
                                    message: widget.userName ?? 'Administrador',
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: SaaSColors.primary
                                          .withValues(alpha: 0.15),
                                      backgroundImage: _profileAvatarImage,
                                      child: _profileAvatarImage == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 20,
                                              color: SaaSColors.primary,
                                            )
                                          : null,
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 17,
                                      backgroundColor: SaaSColors.primary
                                          .withValues(alpha: 0.15),
                                      backgroundImage: _profileAvatarImage,
                                      child: _profileAvatarImage == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 20,
                                              color: SaaSColors.primary,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.userName ?? 'Administrador',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            widget.userEmail ??
                                                'admin@ancora.com',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: SaaSColors.muted(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Sair',
                                      icon: const Icon(Icons.logout, size: 18),
                                      onPressed: widget.onLogout,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Main Content Area (Expanded, 100% height, zero outer scroll)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action Header Strip
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? SaaSColors.cardNavy : Colors.white,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: _sidebarCollapsed
                            ? 'Expandir menu lateral'
                            : 'Recolher menu lateral',
                        onPressed: () => setState(
                          () => _sidebarCollapsed = !_sidebarCollapsed,
                        ),
                        icon: Icon(
                          _sidebarCollapsed
                              ? Icons.view_sidebar_rounded
                              : Icons.menu_open_rounded,
                          size: 20,
                          color: SaaSColors.muted(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedResourceKey != null) ...[
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _selectedResourceKey = null;
                                  _selectedResourceTitle = null;
                                }),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: const Text('Visão Geral'),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '/',
                                style: TextStyle(
                                  color: SaaSColors.muted(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _selectedResourceTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Flexible(
                                child: Text(
                                  switch (_activeTab) {
                                    'infrastructure' =>
                                      'Infraestrutura & Servidor',
                                    'application' =>
                                      'Observabilidade da Aplicação & API',
                                    'database' =>
                                      'Monitoramento do Banco de Dados',
                                    'analytics' =>
                                      'Analytics & Utilização da Plataforma',
                                    'alerts' =>
                                      'Central de Alertas & Incidentes',
                                    'auditLogs' =>
                                      'Logs e Auditoria do Sistema',
                                    'diagnostics' =>
                                      'Saúde e Diagnóstico do Cluster',
                                    'permissions' =>
                                      'Matriz de Permissões e Perfis (RBAC)',
                                    _ =>
                                      'Console Global • Administrador do Sistema',
                                  },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SaaSBadge(
                                label: switch (_activeTab) {
                                  'auditLogs' => 'Registros Imutáveis',
                                  'diagnostics' => 'Métricas em Tempo Real',
                                  'permissions' => '4 Perfis do Sistema',
                                  _ =>
                                    'Olá, ${firstNameOf(widget.userName, fallback: 'Admin')}',
                                },
                                variant: switch (_activeTab) {
                                  'auditLogs' => SaaSBadgeVariant.primary,
                                  'diagnostics' => SaaSBadgeVariant.success,
                                  'permissions' => SaaSBadgeVariant.purple,
                                  _ => SaaSBadgeVariant.primary,
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => AncoraCommandShortcutWrapper.open(
                                context,
                                _commandActions(context),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 15,
                                      color: SaaSColors.muted(context),
                                    ),
                                    if (MediaQuery.sizeOf(context).width >= 1540) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'Busca universal',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: SaaSColors.muted(context),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        'Ctrl+K',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const AncoraConnectionStatusPill(),
                            if (MediaQuery.sizeOf(context).width >= 1520) ...[
                              const SizedBox(width: 8),
                              const AncoraLiveClockPill(),
                            ],
                            const SizedBox(width: 8),
                            if (widget.currentRole != null &&
                                widget.onSwitchRole != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: RoleSwitcherPill(
                                  currentRole: widget.currentRole!,
                                  availableRoles: widget.availableRoles,
                                  onSwitchRole: widget.onSwitchRole!,
                                ),
                              ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: SaaSColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _openCreateCondominium,
                              icon: const Icon(
                                Icons.domain_add_outlined,
                                size: 17,
                              ),
                              label: const Text('Novo condomínio'),
                            ),
                            const SizedBox(width: 8),
                            AncoraContextMenu<String>(
                              tooltip: 'Mais ações administrativas',
                              onSelected: (action) {
                                if (action == 'create_entity') {
                                  _openCreateAnyEntityMenu();
                                } else if (action == 'announcement') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          SystemAnnouncementPage(api: _api),
                                    ),
                                  );
                                }
                              },
                              options: const [
                                AncoraMenuOption(
                                  value: 'create_entity',
                                  label: 'Criar registro no banco',
                                  icon: Icons.add_circle_outline,
                                ),
                                AncoraMenuOption(
                                  value: 'announcement',
                                  label: 'Publicar aviso geral',
                                  icon: Icons.campaign_outlined,
                                ),
                              ],
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.bolt_rounded, size: 16),
                                label: const Text('Ações'),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Atualizar dados',
                              icon: const Icon(Icons.refresh),
                              onPressed: _refresh,
                            ),
                            IconButton(
                              tooltip: 'Minha conta',
                              icon: const Icon(Icons.person_outline),
                              onPressed: _openProfile,
                            ),
                            IconButton(
                              tooltip: isDark ? 'Modo claro' : 'Modo escuro',
                              icon: Icon(
                                isDark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                              ),
                              onPressed: () {
                                AppTheme.themeModeNotifier.value = isDark
                                    ? ThemeMode.light
                                    : ThemeMode.dark;
                              },
                            ),
                          ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content View (Expanded, zero outer scroll)
                Expanded(
                  child: AncoraAnimatedSwitcher(
                    child: KeyedSubtree(
                      key: ValueKey(_selectedResourceKey ?? _activeTab),
                      child: _selectedResourceKey != null
                          ? _AdminResourceView(
                              key: ValueKey(_selectedResourceKey),
                              api: _api,
                              title: _selectedResourceTitle!,
                              resource: _selectedResourceKey!,
                              isEmbedded: true,
                              onBack: () => setState(() {
                                _selectedResourceKey = null;
                                _selectedResourceTitle = null;
                              }),
                            )
                          : switch (_activeTab) {
                              'infrastructure' => AdminInfrastructureView(
                                telemetry: _telemetry,
                                onOpenAlerts: () =>
                                    setState(() => _activeTab = 'alerts'),
                              ),
                              'application' => AdminApplicationView(
                                telemetry: _telemetry,
                                onOpenAlerts: () =>
                                    setState(() => _activeTab = 'alerts'),
                              ),
                              'database' => AdminDatabaseView(
                                telemetry: _telemetry,
                                onOpenAlerts: () =>
                                    setState(() => _activeTab = 'alerts'),
                              ),
                              'analytics' => AdminAnalyticsView(
                                telemetry: _telemetry,
                                condominiums: (data['condominiumList'] is List)
                                    ? (data['condominiumList'] as List)
                                          .whereType<Map>()
                                          .map((e) => Map<String, dynamic>.from(e))
                                          .toList()
                                    : const [],
                              ),
                              'alerts' => AdminAlertsView(telemetry: _telemetry),
                              'auditLogs' => AdminAuditLogView(api: _api),
                              'diagnostics' => AdminDiagnosticsView(api: _api),
                              'permissions' => AdminPermissionsView(api: _api),
                              _ => _buildOverviewContent(
                                context,
                                data,
                                isDark,
                                borderColor,
                              ),
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  Widget _buildOverviewContent(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
    Color borderColor,
  ) {
    final activeCondos =
        (data['activeCondominiums'] as num?)?.toInt() ??
        (data['condominiums'] as num?)?.toInt() ??
        0;
    final totalCondos = (data['condominiums'] as num?)?.toInt() ?? activeCondos;
    final usersByRole = data['usersByRole'] is Map
        ? Map<String, dynamic>.from(data['usersByRole'] as Map)
        : const <String, dynamic>{};
    final adminUsers =
        ((usersByRole['ROLE_ADMIN'] as num?)?.toInt() ?? 0) +
        ((usersByRole['ROLE_MANAGER'] as num?)?.toInt() ?? 0);
    final totalUsers = (data['users'] as num?)?.toInt() ?? 0;
    final adminUsersDisplay = usersByRole.isNotEmpty ? adminUsers : totalUsers;
    final residentsCount = (data['residents'] as num?)?.toInt() ?? 0;
    final unitsCount = (data['units'] as num?)?.toInt() ?? 0;
    final membershipsCount = (data['memberships'] as num?)?.toInt() ?? 0;

    final diagnostics = data['diagnostics'] is Map
        ? Map<String, dynamic>.from(data['diagnostics'] as Map)
        : null;
    final jvm = diagnostics?['jvm'] is Map
        ? Map<String, dynamic>.from(diagnostics!['jvm'] as Map)
        : null;
    final database = diagnostics?['database'] is Map
        ? Map<String, dynamic>.from(diagnostics!['database'] as Map)
        : null;
    final overallStatus = diagnostics?['overallStatus']?.toString();
    final uptimeSeconds = (jvm?['uptimeSeconds'] as num?)?.toInt();
    final dbLatencyMs = database?['latencyMs'];
    final healthValue = uptimeSeconds != null
        ? _formatUptime(uptimeSeconds)
        : (overallStatus ?? '${data['activeSseConnections'] ?? 0} SSE');
    final healthSubtitle = overallStatus != null
        ? '$overallStatus${dbLatencyMs != null ? ' • DB ${dbLatencyMs}ms' : ''}'
        : '${data['connectedRealtimeUsers'] ?? 0} usuários em tempo real';

    final condoList = (data['condominiumList'] is List)
        ? (data['condominiumList'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];

    final visibleResources = _showAllEntities
        ? _resources
        : _resources.take(12).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminLiveToolbar(
            telemetry: _telemetry,
            onOpenAlerts: () => setState(() => _activeTab = 'alerts'),
          ),
          const SizedBox(height: 16),

          // 4 Global Metric Cards + live sparklines
          ListenableBuilder(
            listenable: _telemetry,
            builder: (context, _) {
              final series = AdminTelemetryHelpers.asMapList(
                _telemetry.snapshot?['timeSeries'],
              );
              final cpuSpark = AdminTelemetryHelpers.extractSeries(
                series,
                'systemCpuPercent',
              );
              final heapSpark = AdminTelemetryHelpers.extractSeries(
                series,
                'heapUsagePercent',
              );
              final rpmSpark = AdminTelemetryHelpers.extractSeries(
                series,
                'requestsPerMinute',
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SaaSMetricCard(
                          title: 'Condomínios Ativos',
                          value: '$activeCondos',
                          icon: Icons.apartment_outlined,
                          iconColor: SaaSColors.primary,
                          subtitle: '$totalCondos cadastrados no sistema',
                          onTap: () => setState(() {
                            _selectedResourceKey = 'condominiums';
                            _selectedResourceTitle = 'Condomínios';
                          }),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SaaSMetricCard(
                          title: 'Usuários Administrativos',
                          value: '$adminUsersDisplay',
                          icon: Icons.admin_panel_settings_outlined,
                          iconColor: SaaSColors.purple,
                          subtitle: '$totalUsers usuários no total',
                          sparklineValues: rpmSpark,
                          onTap: () => setState(() {
                            _selectedResourceKey = 'users';
                            _selectedResourceTitle = 'Usuários';
                          }),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SaaSMetricCard(
                          title: 'Moradores Vinculados',
                          value: '$residentsCount',
                          icon: Icons.groups_outlined,
                          iconColor: SaaSColors.success,
                          subtitle: '$unitsCount unidades • $membershipsCount vínculos',
                          sparklineValues: cpuSpark,
                          onTap: () => setState(() {
                            _selectedResourceKey = 'residents';
                            _selectedResourceTitle = 'Moradores';
                          }),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SaaSMetricCard(
                          title: 'Saúde & Uptime Real',
                          value: healthValue,
                          icon: Icons.monitor_heart_outlined,
                          iconColor: overallStatus == 'DOWN'
                              ? SaaSColors.error
                              : SaaSColors.success,
                          subtitle: healthSubtitle,
                          sparklineValues: heapSpark,
                          onTap: () => setState(() {
                            _activeTab = 'diagnostics';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Executive Live Charts Row
                  _buildOverviewChartsRow(series, usersByRole, totalUsers),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Work Area 2 Columns
          SizedBox(
            height: 520,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Pane: Search + Recent Audit Logs (Flex 5)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: SaaSGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SaaSSectionHeader(
                                title: 'Pesquisa Global & Filtros',
                                subtitle:
                                    'Filtre por condomínio, entidade ou auditoria',
                                action: SaaSBadge(
                                  label: 'Enter / Buscar',
                                  variant: SaaSBadgeVariant.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: _AdminSearch(
                                    api: _api,
                                    condominiums: condoList,
                                    resources: _resources,
                                    onOpenResource: _openResource,
                                    onChanged: _refresh,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        flex: 5,
                        child: _buildRecentAuditCard(
                          context,
                          data,
                          isDark,
                          borderColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Right Pane: Database Explorer Grid 3x4 (Flex 7)
                Expanded(
                  flex: 7,
                  child: SaaSGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SaaSSectionHeader(
                          title: 'Entidades & Tabelas',
                          subtitle:
                              'Selecione uma tabela para gerenciar seus registros',
                          action: TextButton.icon(
                            onPressed: () => setState(
                              () => _showAllEntities = !_showAllEntities,
                            ),
                            icon: Icon(
                              _showAllEntities
                                  ? Icons.grid_view_rounded
                                  : Icons.unfold_more_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _showAllEntities
                                  ? 'Principais (12)'
                                  : 'Ver todas (${_resources.length})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.7,
                                ),
                            itemCount: visibleResources.length,
                            itemBuilder: (context, idx) {
                              final res = visibleResources[idx];
                              final count = data[_countKey(res.$2)] ?? 0;
                              final badgeColor = _entityAccentColor(res.$2);
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() {
                                  _selectedResourceKey = res.$2;
                                  _selectedResourceTitle = res.$1;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? SaaSColors.deepNavy.withValues(
                                            alpha: 0.72,
                                          )
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: badgeColor.withValues(
                                          alpha: 0.14,
                                        ),
                                        child: Icon(
                                          res.$3,
                                          color: badgeColor,
                                          size: 19,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              res.$1,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$count registros',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: SaaSColors.muted(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 17,
                                        color: SaaSColors.muted(context),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewChartsRow(
    List<Map<String, dynamic>> series,
    Map<String, dynamic> usersByRole,
    int totalUsers,
  ) {
    final xLabels = AdminTelemetryHelpers.extractTimeLabels(series);
    final sysCpu = AdminTelemetryHelpers.extractSeries(
      series,
      'systemCpuPercent',
    );
    final heapPct = AdminTelemetryHelpers.extractSeries(
      series,
      'heapUsagePercent',
    );
    final rpm = AdminTelemetryHelpers.extractSeries(series, 'requestsPerMinute');
    final p95 = AdminTelemetryHelpers.extractSeries(series, 'p95LatencyMs');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AncoraChartCard(
            title: 'CPU & JVM Heap ao Vivo',
            subtitle: 'Carga do servidor e consumo de memória',
            unit: '%',
            height: 165,
            isEmpty: sysCpu.isEmpty,
            trailing: TextButton(
              onPressed: () => setState(() => _activeTab = 'infrastructure'),
              child: const Text('Detalhes', style: TextStyle(fontSize: 11.5)),
            ),
            legendItems: const [
              (label: 'CPU (%)', color: AncoraChartPalette.indigo),
              (label: 'Heap (%)', color: AncoraChartPalette.violet),
            ],
            child: AncoraLineAreaChart(
              unitSuffix: '%',
              maxYOverride: 100,
              xLabels: xLabels,
              series: [
                AncoraChartSeries(
                  label: 'CPU',
                  values: sysCpu,
                  color: AncoraChartPalette.indigo,
                  fillArea: true,
                ),
                AncoraChartSeries(
                  label: 'Heap',
                  values: heapPct,
                  color: AncoraChartPalette.violet,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AncoraChartCard(
            title: 'Tráfego HTTP & Latência p95',
            subtitle: 'Requisições por minuto e tempo de resposta',
            height: 165,
            isEmpty: rpm.isEmpty,
            trailing: TextButton(
              onPressed: () => setState(() => _activeTab = 'application'),
              child: const Text('API', style: TextStyle(fontSize: 11.5)),
            ),
            legendItems: const [
              (label: 'RPM', color: AncoraChartPalette.cyan),
              (label: 'p95 (ms)', color: AncoraChartPalette.amber),
            ],
            child: AncoraLineAreaChart(
              xLabels: xLabels,
              series: [
                AncoraChartSeries(
                  label: 'RPM',
                  values: rpm,
                  color: AncoraChartPalette.cyan,
                  fillArea: true,
                ),
                AncoraChartSeries(
                  label: 'p95 (ms)',
                  values: p95,
                  color: AncoraChartPalette.amber,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AncoraChartCard(
            title: 'Usuários por Perfil',
            subtitle: 'Distribuição RBAC da plataforma',
            height: 165,
            trailing: TextButton(
              onPressed: () => setState(() => _activeTab = 'analytics'),
              child: const Text('Analytics', style: TextStyle(fontSize: 11.5)),
            ),
            child: AncoraDonutChart(
              centerLabel: 'Total',
              centerValue: '$totalUsers',
              slices: [
                AncoraDonutSlice(
                  label: 'Moradores',
                  value: AdminTelemetryHelpers.asDouble(
                    usersByRole['ROLE_RESIDENT'],
                  ),
                  color: AncoraChartPalette.emerald,
                ),
                AncoraDonutSlice(
                  label: 'Porteiros',
                  value: AdminTelemetryHelpers.asDouble(
                    usersByRole['ROLE_DOORMAN'],
                  ),
                  color: AncoraChartPalette.cyan,
                ),
                AncoraDonutSlice(
                  label: 'Síndicos',
                  value: AdminTelemetryHelpers.asDouble(
                    usersByRole['ROLE_MANAGER'],
                  ),
                  color: AncoraChartPalette.indigo,
                ),
                AncoraDonutSlice(
                  label: 'Admins',
                  value: AdminTelemetryHelpers.asDouble(
                    usersByRole['ROLE_ADMIN'],
                  ),
                  color: AncoraChartPalette.violet,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _entityAccentColor(String key) => switch (key) {
    'condominiums' || 'sectors' || 'units' => SaaSColors.primary,
    'residents' || 'memberships' || 'users' => SaaSColors.purple,
    'packages' || 'package-history' || 'reservations' => SaaSColors.success,
    'announcements' || 'notifications' => SaaSColors.warning,
    _ => SaaSColors.primary,
  };

  Widget _buildRecentAuditCard(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
    Color borderColor,
  ) {
    final logs = (data['recentAuditLogs'] is List)
        ? (data['recentAuditLogs'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];

    return SaaSGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SaaSSectionHeader(
            title: 'Atividades Recentes (Auditoria)',
            subtitle: 'Eventos reais registrados no sistema',
            action: TextButton(
              onPressed: () => setState(() {
                _activeTab = 'auditLogs';
                _selectedResourceKey = null;
                _selectedResourceTitle = null;
              }),
              child: const Text('Ver tudo', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum log recente registrado.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 10,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final action = log['action']?.toString() ?? 'EVENTO';
                      final entity = log['entityType']?.toString() ?? '';
                      final actor =
                          log['actorEmail']?.toString() ??
                          log['actorName']?.toString() ??
                          'Sistema';
                      final createdAt = formatDateTime(
                        log['createdAt']?.toString(),
                      );
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: action.contains('DELETE')
                                  ? SaaSColors.error
                                  : (action.contains('CREATE')
                                        ? SaaSColors.success
                                        : SaaSColors.primary),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$action${entity.isNotEmpty ? ' • $entity' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$actor • $createdAt',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: SaaSColors.muted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    dynamic count,
    required bool isSelected,
    required VoidCallback onTap,
    bool collapsed = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: collapsed ? label : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: collapsed ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: isDark
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFBFDBFE),
                    )
                  : null,
            ),
            child: collapsed
                ? Center(
                    child: Badge(
                      isLabelVisible: count != null,
                      label: Text('$count'),
                      child: Icon(
                        icon,
                        size: 19,
                        color: isSelected
                            ? SaaSColors.primary
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569)),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? SaaSColors.primary
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? SaaSColors.primary
                                : (isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                      if (count != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SaaSColors.primary.withValues(alpha: 0.15)
                                : (isDark
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? SaaSColors.primary
                                  : (isDark
                                        ? Colors.white70
                                        : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAdminLayout(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final condoList = (data['condominiumList'] is List)
        ? (data['condominiumList'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];
    final activeCondos =
        (data['activeCondominiums'] as num?)?.toInt() ??
        (data['condominiums'] as num?)?.toInt() ??
        0;
    final residentsCount = (data['residents'] as num?)?.toInt() ?? 0;
    final totalUsers = (data['users'] as num?)?.toInt() ?? 0;
    final diagnostics = data['diagnostics'] is Map
        ? Map<String, dynamic>.from(data['diagnostics'] as Map)
        : null;
    final overallStatus = diagnostics?['overallStatus']?.toString();
    final uptimeSeconds =
        (diagnostics?['jvm']?['uptimeSeconds'] as num?)?.toInt();
    final healthValue = uptimeSeconds != null
        ? _formatUptime(uptimeSeconds)
        : (overallStatus ?? '${data['activeSseConnections'] ?? 0} SSE');

    return Scaffold(
      backgroundColor: isDark ? SaaSColors.deepNavy : const Color(0xFFF8FAFC),
      drawer: Drawer(
        backgroundColor: isDark ? SaaSColors.cardNavy : Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Âncora Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Builder(
                  builder: (drawerCtx) => ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildSidebarItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Visão Geral',
                        isSelected:
                            _activeTab == 'overview' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'overview';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.memory_rounded,
                        label: 'Infraestrutura & Servidor',
                        isSelected:
                            _activeTab == 'infrastructure' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'infrastructure';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.speed_rounded,
                        label: 'Aplicação & API',
                        isSelected:
                            _activeTab == 'application' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'application';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.storage_rounded,
                        label: 'Banco de Dados',
                        isSelected:
                            _activeTab == 'database' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'database';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.insights_rounded,
                        label: 'Analytics & Negócio',
                        isSelected:
                            _activeTab == 'analytics' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'analytics';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.notifications_active_outlined,
                        label: 'Central de Alertas',
                        count: _telemetry.activeAlertsCount > 0
                            ? _telemetry.activeAlertsCount
                            : null,
                        isSelected:
                            _activeTab == 'alerts' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'alerts';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.shield_outlined,
                        label: 'Logs e Auditoria',
                        isSelected:
                            _activeTab == 'auditLogs' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'auditLogs';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.monitor_heart_outlined,
                        label: 'Saúde e Diagnóstico',
                        isSelected:
                            _activeTab == 'diagnostics' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'diagnostics';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      _buildSidebarItem(
                        icon: Icons.lock_person_outlined,
                        label: 'Permissões e Papéis',
                        isSelected:
                            _activeTab == 'permissions' &&
                            _selectedResourceKey == null,
                        onTap: () {
                          Navigator.of(drawerCtx).pop();
                          setState(() {
                            _activeTab = 'permissions';
                            _selectedResourceKey = null;
                            _selectedResourceTitle = null;
                          });
                        },
                      ),
                      const Divider(height: 20),
                      ..._resources.map((res) {
                        final count = data[_countKey(res.$2)] ?? 0;
                        return _buildSidebarItem(
                          icon: res.$3,
                          label: res.$1,
                          count: count,
                          isSelected: _selectedResourceKey == res.$2,
                          onTap: () {
                            Navigator.of(drawerCtx).pop();
                            setState(() {
                              _selectedResourceKey = res.$2;
                              _selectedResourceTitle = res.$1;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          _selectedResourceTitle ??
              switch (_activeTab) {
                'infrastructure' => 'Infraestrutura & Servidor',
                'application' => 'Aplicação & API',
                'database' => 'Banco de Dados',
                'analytics' => 'Analytics & Negócio',
                'alerts' => 'Central de Alertas',
                'auditLogs' => 'Logs e Auditoria',
                'diagnostics' => 'Saúde e Diagnóstico',
                'permissions' => 'Permissões e Papéis',
                _ => 'Console Global',
              },
        ),
        backgroundColor: isDark
            ? SaaSColors.cardNavy
            : const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Minha conta',
            onPressed: _openProfile,
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white24,
              backgroundImage: _profileAvatarImage,
              child: _profileAvatarImage == null
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AncoraContextMenu<String>(
              tooltip: 'Ações rápidas',
              onSelected: (action) {
                if (action == 'theme') {
                  AppTheme.themeModeNotifier.value = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                } else if (action == 'new_condo') {
                  _openCreateCondominium();
                } else if (action == 'create_entity') {
                  _openCreateAnyEntityMenu();
                } else if (action == 'announcement') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SystemAnnouncementPage(api: _api),
                    ),
                  );
                } else if (action == 'logout') {
                  widget.onLogout();
                }
              },
              options: [
                AncoraMenuOption(
                  value: 'theme',
                  label: isDark ? 'Modo claro' : 'Modo escuro',
                  icon: isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                const AncoraMenuOption(
                  value: 'new_condo',
                  label: 'Novo condomínio',
                  icon: Icons.domain_add_outlined,
                ),
                const AncoraMenuOption(
                  value: 'create_entity',
                  label: 'Criar entrada no banco',
                  icon: Icons.add_circle_outline,
                ),
                const AncoraMenuOption(
                  value: 'announcement',
                  label: 'Publicar aviso geral',
                  icon: Icons.campaign_outlined,
                ),
                const AncoraMenuOption(
                  value: 'logout',
                  label: 'Sair',
                  icon: Icons.logout_rounded,
                  isDanger: true,
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_vert_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: _selectedResourceKey != null
          ? _AdminResourceView(
              key: ValueKey(_selectedResourceKey),
              api: _api,
              title: _selectedResourceTitle!,
              resource: _selectedResourceKey!,
              isEmbedded: true,
              onBack: () => setState(() {
                _selectedResourceKey = null;
                _selectedResourceTitle = null;
              }),
            )
          : _activeTab != 'overview'
          ? Column(
              children: [
                Material(
                  color: isDark ? SaaSColors.cardNavy : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _activeTab = 'overview';
                            _selectedResourceKey = null;
                          }),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Visão Geral'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: switch (_activeTab) {
                    'infrastructure' => AdminInfrastructureView(
                      telemetry: _telemetry,
                      onOpenAlerts: () =>
                          setState(() => _activeTab = 'alerts'),
                    ),
                    'application' => AdminApplicationView(
                      telemetry: _telemetry,
                      onOpenAlerts: () =>
                          setState(() => _activeTab = 'alerts'),
                    ),
                    'database' => AdminDatabaseView(
                      telemetry: _telemetry,
                      onOpenAlerts: () =>
                          setState(() => _activeTab = 'alerts'),
                    ),
                    'analytics' => AdminAnalyticsView(
                      telemetry: _telemetry,
                      condominiums: condoList,
                    ),
                    'alerts' => AdminAlertsView(telemetry: _telemetry),
                    'auditLogs' => AdminAuditLogView(api: _api),
                    'diagnostics' => AdminDiagnosticsView(api: _api),
                    'permissions' => AdminPermissionsView(api: _api),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ],
            )
          : LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth < 520
              ? (constraints.maxWidth - 52) / 2
              : constraints.maxWidth < 900
              ? (constraints.maxWidth - 66) / 3
              : (constraints.maxWidth - 96) / 4;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x282563EB),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AncoraConnectionStatusPill(),
                          AncoraLiveClockPill(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Olá, ${firstNameOf(widget.userName, fallback: 'administrador')}!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.userEmail ??
                                      'Console Global Multi-Condomínio',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1E3A8A),
                            ),
                            onPressed: _openCreateCondominium,
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Novo condomínio'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      label: 'Condomínios Ativos',
                      value: activeCondos,
                      icon: Icons.apartment_outlined,
                      onTap: () => _openResource('Condomínios', 'condominiums'),
                    ),
                    _MetricCard(
                      label: 'Usuários Totais',
                      value: totalUsers,
                      icon: Icons.people_alt_outlined,
                      onTap: () => _openResource('Usuários', 'users'),
                    ),
                    _MetricCard(
                      label: 'Moradores Vinculados',
                      value: residentsCount,
                      icon: Icons.groups_outlined,
                      onTap: () => _openResource('Moradores', 'residents'),
                    ),
                    _MetricCard(
                      label: 'Uptime / Cluster',
                      value: healthValue,
                      icon: Icons.monitor_heart_outlined,
                      onTap: () => setState(() {
                        _activeTab = 'diagnostics';
                        _selectedResourceKey = null;
                        _selectedResourceTitle = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Menu do administrador',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.add_circle_outline,
                      color: const Color(0xFF059669),
                      title: 'Criar registro',
                      subtitle: 'Cadastrar qualquer entidade e acoplar ao pai',
                      onTap: _openCreateAnyEntityMenu,
                    ),
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.domain_add_outlined,
                      color: const Color(0xFF2F3FB0),
                      title: 'Criar condomínio',
                      subtitle: 'Cadastrar condomínio e definir síndico',
                      onTap: _openCreateCondominium,
                    ),
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.apartment_outlined,
                      color: const Color(0xFF0E7490),
                      title: 'Condomínios',
                      subtitle: 'Gerenciar condomínios e síndicos',
                      onTap: () => _openResource('Condomínios', 'condominiums'),
                    ),
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF4338CA),
                      title: 'Usuários',
                      subtitle: 'Consultar contas e perfis de acesso',
                      onTap: () => _openResource('Usuários', 'users'),
                    ),
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.campaign_outlined,
                      color: const Color(0xFFB45309),
                      title: 'Aviso geral',
                      subtitle: 'Enviar comunicado para todo o sistema',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SystemAnnouncementPage(api: _api),
                        ),
                      ),
                    ),
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.shield_outlined,
                      color: const Color(0xFF4F46E5),
                      title: 'Logs e Auditoria',
                      subtitle: 'Trilha permanente e imutável de eventos',
                      onTap: () => setState(() {
                        _activeTab = 'auditLogs';
                        _selectedResourceKey = null;
                        _selectedResourceTitle = null;
                      }),
                    ),
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.monitor_heart_outlined,
                      color: const Color(0xFF059669),
                      title: 'Saúde e Diagnóstico',
                      subtitle: 'Telemetria, JVM, caches e latência',
                      onTap: () => setState(() {
                        _activeTab = 'diagnostics';
                        _selectedResourceKey = null;
                        _selectedResourceTitle = null;
                      }),
                    ),
                    _QuickActionCard(
                      width: cardWidth,
                      icon: Icons.lock_person_outlined,
                      color: const Color(0xFF7C3AED),
                      title: 'Permissões e Papéis',
                      subtitle: 'Matriz RBAC e planos de assinatura',
                      onTap: () => setState(() {
                        _activeTab = 'permissions';
                        _selectedResourceKey = null;
                        _selectedResourceTitle = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _AdminSearch(
                  api: _api,
                  condominiums: condoList,
                  resources: _resources,
                  onOpenResource: _openResource,
                  onChanged: _refresh,
                ),
                const SizedBox(height: 22),
                Text(
                  'Resumo geral do banco de dados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _resources
                      .map(
                        (entry) => SizedBox(
                          width: cardWidth,
                          child: _MetricCard(
                            label: entry.$1,
                            value: data[_countKey(entry.$2)] ?? 0,
                            icon: entry.$3,
                            onTap: () => _openResource(entry.$1, entry.$2),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    title: const Text('Conta administrativa'),
                    subtitle: Text(
                      '${widget.userName ?? 'Ancora Admin'} · ${widget.userEmail ?? ''}',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _countKey(String resource) => switch (resource) {
    'common-areas' => 'commonAreas',
    'billing-plans' => 'billingPlans',
    'package-history' => 'packageHistory',
    'lost-found' => 'lostFound',
    'moving-requests' => 'movingRequests',
    'guest-lists' => 'guestLists',
    'maintenance-orders' => 'maintenanceOrders',
    'unit-payments' => 'unitPayments',
    'emergency-alerts' => 'emergencyAlerts',
    'shift-logs' => 'shiftLogs',
    'renovation-requests' => 'renovationRequests',
    'key-registry' => 'keyRegistry',
    'utility-readings' => 'utilityReadings',
    'parking-spots' => 'parkingSpots',
    _ => resource,
  };

  Future<void> _openResource(String label, String resource) async {
    setState(() {
      _selectedResourceKey = resource;
      _selectedResourceTitle = label;
    });
  }

  ImageProvider? get _profileAvatarImage {
    return resolveSmartImageProvider(_profile['profileImage']?.toString());
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.width,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: SaaSCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: SaaSColors.muted(context)),
          ),
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final dynamic value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SaaSCard(
    onTap: onTap,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: SaaSColors.primary),
        const SizedBox(height: 12),
        Text(
          '$value',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: SaaSColors.muted(context)),
        ),
      ],
    ),
  );
}

Future<Map<String, dynamic>?> showCreateCondominiumDialog({
  required BuildContext context,
  required HomeService api,
}) async {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final managerEmailController = TextEditingController();
  final defaultPlans = <String>['Básico', 'Profissional', 'Premium'];
  var availablePlans = List<String>.from(defaultPlans);
  var selectedPlan = availablePlans.first;
  var isActive = true;
  var saving = false;
  String? errorMessage;

  try {
    final plansResponse = await api.get('/billing/plans');
    if (plansResponse is List) {
      final loaded = plansResponse
          .whereType<Map>()
          .map((e) => e['name']?.toString() ?? '')
          .where((name) => name.trim().isNotEmpty)
          .toList();
      for (final p in loaded) {
        if (!availablePlans.any(
          (existing) => existing.toLowerCase() == p.toLowerCase(),
        )) {
          availablePlans.add(p);
        }
      }
      if (availablePlans.isNotEmpty) {
        selectedPlan = availablePlans.first;
      }
    }
  } catch (_) {}

  if (!context.mounted) {
    nameController.dispose();
    addressController.dispose();
    managerEmailController.dispose();
    return null;
  }

  int? createdCondoId;
  Map<String, dynamic>? createdCondoMap;

  final created = await showAncoraDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFE8ECFF),
              child: Icon(Icons.domain_add_outlined, color: Color(0xFF2F3FB0)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Novo condomínio',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Preencha os dados abaixo para cadastrar um novo condomínio no sistema.',
                  style: TextStyle(color: Color(0xFF5C6179)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  enabled: !saving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome do condomínio *',
                    hintText: 'Ex.: Residencial Parque das Flores',
                    prefixIcon: Icon(Icons.apartment_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  enabled: !saving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Endereço completo *',
                    hintText: 'Ex.: Av. Atlântica, 1200 - Centro',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlan,
                  decoration: const InputDecoration(
                    labelText: 'Plano comercial',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: availablePlans
                      .map(
                        (plan) => DropdownMenuItem<String>(
                          value: plan,
                          child: Text(plan),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() => selectedPlan = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: managerEmailController,
                  enabled: !saving,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail do síndico inicial (opcional)',
                    hintText: 'Ex.: sindico@email.com',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Condomínio ativo'),
                  subtitle: const Text('Liberado para operação imediatamente'),
                  value: isActive,
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(() => isActive = value),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: saving
                ? null
                : () async {
                    final name = nameController.text.trim();
                    final address = addressController.text.trim();
                    final managerEmail = managerEmailController.text
                        .trim()
                        .toLowerCase();
                    if (name.isEmpty || address.isEmpty) {
                      setDialogState(() {
                        errorMessage =
                            'Informe o nome e o endereço do condomínio.';
                      });
                      return;
                    }
                    if (managerEmail.isNotEmpty &&
                        !managerEmail.contains('@')) {
                      setDialogState(() {
                        errorMessage =
                            'Informe um e-mail válido para o síndico ou deixe em branco.';
                      });
                      return;
                    }
                    setDialogState(() {
                      saving = true;
                      errorMessage = null;
                    });
                    try {
                      if (createdCondoId == null) {
                        final response = await api.send(
                          'POST',
                          '/condominiums',
                          body: {
                            'name': name,
                            'address': address,
                            'billingPlan': selectedPlan,
                            'isActive': isActive,
                          },
                        );
                        createdCondoMap = response is Map<String, dynamic>
                            ? response
                            : <String, dynamic>{
                                'name': name,
                                'address': address,
                                'billingPlan': selectedPlan,
                                'isActive': isActive,
                              };
                        createdCondoId =
                            (createdCondoMap?['id'] as num?)?.toInt();
                      }
                      if (createdCondoId != null && managerEmail.isNotEmpty) {
                        await api.send(
                          'POST',
                          '/admin/condominiums/$createdCondoId/managers',
                          body: {'email': managerEmail},
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, createdCondoMap);
                      }
                    } catch (e) {
                      setDialogState(() {
                        saving = false;
                        errorMessage = createdCondoId != null
                            ? 'Condomínio #$createdCondoId já criado, mas falhou ao vincular síndico (tente salvar novamente sem duplicar): $e'
                            : e.toString();
                      });
                    }
                  },
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(saving ? 'Criando…' : 'Criar condomínio'),
          ),
        ],
      ),
    ),
  );

  nameController.dispose();
  addressController.dispose();
  managerEmailController.dispose();
  return created;
}

class _AdminResourceView extends StatefulWidget {
  const _AdminResourceView({
    super.key,
    required this.api,
    required this.title,
    required this.resource,
    this.isEmbedded = false,
    this.onBack,
  });

  final HomeService api;
  final String title;
  final String resource;
  final bool isEmbedded;
  final VoidCallback? onBack;

  @override
  State<_AdminResourceView> createState() => _AdminResourceViewState();
}

class _AdminResourceViewState extends State<_AdminResourceView> {
  int _page = 0;
  int _size = 25;
  String _sort = 'id,desc';
  String _query = '';
  late Future<dynamic> _data;

  bool get _supportsCreate => adminResourceSupportsCreate(widget.resource);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AdminResourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource) {
      _page = 0;
      _sort = 'id,desc';
      _query = '';
      _load();
    }
  }

  void _load() {
    _data = widget.api.get(
      '/admin/data/${widget.resource}?page=$_page&size=$_size&sort=$_sort${_query.trim().isEmpty ? '' : '&query=${Uri.encodeQueryComponent(_query.trim())}'}',
    );
  }

  Future<void> _createRecord() async {
    if (!_supportsCreate) return;
    final created = await showCreateAdminResourceDialog(
      context: context,
      api: widget.api,
      resource: widget.resource,
      title: widget.title,
    );
    if (created != null && mounted) {
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registro em "${widget.title}" criado com sucesso!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Column(
      children: [
        if (!_supportsCreate)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Somente leitura: este recurso ainda não possui operações de gravação no backend.',
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: EnterSearchField(
                  hintText: 'Pesquisar registros em ${widget.title}',
                  onSubmitted: (query) => setState(() {
                    _query = query;
                    _page = 0;
                    _load();
                  }),
                ),
              ),
              DropdownButton<String>(
                value: _sort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'id,desc', child: Text('Mais recentes')),
                  DropdownMenuItem(value: 'id,asc', child: Text('Mais antigos')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _sort = v;
                    _page = 0;
                    _load();
                  });
                },
              ),
              DropdownButton<int>(
                value: _size,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25 / pág')),
                  DropdownMenuItem(value: 50, child: Text('50 / pág')),
                  DropdownMenuItem(value: 100, child: Text('100 / pág')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _size = v;
                    _page = 0;
                    _load();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<dynamic>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: SaaSLoadingState(message: 'Carregando registros...'),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SaaSErrorState(
                      message: snapshot.error.toString(),
                      onRetry: () => setState(_load),
                    ),
                  ),
                );
              }
              final result = snapshot.data;
              final rows = result is Map && result['content'] is List
                  ? (result['content'] as List)
                        .whereType<Map<String, dynamic>>()
                        .where((item) => recordMatchesQuery(item, _query))
                        .toList()
                  : <Map<String, dynamic>>[];
              final totalPages = result is Map
                  ? (result['totalPages'] as num?)?.toInt() ?? 1
                  : 1;

              return Column(
                children: [
                  if (rows.isEmpty)
                    const Expanded(
                      child: SaaSEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nenhum registro encontrado',
                        subtitle:
                            'Não há registros correspondentes aos critérios de pesquisa.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final item = rows[index];
                          return _AdminRecordCard(
                            resource: widget.resource,
                            item: item,
                            api: widget.api,
                            onChanged: () => setState(_load),
                          );
                        },
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Página anterior',
                            onPressed: _page > 0
                                ? () => setState(() {
                                    _page--;
                                    _load();
                                  })
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            'Página ${_page + 1} de $totalPages',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            tooltip: 'Próxima página',
                            onPressed: _page + 1 < totalPages
                                ? () => setState(() {
                                    _page++;
                                    _load();
                                  })
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SaaSCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      tooltip: 'Voltar à visão geral',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_supportsCreate)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: SaaSColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _createRecord,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Novo em ${widget.title}'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Atualizar',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(_load),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(child: bodyContent),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF2F3FB0),
        foregroundColor: Colors.white,
        actions: [
          if (_supportsCreate)
            IconButton(
              tooltip: 'Novo registro em ${widget.title}',
              onPressed: _createRecord,
              icon: const Icon(Icons.add_circle_outline),
            ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _supportsCreate
          ? FloatingActionButton.extended(
              onPressed: _createRecord,
              icon: const Icon(Icons.add),
              label: Text('Novo em ${widget.title}'),
            )
          : null,
      body: bodyContent,
    );
  }
}

class _AdminRecordCard extends StatelessWidget {
  const _AdminRecordCard({
    required this.resource,
    required this.item,
    required this.api,
    required this.onChanged,
  });

  final String resource;
  final Map<String, dynamic> item;
  final HomeService api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final title = _recordPrimaryTitle(resource, item);
    final subtitle = _recordSecondarySubtitle(resource, item);
    final badges = _recordBadges(resource, item);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: _buildLeadingAvatar(resource, item, title),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(color: Color(0xFF5C6179))),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: badges),
            ],
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FormattedRecordDetails(resource: resource, item: item),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showRecordDetailsDialog(
                        context: context,
                        resource: resource,
                        item: item,
                        api: api,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Ficha completa'),
                    ),
                    if (kAdminEditableResourceKeys.contains(resource))
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final updated = await showEditAdminResourceDialog(
                            context: context,
                            api: api,
                            resource: resource,
                            item: item,
                          );
                          if (updated != null && context.mounted) {
                            onChanged();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Registro atualizado com sucesso!',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar registro'),
                      ),
                    if (resource == 'condominiums' && item['id'] is num)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MembershipManagementPage(
                                api: api,
                                condominiumId: (item['id'] as num).toInt(),
                                isSystemAdmin: true,
                              ),
                            ),
                          );
                          onChanged();
                        },
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 18,
                        ),
                        label: const Text('Gerenciar síndicos'),
                      ),
                    if (kAdminDeletableResourceKeys.contains(resource) &&
                        item['id'] is num)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                        onPressed: () => _confirmControlledDelete(
                          context,
                          resource: resource,
                          id: (item['id'] as num).toInt(),
                          identifierLabel: title,
                          api: api,
                          onDeleted: onChanged,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Excluir registro'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmControlledDelete(
    BuildContext context, {
    required String resource,
    required int id,
    required String identifierLabel,
    required HomeService api,
    required VoidCallback onDeleted,
  }) async {
    final confirmCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final expectedToken = identifierLabel.trim().isNotEmpty
        ? identifierLabel.trim()
        : '#$id';
    String? inlineError;
    bool deleting = false;

    try {
      final deleted = await showAncoraDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: const Text('Exclusão Controlada e Auditada'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Esta operação remove o registro #$id em "$resource" e registra auditoria irreversível.\n\nDigite "$expectedToken" (ou "$id") para confirmar:',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      decoration: InputDecoration(
                        labelText: 'Confirmação *',
                        hintText: expectedToken,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motivo da exclusão (Auditoria) *',
                        hintText: 'Descreva a justificativa administrativa...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        inlineError!,
                        style: const TextStyle(
                          color: SaaSColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: deleting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SaaSColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: deleting
                    ? null
                    : () async {
                        final typed = confirmCtrl.text.trim();
                        final reason = reasonCtrl.text.trim();
                        if (typed != expectedToken && typed != '$id') {
                          setDlg(
                            () => inlineError =
                                'Confirmação inválida. Digite "$expectedToken" ou "$id".',
                          );
                          return;
                        }
                        if (reason.length < 3) {
                          setDlg(
                            () => inlineError =
                                'Informe o motivo para o log de auditoria.',
                          );
                          return;
                        }
                        setDlg(() {
                          deleting = true;
                          inlineError = null;
                        });
                        try {
                          await api.send(
                            'DELETE',
                            '/admin/data/$resource/$id?reason=${Uri.encodeQueryComponent(reason)}',
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setDlg(() {
                            deleting = false;
                            inlineError = 'Falha ao excluir: $e';
                          });
                        }
                      },
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(deleting ? 'Excluindo...' : 'Confirmar Exclusão'),
              ),
            ],
          ),
        ),
      );
      if (deleted == true && context.mounted) {
        onDeleted();
        SaaSFeedback.showSuccess(
          context,
          'Registro #$id excluído com registro em auditoria.',
        );
      }
    } finally {
      confirmCtrl.dispose();
      reasonCtrl.dispose();
    }
  }

  Widget _buildLeadingAvatar(
    String resource,
    Map<String, dynamic> item,
    String title,
  ) {
    if (resource == 'users') {
      final initials = title.trim().isNotEmpty
          ? title
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((part) => part.isNotEmpty ? part[0].toUpperCase() : '')
                .join()
          : 'U';
      return CircleAvatar(
        backgroundColor: const Color(0xFFE0E7FF),
        foregroundColor: const Color(0xFF2F3FB0),
        child: Text(
          initials,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }
    final icon = switch (resource) {
      'condominiums' => Icons.apartment_outlined,
      'memberships' => Icons.admin_panel_settings_outlined,
      'sectors' => Icons.domain_outlined,
      'units' => Icons.home_work_outlined,
      'residents' => Icons.groups_outlined,
      'packages' => Icons.inventory_2_outlined,
      'announcements' => Icons.campaign_outlined,
      'reservations' => Icons.event_available_outlined,
      'common-areas' => Icons.deck_outlined,
      'notifications' => Icons.notifications_outlined,
      'billing-plans' => Icons.receipt_long_outlined,
      'condominium-subscriptions' => Icons.subscriptions_outlined,
      'subscription-history' => Icons.history_rounded,
      'tickets' => Icons.report_problem_outlined,
      'expenses' => Icons.attach_money_outlined,
      'infractions' => Icons.gavel_outlined,
      'features' => Icons.extension_outlined,
      _ => Icons.article_outlined,
    };
    return CircleAvatar(
      backgroundColor: const Color(0xFFE8ECFF),
      foregroundColor: const Color(0xFF2F3FB0),
      child: Icon(icon, size: 20),
    );
  }
}

Future<void> showRecordDetailsDialog({
  required BuildContext context,
  required String resource,
  required Map<String, dynamic> item,
  HomeService? api,
}) async {
  final title = _recordPrimaryTitle(resource, item);
  final subtitle = _recordSecondarySubtitle(resource, item);
  final badges = _recordBadges(resource, item);

  await showAncoraDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE0E7FF),
            foregroundColor: const Color(0xFF2F3FB0),
            child: Icon(
              resource == 'users'
                  ? Icons.person_outline
                  : resource == 'condominiums'
                  ? Icons.apartment_outlined
                  : Icons.info_outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5C6179),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (badges.isNotEmpty) ...[
                Wrap(spacing: 6, runSpacing: 6, children: badges),
                const SizedBox(height: 16),
              ],
              _FormattedRecordDetails(resource: resource, item: item),
            ],
          ),
        ),
      ),
      actions: [
        if (resource == 'condominiums' && item['id'] is num && api != null)
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MembershipManagementPage(
                    api: api,
                    condominiumId: (item['id'] as num).toInt(),
                    isSystemAdmin: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Gerenciar síndicos'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}

class _FormattedRecordDetails extends StatelessWidget {
  const _FormattedRecordDetails({required this.resource, required this.item});

  final String resource;
  final Map<String, dynamic> item;

  static const _hiddenKeys = <String>{
    'profileImage',
    'imageUrl',
    'id',
    'condominiumId',
    'userId',
    'unitId',
    'sectorId',
    'billingPlanId',
    'recipientId',
    'createdById',
    'commonAreaId',
    'reservedById',
    'invitationId',
    'origin',
  };

  @override
  Widget build(BuildContext context) {
    final entries = item.entries
        .where((e) => !_hiddenKeys.contains(e.key) && e.value != null)
        .toList();
    final attachedImage = (item['imageUrl'] ?? item['profileImage'])
        ?.toString()
        .trim();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaaSColors.surfaceSubtle(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaaSColors.border(isDark)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 16, color: SaaSColors.border(isDark)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _fieldIcon(entries[i].key),
                  size: 18,
                  color: SaaSColors.textSecondary(isDark),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 135,
                  child: Text(
                    _fieldLabel(entries[i].key),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: SaaSColors.textSecondary(isDark),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFormattedValue(entries[i].key, entries[i].value),
                ),
              ],
            ),
          ],
          if (attachedImage != null && attachedImage.isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            ClickableImagePreview(
              imageSource: attachedImage,
              title: _recordPrimaryTitle(resource, item),
              height: 180,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedValue(String key, dynamic value) {
    if (key == 'roles' && value is List) {
      final roles = value
          .map(_extractAuthority)
          .where((e) => e.isNotEmpty)
          .toList();
      if (roles.isEmpty) {
        return const Text('Morador (padrão)');
      }
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: roles.map(_roleChip).toList(),
      );
    }
    if (key == 'features' && value is List) {
      final features = value
          .map(
            (f) => f is Map
                ? (f['name'] ?? f['code'] ?? f.toString())
                : f.toString(),
          )
          .toList();
      if (features.isEmpty) {
        return const Text('Nenhum recurso vinculado');
      }
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: features
            .map(
              (f) => Chip(
                visualDensity: VisualDensity.compact,
                label: Text(f.toString(), style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList(),
      );
    }
    final formatted = _formatScalarValue(key, value);
    return SelectableText(
      formatted.isEmpty ? 'Não informado' : formatted,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w500,
        fontSize: 13.5,
      ),
    );
  }
}

String _recordPrimaryTitle(String resource, Map<String, dynamic> item) {
  if (resource == 'users') {
    final fullName = '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'
        .trim();
    if (fullName.isNotEmpty) return fullName;
    if (item['email'] != null) return item['email'].toString();
  }
  if (resource == 'memberships') {
    final userName = item['userName']?.toString().trim() ?? '';
    final condoName = item['condominiumName']?.toString().trim() ?? '';
    if (userName.isNotEmpty && condoName.isNotEmpty) {
      return '$userName • $condoName';
    }
    if (userName.isNotEmpty) return userName;
  }
  for (final key in [
    'name',
    'title',
    'description',
    'userName',
    'recipientName',
    'reservedByName',
    'commonAreaName',
    'email',
    'identifier',
    'unitName',
    'unitIdentifier',
    'sectorName',
    'condominiumName',
    'code',
  ]) {
    final value = item[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return 'Registro cadastrado';
}

String _recordSecondarySubtitle(String resource, Map<String, dynamic> item) {
  if (resource == 'users') {
    final email = item['email']?.toString() ?? '';
    return email.isNotEmpty ? email : 'Conta cadastrada';
  }
  if (resource == 'condominiums') {
    final address = item['address']?.toString() ?? '';
    return address.isNotEmpty ? address : 'Condomínio cadastrado';
  }
  if (resource == 'memberships') {
    final email =
        item['userEmail']?.toString() ?? item['email']?.toString() ?? '';
    return email.isNotEmpty ? email : 'Vínculo ativo';
  }
  final parts = <String>[
    for (final key in [
      'condominiumName',
      'sectorName',
      'unitName',
      'unitIdentifier',
      'recipientName',
      'userName',
      'reservedByName',
      'userEmail',
      'email',
    ])
      if (item[key] != null && item[key].toString().trim().isNotEmpty)
        key == 'unitIdentifier'
            ? 'Unidade ${item[key]}'
            : item[key].toString().trim(),
  ];
  return parts.isNotEmpty ? parts.take(3).join(' • ') : 'Detalhes do cadastro';
}

List<Widget> _recordBadges(String resource, Map<String, dynamic> item) {
  final badges = <Widget>[];
  if (resource == 'users' && item['roles'] is List) {
    for (final raw in item['roles'] as List) {
      final auth = _extractAuthority(raw);
      if (auth.isNotEmpty) {
        badges.add(_roleChip(auth));
      }
    }
  }
  if (resource == 'condominiums') {
    final planName = item['billingPlanName'] ?? item['billingPlan'];
    if (planName != null) {
      badges.add(
        _pillBadge(
          'Plano: $planName',
          const Color(0xFFE0E7FF),
          const Color(0xFF2F3FB0),
        ),
      );
    }
    final active = item['isActive'] == true || item['active'] == true;
    badges.add(
      _pillBadge(
        active ? 'Ativo' : 'Inativo',
        active ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        active ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
      ),
    );
  }
  if (item['authority'] != null) {
    badges.add(_roleChip(item['authority'].toString()));
  }
  if (item['status'] != null) {
    badges.add(
      _pillBadge(
        _translateEnum(item['status'].toString()),
        const Color(0xFFF1F5F9),
        const Color(0xFF334155),
      ),
    );
  }
  return badges;
}

String _extractAuthority(dynamic raw) {
  if (raw is String) return raw;
  if (raw is Map && raw['authority'] != null) {
    return raw['authority'].toString();
  }
  return '';
}

Widget _roleChip(String authority) {
  final (label, bg, fg) = switch (authority) {
    'ROLE_ADMIN' => (
      'Administrador',
      const Color(0xFFEDE9FE),
      const Color(0xFF6D28D9),
    ),
    'ROLE_MANAGER' => (
      'Síndico',
      const Color(0xFFDBEAFE),
      const Color(0xFF1D4ED8),
    ),
    'ROLE_DOORMAN' => (
      'Porteiro',
      const Color(0xFFCCFBF1),
      const Color(0xFF0F766E),
    ),
    'ROLE_RESIDENT' => (
      'Morador',
      const Color(0xFFE2E8F0),
      const Color(0xFF334155),
    ),
    _ => (
      _translateEnum(authority),
      const Color(0xFFE2E8F0),
      const Color(0xFF334155),
    ),
  };
  return _pillBadge(label, bg, fg);
}

Widget _pillBadge(String text, Color background, Color foreground) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(999),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: foreground,
    ),
  ),
);

String _fieldLabel(String key) => switch (key) {
  'firstName' => 'Nome',
  'lastName' => 'Sobrenome',
  'name' => 'Nome',
  'userName' => 'Usuário',
  'recipientName' => 'Destinatário',
  'createdByName' => 'Publicado por',
  'reservedByName' || 'residentName' => 'Morador',
  'email' ||
  'userEmail' ||
  'residentEmail' ||
  'createdByEmail' ||
  'reservedByEmail' => 'E-mail',
  'contactPhone' => 'Telefone de contato',
  'roles' => 'Perfis de acesso',
  'authority' || 'invitationAuthority' => 'Papel / Permissão',
  'address' => 'Endereço',
  'billingPlan' || 'billingPlanName' => 'Plano comercial',
  'isActive' || 'active' => 'Situação',
  'status' || 'invitationStatus' => 'Status',
  'condominiumName' => 'Condomínio',
  'sector' || 'sectorName' => 'Setor',
  'identifier' || 'unitIdentifier' || 'unitName' => 'Unidade',
  'structuralType' => 'Tipo de estrutura',
  'description' => 'Descrição',
  'title' => 'Título',
  'content' || 'message' => 'Mensagem / Conteúdo',
  'type' => 'Tipo',
  'read' => 'Leitura',
  'monthlyFee' => 'Mensalidade',
  'code' => 'Código',
  'features' => 'Recursos incluídos',
  'createdAt' => 'Criado em',
  'expiresAt' => 'Expira em',
  'respondedAt' => 'Respondido em',
  'receivedAt' => 'Recebido em',
  'notifiedAt' => 'Notificado em',
  'pickedUpAt' => 'Retirado em',
  'cancelledAt' => 'Cancelado em',
  'returnedAt' => 'Devolvido em',
  'startAt' => 'Início',
  'endAt' => 'Término',
  'commonAreaName' || 'commonArea' => 'Área comum',
  'capacity' => 'Capacidade',
  'requiresApproval' => 'Exige aprovação',
  _ => key,
};

IconData _fieldIcon(String key) => switch (key) {
  'firstName' ||
  'lastName' ||
  'name' ||
  'userName' ||
  'recipientName' ||
  'createdByName' ||
  'reservedByName' ||
  'residentName' => Icons.person_outline,
  'email' ||
  'userEmail' ||
  'residentEmail' ||
  'createdByEmail' ||
  'reservedByEmail' => Icons.email_outlined,
  'contactPhone' => Icons.phone_outlined,
  'roles' ||
  'authority' ||
  'invitationAuthority' => Icons.verified_user_outlined,
  'address' => Icons.location_on_outlined,
  'billingPlan' ||
  'billingPlanName' ||
  'monthlyFee' => Icons.receipt_long_outlined,
  'isActive' ||
  'active' ||
  'status' ||
  'invitationStatus' => Icons.check_circle_outline,
  'condominiumName' => Icons.apartment_outlined,
  'createdAt' ||
  'expiresAt' ||
  'respondedAt' ||
  'receivedAt' ||
  'notifiedAt' ||
  'pickedUpAt' ||
  'cancelledAt' ||
  'returnedAt' ||
  'startAt' ||
  'endAt' => Icons.schedule_outlined,
  _ => Icons.label_outline,
};

String _formatScalarValue(String key, dynamic value) {
  if (value == null) return '';
  if (value is bool) {
    if (key == 'isActive' || key == 'active') {
      return value ? 'Ativo' : 'Inativo';
    }
    if (key == 'read') {
      return value ? 'Lida' : 'Não lida';
    }
    return value ? 'Sim' : 'Não';
  }
  if (key == 'monthlyFee' && value is num) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
  final str = value.toString().trim();
  if (str.isEmpty) return '';
  if (key == 'contactPhone') {
    return formatPhone(str);
  }
  if (key.endsWith('At') || key.endsWith('Date')) {
    try {
      final dt = DateTime.parse(str).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {}
  }
  return _translateEnum(str);
}

String _translateEnum(String value) => switch (value) {
  'ROLE_ADMIN' => 'Administrador',
  'ROLE_MANAGER' => 'Síndico',
  'ROLE_DOORMAN' => 'Porteiro',
  'ROLE_RESIDENT' => 'Morador',
  'ACTIVE' => 'Ativo',
  'PENDING' => 'Pendente',
  'DECLINED' => 'Recusado',
  'CONFIRMED' => 'Confirmada',
  'CANCELLED' => 'Cancelada',
  'EXPECTED' => 'Aguardando recebimento',
  'RECEIVED' => 'Recebida na portaria',
  'NOTIFIED' => 'Morador notificado',
  'PICKED_UP' || 'DELIVERED' => 'Entregue ao morador',
  'RETURNED' => 'Devolvida',
  'BLOCK' => 'Bloco',
  'STREET' => 'Rua',
  'COURT' => 'Quadra',
  'GRILL' => 'Área gourmet',
  'MEMBERSHIP_INVITATION' => 'Convite de condomínio',
  'SYSTEM_ANNOUNCEMENT' => 'Comunicado do sistema',
  'ANNOUNCEMENT' => 'Comunicado',
  'PACKAGE_RECEIVED' => 'Encomenda recebida',
  'PACKAGE_STATUS_CHANGED' => 'Atualização de encomenda',
  'RESERVATION' => 'Reserva',
  'OWNER' => 'Proprietário',
  'TENANT' => 'Inquilino',
  'DEPENDENT' => 'Dependente',
  _ => value,
};

class _AdminSearch extends StatefulWidget {
  const _AdminSearch({
    required this.api,
    this.condominiums = const [],
    this.resources = const [],
    this.onOpenResource,
    this.onChanged,
  });

  final HomeService api;
  final List<Map<String, dynamic>> condominiums;
  final List<(String, String, IconData)> resources;
  final void Function(String label, String resource)? onOpenResource;
  final VoidCallback? onChanged;

  @override
  State<_AdminSearch> createState() => _AdminSearchState();
}

class _AdminSearchState extends State<_AdminSearch> {
  final _controller = TextEditingController();
  int _requestNumber = 0;
  bool _loading = false;
  String _query = '';
  String _selectedType = 'all';
  int? _selectedCondoId;
  Map<String, dynamic>? _results;
  List<Map<String, dynamic>> _entityResults = const [];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmitted(String value) {
    final requestNumber = ++_requestNumber;
    final query = value.trim();
    setState(() {
      _query = query;
      _loading = false;
      _results = null;
      _entityResults = const [];
      _error = null;
    });
    if (query.isEmpty && _selectedType == 'all' && _selectedCondoId == null) {
      return;
    }
    _search(query, requestNumber);
  }

  Future<void> _search(String query, int requestNumber) async {
    if (!mounted || requestNumber != _requestNumber) return;
    setState(() => _loading = true);
    try {
      if (_selectedType == 'all') {
        final effectiveQuery = query.isNotEmpty
            ? query
            : (widget.condominiums
                      .where((c) => c['id'] == _selectedCondoId)
                      .map((c) => c['name']?.toString() ?? '')
                      .firstOrNull ??
                  '');
        if (effectiveQuery.isEmpty) {
          setState(() {
            _results = <String, dynamic>{};
            _loading = false;
          });
          return;
        }
        final value = await widget.api.get(
          '/admin/search?query=${Uri.encodeQueryComponent(effectiveQuery)}',
        );
        if (!mounted || requestNumber != _requestNumber) return;
        setState(() {
          _results =
              value is Map<String, dynamic> ? value : <String, dynamic>{};
          _loading = false;
        });
      } else if (_selectedType == 'audit-logs') {
        final value = await widget.api.get(
          '/admin/audit-logs?page=0&size=15${query.isNotEmpty ? '&query=${Uri.encodeQueryComponent(query)}' : ''}',
        );
        if (!mounted || requestNumber != _requestNumber) return;
        final list = value is Map && value['content'] is List
            ? (value['content'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const <Map<String, dynamic>>[];
        setState(() {
          _entityResults = list;
          _loading = false;
        });
      } else {
        final queryPart = query.isNotEmpty
            ? '&query=${Uri.encodeQueryComponent(query)}'
            : '';
        final value = await widget.api.get(
          '/admin/data/$_selectedType?page=0&size=20$queryPart',
        );
        if (!mounted || requestNumber != _requestNumber) return;
        var list = value is Map && value['content'] is List
            ? (value['content'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const <Map<String, dynamic>>[];
        if (_selectedCondoId != null) {
          final condoObj = widget.condominiums
              .where((c) => c['id'] == _selectedCondoId)
              .firstOrNull;
          final condoName =
              condoObj?['name']?.toString().toLowerCase() ?? '';
          list = list.where((item) {
            final itemCondoId = item['condominiumId'];
            if (itemCondoId is num && itemCondoId.toInt() == _selectedCondoId) {
              return true;
            }
            if (condoName.isNotEmpty &&
                item.toString().toLowerCase().contains(condoName)) {
              return true;
            }
            return false;
          }).toList();
        }
        setState(() {
          _entityResults = list;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openSearchResultDetails(
    String key,
    Map<String, dynamic> summaryItem,
  ) async {
    final id = summaryItem['id'];
    var fullItem = summaryItem;
    if (id != null && key != 'audit-logs') {
      try {
        final pageData = await widget.api.get(
          '/admin/data/$key?page=0&size=25&query=${Uri.encodeQueryComponent(id.toString())}',
        );
        if (pageData is Map && pageData['content'] is List) {
          for (final e
              in (pageData['content'] as List)
                  .whereType<Map<String, dynamic>>()) {
            if (e['id'] == id) {
              fullItem = e;
              break;
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await showRecordDetailsDialog(
      context: context,
      resource: key == 'audit-logs' ? 'users' : key,
      item: fullItem,
      api: widget.api,
    );
  }

  List<Map<String, dynamic>> _items(String key) {
    final values = _results?[key];
    return values is List
        ? values.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
  }

  int get _resultCount =>
      _items('users').length +
      _items('condominiums').length +
      _items('sectors').length;

  @override
  Widget build(BuildContext context) {
    final filterTypes = <(String, String)>[
      ('all', 'Busca Global (Usuários, Condos, Setores)'),
      ('audit-logs', 'Trilha de Auditoria'),
      ...widget.resources.take(12).map((r) => (r.$2, r.$1)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.condominiums.isNotEmpty || widget.resources.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de registro',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: filterTypes
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.$1,
                          child: Text(
                            e.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedType = value);
                    if (_controller.text.trim().isNotEmpty ||
                        value != 'all') {
                      _onSubmitted(_controller.text);
                    }
                  },
                ),
              ),
              if (widget.condominiums.isNotEmpty)
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedCondoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Condomínio',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Todos os condomínios',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...widget.condominiums.map(
                        (c) => DropdownMenuItem<int?>(
                          value: (c['id'] as num?)?.toInt(),
                          child: Text(
                            c['name']?.toString() ?? 'Condomínio #${c['id']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCondoId = value);
                      if (_controller.text.trim().isNotEmpty ||
                          _selectedType != 'all' ||
                          value != null) {
                        _onSubmitted(_controller.text);
                      }
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _controller,
          maxLength: 100,
          onSubmitted: _onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Nome, e-mail, setor, código ou evento',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpar pesquisa',
                    onPressed: () {
                      _controller.clear();
                      _onSubmitted('');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
                IconButton(
                  tooltip: 'Pesquisar',
                  onPressed: () => _onSubmitted(_controller.text),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ],
            ),
            isDense: true,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_selectedType != 'all' && !_loading && _results == null) ...[
          const SizedBox(height: 10),
          if (_entityResults.isEmpty)
            Text(
              'Nenhum registro encontrado com os filtros aplicados.',
              style: TextStyle(fontSize: 12, color: SaaSColors.muted(context)),
            )
          else
            ..._entityResults.take(8).map(
              (item) {
                final title =
                    item['name']?.toString() ??
                    item['title']?.toString() ??
                    item['action']?.toString() ??
                    item['email']?.toString() ??
                    'Registro #${item['id'] ?? '-'}';
                final subtitle =
                    item['details']?.toString() ??
                    item['email']?.toString() ??
                    item['entityType']?.toString() ??
                    item['status']?.toString() ??
                    '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: SaaSColors.primary.withValues(alpha: 0.14),
                    child: const Icon(
                      Icons.dataset_outlined,
                      color: SaaSColors.primary,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: subtitle.isEmpty
                      ? null
                      : Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                  onTap: () => _openSearchResultDetails(_selectedType, item),
                );
              },
            ),
        ],
        if (_results != null &&
            (_query.isNotEmpty || _selectedCondoId != null) &&
            !_loading) ...[
          const SizedBox(height: 12),
          if (_resultCount == 0)
            const Text('Nenhum usuário, condomínio ou setor encontrado.')
          else ...[
            _resultGroup('Usuários', 'users', Icons.people_outline),
            _resultGroup(
              'Condomínios',
              'condominiums',
              Icons.apartment_outlined,
            ),
            _resultGroup('Setores', 'sectors', Icons.domain_outlined),
          ],
        ],
      ],
    );
  }

  Widget _resultGroup(String title, String key, IconData icon) {
    final values = _items(key);
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ...values.map(
          (item) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () => _openSearchResultDetails(key, item),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: SaaSColors.primary.withValues(alpha: 0.14),
              child: Icon(icon, color: SaaSColors.primary, size: 18),
            ),
            title: Text(
              item['name']?.toString() ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: item['details'] == null
                ? null
                : Text(item['details'].toString()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (key == 'condominiums' && item['id'] is num)
                  IconButton(
                    tooltip: 'Gerenciar síndicos',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MembershipManagementPage(
                            api: widget.api,
                            condominiumId: (item['id'] as num).toInt(),
                            isSystemAdmin: true,
                          ),
                        ),
                      );
                      widget.onChanged?.call();
                    },
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                IconButton(
                  tooltip: 'Ver detalhes',
                  onPressed: () => _openSearchResultDetails(key, item),
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
