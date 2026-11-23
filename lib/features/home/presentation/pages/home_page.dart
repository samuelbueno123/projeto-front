import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/design_system/motion_system.dart';
import '../../../../core/services/realtime_service.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/command_palette.dart';
import '../../../../core/widgets/condo_assistant_sheet.dart';
import '../../../../core/widgets/custom_menus.dart';
import '../../../../core/widgets/emergency_sos_banner.dart';
import '../../../../core/widgets/enter_search_field.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import '../../../../core/widgets/role_switcher_pill.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/subscription_status_banner.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/pages/user_profile_page.dart';
import '../../../community/data/community_api.dart';
import '../../../community/presentation/dialogs/boleto_payment_dialog.dart';
import '../../../community/presentation/dialogs/common_area_booking_dialog.dart';
import '../../../community/presentation/dialogs/discord_welcome_dialog.dart';
import '../../../community/presentation/dialogs/emergency_sos_dialog.dart';
import '../../../community/presentation/dialogs/join_condominium_dialog.dart';
import '../../../community/presentation/dialogs/visitor_digital_pass_dialog.dart';
import '../../../community/presentation/views/community_hub_view.dart';
import '../../../community/presentation/views/condominium_gallery_view.dart';
import '../../../community/presentation/views/doorman_chat_view.dart';
import '../../data/home_service.dart';
import 'notifications_page.dart';

part 'home_resident_sections_part.dart';
part 'home_resident_dialogs_part.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onLogout,
    this.token,
    this.userName,
    this.userEmail,
    this.authProvider = 'password',
    required this.reauthenticateWithGoogle,
    required this.refreshWithCredentials,
    required this.refreshGoogleSession,
    this.currentRole,
    this.availableRoles = const [],
    this.onSwitchRole,
    this.api,
  });

  final Future<void> Function() onLogout;
  final String? token;
  final String? userName;
  final String? userEmail;
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeService _api;
  late CommunityApi _communityApi;
  StreamSubscription<RealtimeEvent>? _realtimeSub;
  int _tab =
      0; // 0: Início, 1: Acesso/Encomendas, 2: Reservas, 3: Mensagens/Chat, 4: Perfil, 5: Galeria, 6: Hub
  final int _communityCategoryIndex = 0;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _memberships = [];
  int? _selectedCondominiumId;
  int? _selectedMembershipId;
  Map<String, dynamic>? _condominium;
  Map<String, dynamic>? _subscription;
  SubscriptionAccessState get _subAccess => SubscriptionAccessState.fromMaps(
    condominium: _condominium,
    subscription: _subscription,
  );
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _polls = [];
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _profile = {};

  String _packageQuery = '';
  String _reservationQuery = '';
  String _reservationFilter = 'SCHEDULED'; // SCHEDULED, PAST, CANCELLED
  String _announcementQuery = '';

  Map<String, dynamic>? get _activeMembership {
    if (_memberships.isEmpty) return null;
    if (_selectedMembershipId != null) {
      for (final m in _memberships) {
        if ((m['id'] as num?)?.toInt() == _selectedMembershipId) {
          return m;
        }
      }
    }
    if (_selectedCondominiumId != null) {
      for (final m in _memberships) {
        if ((m['condominiumId'] as num?)?.toInt() == _selectedCondominiumId) {
          return m;
        }
      }
    }
    return _memberships.first;
  }

  String get _unitDisplay {
    final mem = _activeMembership;
    if (mem != null) {
      final unitName = mem['unitIdentifier'] ?? mem['unitName'];
      if (unitName != null && unitName.toString().trim().isNotEmpty) {
        return 'Apartamento $unitName';
      }
      final label = mem['unitLabel']?.toString();
      if (label != null && label.trim().isNotEmpty) {
        final match = RegExp(r'Unid\.?\s*([^\s•]+)').firstMatch(label);
        if (match != null) {
          return 'Apartamento ${match.group(1)}';
        }
        return label;
      }
    }
    final profileUnit = _profile['unitIdentifier'] ?? _profile['unitName'];
    if (profileUnit != null && profileUnit.toString().trim().isNotEmpty) {
      return 'Apartamento $profileUnit';
    }
    return 'Sem unidade vinculada';
  }

  String get _sectorDisplay {
    final mem = _activeMembership;
    if (mem != null) {
      final sec = mem['sectorName'] ?? mem['sector'];
      if (sec != null && sec.toString().trim().isNotEmpty) {
        return 'Bloco $sec';
      }
      final label = mem['unitLabel']?.toString();
      if (label != null && label.contains('•')) {
        return label.split('•').first.trim();
      }
    }
    final profileSec = _profile['sectorName'] ?? _profile['sector'];
    if (profileSec != null && profileSec.toString().trim().isNotEmpty) {
      return 'Bloco $profileSec';
    }
    return 'Bloco não definido';
  }

  bool get _canManage {
    if (widget.currentRole != null &&
        widget.currentRole!.toUpperCase().contains('RESIDENT')) {
      return false;
    }
    final token = widget.token;
    if (token == null) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      final roles = payload is Map ? payload['authorities'] : null;
      return roles is List &&
          roles.any((role) => role == 'ROLE_ADMIN' || role == 'ROLE_MANAGER');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? HomeService(token: widget.token);
    _communityApi = CommunityApi(api: _api);
    _initRealtime();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.api != widget.api) {
      if (oldWidget.api == null && widget.api == null) {
        _api.dispose();
      }
      _api = widget.api ?? HomeService(token: widget.token);
      _communityApi = CommunityApi(api: _api);
      _initRealtime();
      _load();
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    if (widget.api == null) {
      _api.dispose();
    }
    super.dispose();
  }

  void _initRealtime() {
    _realtimeSub?.cancel();
    if (widget.token != null && widget.token!.isNotEmpty) {
      RealtimeService.instance.setToken(widget.token);
      _realtimeSub = RealtimeService.instance.events.listen((event) {
        _handleRealtimeUpdate(event);
      });
    }
  }

  void _handleRealtimeUpdate(RealtimeEvent event) {
    if (!mounted) return;
    if (event.condominiumId != null &&
        _selectedCondominiumId != null &&
        event.condominiumId != _selectedCondominiumId) {
      return;
    }
    switch (event.type) {
      case RealtimeEventTypes.notification:
      case RealtimeEventTypes.systemAnnouncement:
        _refreshNotifications();
        break;
      case RealtimeEventTypes.packageUpdated:
        _refreshPackages();
        _refreshNotifications();
        break;
      case RealtimeEventTypes.announcement:
      case RealtimeEventTypes.announcementCreated:
        _refreshAnnouncements();
        _refreshNotifications();
        break;
      case RealtimeEventTypes.reservationUpdated:
        _refreshReservations();
        _refreshNotifications();
        break;
      case RealtimeEventTypes.invoiceUpdated:
        _refreshInvoices();
        break;
      case RealtimeEventTypes.subscriptionUpdated:
        _load();
        break;
      case RealtimeEventTypes.chatMessage:
        _refreshNotifications();
        break;
    }
  }

  void _mutate(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _refreshNotifications() async {
    try {
      final condoId = _condominium?['id'] ?? _selectedCondominiumId;
      final path = condoId != null
          ? '/notifications/my?condominiumId=$condoId'
          : '/notifications/my';
      final res = await _safeGet(path);
      if (!mounted) return;
      final raw = _list(res);
      final filtered = condoId == null
          ? raw
          : raw.where((n) {
              final origin = n['origin']?.toString().toUpperCase();
              final nid = n['condominiumId'];
              if (nid == null) {
                return origin != 'CONDOMINIUM' && n['type'] != 'ANNOUNCEMENT';
              }
              return nid.toString() == condoId.toString();
            }).toList();
      setState(() => _notifications = filtered);
    } catch (_) {}
  }

  Future<void> _refreshPackages() async {
    try {
      final condoId = _condominium?['id'] ?? _selectedCondominiumId;
      final path = condoId != null
          ? '/packages/my?condominiumId=$condoId&page=0&size=20'
          : '/packages/my?page=0&size=20';
      final res = await _safeGet(path);
      if (!mounted) return;
      setState(() => _packages = _list(res));
    } catch (_) {}
  }

  Future<void> _refreshAnnouncements() async {
    if (_condominium == null) return;
    try {
      final id = _condominium!['id'];
      final res = await _safeGet('/condominiums/$id/announcements');
      if (!mounted) return;
      setState(() => _announcements = _list(res));
    } catch (_) {}
  }

  Future<void> _refreshReservations() async {
    if (_condominium == null) return;
    try {
      final id = _condominium!['id'];
      final res = await _safeGet('/condominiums/$id/reservations/my');
      if (!mounted) return;
      setState(() => _reservations = _list(res));
    } catch (_) {}
  }

  Future<void> _refreshInvoices() async {
    if (_condominium == null) return;
    try {
      final id = _condominium!['id'];
      final res = await _safeGet('/condominiums/$id/my-invoices');
      if (!mounted) return;
      setState(() => _invoices = _list(res));
    } catch (_) {}
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    if (value is Map && value['content'] is List) {
      return (value['content'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final initial = await Future.wait([
        _safeGet('/users/me'),
        _api.get('/memberships/my'),
      ]);
      final profile = _map(initial[0]);
      final memberships = _list(initial[1]);
      var notifications = <Map<String, dynamic>>[];

      // Apply saved theme preference
      final themePref = profile['themePreference']?.toString();
      if (themePref != null && themePref.isNotEmpty) {
        AppTheme.setThemePreference(themePref);
      }

      Map<String, dynamic>? condominium;
      Map<String, dynamic>? subscription;
      List<Map<String, dynamic>> announcements = [];
      List<Map<String, dynamic>> packages = [];
      List<Map<String, dynamic>> reservations = [];
      List<Map<String, dynamic>> invoices = [];
      List<Map<String, dynamic>> polls = [];
      List<Map<String, dynamic>> visitors = [];
      List<Map<String, dynamic>> tickets = [];
      int? selectedCondoId = _selectedCondominiumId;

      if (memberships.isNotEmpty) {
        final matchingMem = selectedCondoId != null
            ? memberships.firstWhere(
                (m) => (m['condominiumId'] as num?)?.toInt() == selectedCondoId,
                orElse: () => memberships.first,
              )
            : memberships.first;
        final id = (matchingMem['condominiumId'] as num).toInt();
        selectedCondoId = id;
        condominium = _map(await _api.get('/condominiums/$id'));

        final results = await Future.wait([
          _safeGet('/condominiums/$id/announcements'),
          _safeGet('/packages/my?condominiumId=$id&page=0&size=20'),
          _safeGet('/condominiums/$id/reservations/my'),
          _safeGet('/condominiums/$id/my-invoices'),
          _safeGet('/condominiums/$id/polls'),
          _safeGet('/condominiums/$id/visitors?mine=true'),
          _safeGet('/condominiums/$id/tickets?mine=true'),
          _safeGet('/notifications/my?condominiumId=$id'),
          _safeGet('/condominiums/$id/subscription'),
        ]);

        announcements = _list(results[0]);
        packages = _list(results[1]);
        reservations = _list(results[2]);
        invoices = _list(results[3]);
        polls = _list(results[4]);
        visitors = _list(results[5]);
        tickets = _list(results[6]);
        notifications = _list(results[7]).where((n) {
          final cid = (n['condominiumId'] as num?)?.toInt();
          if (cid != null) return cid == id;
          return n['type'] != 'ANNOUNCEMENT';
        }).toList();
        if (results[8] is Map<String, dynamic>) {
          subscription = Map<String, dynamic>.from(results[8] as Map);
        }

        // Discord welcome dialog on first access
        if (matchingMem['hasSeenWelcome'] != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => DiscordWelcomeDialog(
                condominiumName:
                    condominium?['name']?.toString() ?? 'nosso Condomínio',
                membershipId: matchingMem['id'] as num,
                api: _communityApi,
                onExplored: () {
                  matchingMem['hasSeenWelcome'] = true;
                },
              ),
            );
          });
        }
      } else {
        notifications = _list(await _safeGet('/notifications/my'));
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _memberships = memberships;
        _selectedCondominiumId = selectedCondoId;
        _condominium = condominium;
        _subscription = subscription;
        _announcements = announcements;
        _packages = packages;
        _reservations = reservations;
        _notifications = notifications;
        _invoices = invoices;
        _polls = polls;
        _visitors = visitors;
        _tickets = tickets;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await _api.get(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleTheme() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextPref = isDark ? 'LIGHT' : 'DARK';
    AppTheme.setThemePreference(nextPref);
    try {
      await _communityApi.updateThemePreference(nextPref);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível salvar a preferência de tema: $error',
          ),
        ),
      );
    }
  }

  String _text(dynamic value, [String fallback = '—']) =>
      value == null || value.toString().isEmpty ? fallback : value.toString();

  String _formatDate(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return '—';
    return formatDateTime(raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = _notifications.where((e) => e['read'] != true).length;

    if (_tab == 4) {
      return UserProfilePage(
        token: widget.token,
        userName: widget.userName,
        userEmail: widget.userEmail,
        provider: widget.authProvider,
        onLogout: widget.onLogout,
        onClose: () {
          setState(() => _tab = 0);
          _load();
        },
        reauthenticateWithGoogle: widget.reauthenticateWithGoogle,
        refreshWithCredentials: widget.refreshWithCredentials,
        refreshGoogleSession: widget.refreshGoogleSession,
      );
    }

    const navTabs = <int>[0, 1, 2, 3, 5, 6, 7, 4];
    const destinations = <AncoraNavDestination>[
      AncoraNavDestination(
        id: 'overview',
        label: 'Início',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        section: 'Principal',
        showInBottomNav: true,
      ),
      AncoraNavDestination(
        id: 'packages',
        label: 'Encomendas e acesso',
        icon: Icons.inventory_2_outlined,
        section: 'Principal',
        showInBottomNav: true,
      ),
      AncoraNavDestination(
        id: 'reservations',
        label: 'Reservas',
        icon: Icons.event_available_outlined,
        section: 'Principal',
        showInBottomNav: true,
      ),
      AncoraNavDestination(
        id: 'chat',
        label: 'Chat com a portaria',
        icon: Icons.chat_bubble_outline_rounded,
        section: 'Principal',
        showInBottomNav: true,
      ),
      AncoraNavDestination(
        id: 'gallery',
        label: 'Galeria',
        icon: Icons.photo_library_outlined,
        section: 'Condomínio',
      ),
      AncoraNavDestination(
        id: 'community',
        label: 'Comunidade',
        icon: Icons.diversity_3_outlined,
        section: 'Condomínio',
      ),
      AncoraNavDestination(
        id: 'announcements',
        label: 'Comunicados',
        icon: Icons.campaign_outlined,
        section: 'Condomínio',
      ),
      AncoraNavDestination(
        id: 'profile',
        label: 'Meu perfil',
        icon: Icons.person_outline_rounded,
        section: 'Conta',
      ),
    ];
    final selectedIndex = navTabs.indexOf(_tab).clamp(0, navTabs.length - 1);
    final condoId = _condominium?['id'] as num?;
    final commandActions = <AncoraCommandAction>[
      for (var index = 0; index < navTabs.length; index++)
        AncoraCommandAction(
          id: destinations[index].id,
          title: 'Abrir ${destinations[index].label}',
          icon: destinations[index].icon,
          onExecute: () => setState(() => _tab = navTabs[index]),
          category: 'Navegação',
        ),
      AncoraCommandAction(
        id: 'profile',
        title: 'Abrir meu perfil',
        icon: Icons.person_outline_rounded,
        onExecute: () => setState(() => _tab = 4),
        category: 'Conta',
      ),
      AncoraCommandAction(
        id: 'assistant',
        title: 'Perguntar ao assistente do condomínio',
        icon: Icons.auto_awesome_rounded,
        onExecute: _openAssistantModal,
        category: 'Ações rápidas',
      ),
      AncoraCommandAction(
        id: 'billing',
        title: 'Consultar boletos e pagamentos',
        icon: Icons.receipt_long_outlined,
        onExecute: _openPaymentDialog,
        category: 'Ações rápidas',
      ),
      if (condoId != null)
        AncoraCommandAction(
          id: 'sos',
          title: 'Acionar alerta SOS',
          icon: Icons.emergency_rounded,
          onExecute: _openEmergencySos,
          category: 'Ações rápidas',
        ),
    ];
    final portalBody = _loading
        ? const AncoraDashboardSkeleton()
        : _error != null
        ? _errorPanel()
        : _memberships.isEmpty && _tab == 0
        ? _noCondominiumNotice()
        : IndexedStack(
            index: selectedIndex,
            children: List.generate(navTabs.length, (index) {
              final tab = navTabs[index];
              return _LazyIndexedTab(
                key: ValueKey(
                  '${widget.token}:${widget.currentRole}:$condoId:$isDesktop:$tab',
                ),
                isActive: selectedIndex == index,
                builder: (_) => _buildBody(isDesktop, tab: tab),
              );
            }),
          );

    return AncoraCommandShortcutWrapper(
      actions: commandActions,
      child: AncoraNavigationShell(
        title: 'Âncora Gestão',
        subtitle: _condominium?['name']?.toString() ?? 'Portal do morador',
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelect: (index) => setState(() => _tab = navTabs[index]),
        onOpenCommandPalette: () =>
            AncoraCommandShortcutWrapper.open(context, commandActions),
        body: portalBody,
        banner: _canManage && condoId != null && _hasFeature('EMERGENCY_SOS')
            ? EmergencySosBanner(api: _api, condominiumId: condoId)
            : null,
        headerActions: [
          if (condoId != null && _hasFeature('EMERGENCY_SOS'))
            IconButton(
              tooltip: 'Acionar alerta SOS',
              onPressed: _openEmergencySos,
              icon: const Icon(
                Icons.emergency_rounded,
                color: Color(0xFFDC2626),
              ),
            ),
          IconButton(
            tooltip: 'Serviços do condomínio',
            onPressed: _showMoreMenus,
            icon: const Icon(Icons.grid_view_rounded),
          ),
          if (condoId != null && _hasFeature('AI_ASSISTANT'))
            IconButton(
              tooltip: 'Assistente IA do condomínio',
              onPressed: _openAssistantModal,
              icon: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFD97706),
              ),
            ),
          IconButton(
            tooltip: 'Notificações',
            onPressed: _showNotifications,
            icon: Badge(
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          UserAvatar(
            imageSource: _profile['profileImage']?.toString(),
            name: _profile['firstName']?.toString() ?? widget.userName,
            radius: 17,
            onTap: () => setState(() => _tab = 4),
            tooltip: 'Meu perfil',
          ),
        ],
        sidebarFooterExtra: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.currentRole != null && widget.onSwitchRole != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RoleSwitcherPill(
                    currentRole: widget.currentRole!,
                    availableRoles: widget.availableRoles,
                    onSwitchRole: widget.onSwitchRole!,
                    isLight: !isDark,
                  ),
                ),
              ListTile(
                dense: true,
                leading: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                title: const Text('Alternar tema'),
                onTap: _toggleTheme,
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Sair da conta'),
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDesktop, {int? tab}) {
    switch (tab ?? _tab) {
      case 1:
        return _wrapPage(_packagesPage());
      case 2:
        if (_condominium != null && !_hasFeature('RESERVATIONS')) {
          return FeatureLockedPlaceholder(
            featureLabel: 'Reservas de Áreas Comuns',
            planName: _subAccess.planName,
            isSuspended: _subAccess.isSuspendedOrCancelled,
          );
        }
        return _wrapPage(_reservationsPage());
      case 3:
        if (_condominium != null && !_hasFeature('DOORMAN_CHAT')) {
          return FeatureLockedPlaceholder(
            featureLabel: 'Chat com a Portaria',
            planName: _subAccess.planName,
            isSuspended: _subAccess.isSuspendedOrCancelled,
          );
        }
        return _condominium != null
            ? DoormanChatView(
                condominiumId: _condominium!['id'],
                api: _communityApi,
                isDoormanMode: false,
              )
            : const SaaSEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Nenhum condomínio ativo',
                subtitle:
                    'Vincule-se a um condomínio para conversar com a portaria.',
              );
      case 5:
        return _condominium != null
            ? CondominiumGalleryView(
                condominiumId: _condominium!['id'],
                api: _communityApi,
                canManage: _canManage,
              )
            : const SaaSEmptyState(
                icon: Icons.photo_library_outlined,
                title: 'Nenhum condomínio ativo',
                subtitle:
                    'Vincule-se a um condomínio para visualizar a galeria de fotos.',
              );
      case 6:
        return _condominium != null
            ? CommunityHubView(
                api: _communityApi,
                condominiumId: _condominium!['id'],
                initialCategoryIndex: _communityCategoryIndex,
                canManage: _canManage,
                enabledFeatures: _subAccess.enabledFeatures.toList(),
              )
            : _wrapPage(_announcementsPage());
      case 7:
        return _wrapPage(_announcementsPage());
      default:
        return _buildResidentDashboard(isDesktop);
    }
  }

  Widget _wrapPage(Widget content) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            children: [content],
          ),
        ),
      ),
    );
  }

  String get _residentFirstName {
    final fromProfile = _profile['firstName']?.toString().trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return firstNameOf(widget.userName, fallback: 'Morador');
  }

  Future<void> _openQuickVisitorDialog() async {
    final condoId = _condominium?['id'] as num?;
    if (condoId == null) return;
    final nameCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    String visitorType = 'VISITOR';
    bool saving = false;

    final createdVisitor = await showAncoraDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: SaaSColors.primary),
              SizedBox(width: 10),
              Expanded(child: Text('Liberar Visitante (QR Code)')),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nome do visitante ou prestador *',
                      hintText: 'Ex.: João da Silva',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: visitorType,
                    decoration: const InputDecoration(labelText: 'Tipo de acesso'),
                    items: const [
                      DropdownMenuItem(value: 'VISITOR', child: Text('Visitante / Convidado')),
                      DropdownMenuItem(value: 'SERVICE_PROVIDER', child: Text('Prestador de Serviço')),
                      DropdownMenuItem(value: 'DELIVERY', child: Text('Entregador')),
                    ],
                    onChanged: (v) => setDlgState(() => visitorType = v ?? visitorType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: docCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Documento (RG / CPF - opcional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: plateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Placa do veículo (opcional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        SaaSFeedback.showWarning(
                          context,
                          'Informe o nome do visitante.',
                        );
                        return;
                      }
                      setDlgState(() => saving = true);
                      try {
                        final res = await _communityApi.createVisitor(
                          condoId: condoId,
                          visitorName: nameCtrl.text.trim(),
                          visitorType: visitorType,
                          documentNumber: docCtrl.text.trim().isEmpty
                              ? null
                              : docCtrl.text.trim(),
                          vehiclePlate: plateCtrl.text.trim().isEmpty
                              ? null
                              : plateCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx, res);
                      } catch (e) {
                        setDlgState(() => saving = false);
                        if (context.mounted) {
                          SaaSFeedback.showError(context, 'Erro: $e');
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_rounded, size: 18),
              label: const Text('Gerar Convite QR'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    docCtrl.dispose();
    plateCtrl.dispose();

    if (createdVisitor != null && mounted) {
      await _load();
      final visitorId = createdVisitor['id'] as num?;
      if (visitorId != null && mounted) {
        await showAncoraDialog<void>(
          context: context,
          builder: (_) => VisitorDigitalPassDialog(
            visitorId: visitorId,
            api: _communityApi,
          ),
        );
      }
    }
  }

  Future<void> _openQuickTicketDialog() async {
    final condoId = _condominium?['id'] as num?;
    if (condoId == null) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String category = 'MAINTENANCE';
    bool saving = false;

    final created = await showAncoraDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.report_problem_outlined, color: SaaSColors.warning),
              SizedBox(width: 10),
              Expanded(child: Text('Registrar Ocorrência / Chamado')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Assunto da ocorrência *',
                      hintText: 'Ex.: Lâmpada queimada no corredor',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'MAINTENANCE', child: Text('Manutenção')),
                      DropdownMenuItem(value: 'NOISE', child: Text('Barulho / Sossego')),
                      DropdownMenuItem(value: 'CLEANING', child: Text('Limpeza')),
                      DropdownMenuItem(value: 'SECURITY', child: Text('Segurança')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
                    ],
                    onChanged: (v) => setDlgState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Local (opcional)',
                      hintText: 'Ex.: Bloco 2 • Hall do 4º andar',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição *',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty ||
                          descCtrl.text.trim().isEmpty) {
                        SaaSFeedback.showWarning(
                          context,
                          'Informe assunto e descrição.',
                        );
                        return;
                      }
                      setDlgState(() => saving = true);
                      try {
                        await _communityApi.createTicket(
                          condoId: condoId,
                          category: category,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          location: locationCtrl.text.trim().isEmpty
                              ? null
                              : locationCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDlgState(() => saving = false);
                        if (context.mounted) {
                          SaaSFeedback.showError(context, 'Erro: $e');
                        }
                      }
                    },
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text('Enviar Ocorrência'),
            ),
          ],
        ),
      ),
    );
    titleCtrl.dispose();
    descCtrl.dispose();
    locationCtrl.dispose();
    if (created == true && mounted) {
      SaaSFeedback.showSuccess(context, 'Ocorrência registrada com sucesso!');
      _load();
    }
  }

  Future<void> _votePoll(num pollId, num optionId) async {
    try {
      await _communityApi.votePoll(pollId: pollId, optionId: optionId);
      if (!mounted) return;
      SaaSFeedback.showSuccess(context, 'Voto registrado na enquete!');
      _load();
    } catch (e) {
      if (mounted) SaaSFeedback.showError(context, 'Não foi possível votar: $e');
    }
  }

  Widget _buildResidentDashboard(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final condoName = _condominium?['name']?.toString() ?? 'Condomínio';

    final pendingPackagesList = _packages
        .where(
          (e) =>
              e['status'] == 'WAITING_PICKUP' ||
              e['status'] == 'RECEIVED' ||
              e['status'] == 'NOTIFIED' ||
              e['status'] == 'PENDING',
        )
        .toList();
    final pendingPkgs = pendingPackagesList.length;

    final scheduledReservations = _reservations.where((r) {
      final s = (r['status']?.toString() ?? '').toUpperCase();
      if (s == 'CANCELLED' || s == 'REJECTED' || s == 'DENIED') return false;
      final end = parseUtcToLocal(r['endAt']);
      return end == null || end.isAfter(DateTime.now());
    }).toList();
    final activeRes = scheduledReservations.length;

    final openInvoices = _invoices
        .where((i) => i['status'] != 'PAID' && i['status'] != 'UP_TO_DATE')
        .toList();
    final hasOpenInvoice = openInvoices.isNotEmpty;
    final firstOpenInvoice = hasOpenInvoice ? openInvoices.first : null;
    final hasOverdue = openInvoices.any((i) => i['status'] == 'OVERDUE');

    final latestPkg = pendingPackagesList.isNotEmpty
        ? pendingPackagesList.first
        : null;
    final pkgSubtitle = latestPkg != null
        ? '${latestPkg['description'] ?? 'Pacote'} • ${_formatDate(latestPkg['receivedAt'])}'
        : 'Nenhuma encomenda aguardando retirada';

    final nextRes = scheduledReservations.isNotEmpty
        ? scheduledReservations.first
        : null;
    final resSubtitle = nextRes != null
        ? '${nextRes['commonAreaName'] ?? 'Área comum'} • ${_formatDate(nextRes['startAt'])}'
        : 'Nenhuma reserva agendada';

    final brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final invAmount = (firstOpenInvoice?['amount'] as num?)?.toDouble();
    final finValue = hasOpenInvoice
        ? (hasOverdue ? 'Taxa Vencida' : 'Taxa em Aberto')
        : 'Em dia';
    final finSubtitle = hasOpenInvoice
        ? '${firstOpenInvoice?['dueDate'] != null ? 'Vence ${_formatDueDate(firstOpenInvoice!['dueDate'])}' : 'Aberto'}${invAmount != null ? ' • ${brl.format(invAmount)}' : ''}'
        : 'Sem pendências financeiras';

    final totalAnnouncements = _announcements.length;
    final annSubtitle = _announcements.isNotEmpty
        ? (_announcements.first['title']?.toString() ?? 'Mural atualizado')
        : 'Nenhum comunicado publicado';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 16,
          16,
          isDesktop ? 24 : 16,
          28,
        ),
        children: [
          SubscriptionStatusBanner(access: _subAccess),
          // Contextual Greeting Banner
          _buildResidentContextBanner(isDark, condoName),
          const SizedBox(height: 16),

          // 4 Status Cards
          SaaSMetricGrid(
            items: [
              SaaSMetricCard(
                title: 'Encomendas',
                value: pendingPkgs > 0
                    ? '$pendingPkgs Aguardando Retirada'
                    : '0 Aguardando',
                icon: Icons.inventory_2_outlined,
                iconColor: pendingPkgs > 0
                    ? SaaSColors.success
                    : SaaSColors.primary,
                trend: pendingPkgs > 0 ? 'Na portaria' : null,
                subtitle: pkgSubtitle,
                onTap: () => setState(() => _tab = 1),
              ),
              SaaSMetricCard(
                title: 'Reservas',
                value: activeRes > 0
                    ? '$activeRes ${activeRes == 1 ? 'Próxima' : 'Próximas'}'
                    : '0 Reservas',
                icon: Icons.event_available_outlined,
                iconColor: SaaSColors.primary,
                subtitle: resSubtitle,
                onTap: () => setState(() => _tab = 2),
              ),
              SaaSMetricCard(
                title: 'Financeiro',
                value: finValue,
                icon: Icons.receipt_long_outlined,
                iconColor: hasOverdue
                    ? SaaSColors.error
                    : (hasOpenInvoice ? SaaSColors.warning : SaaSColors.success),
                trend: hasOpenInvoice ? 'Pagar com PIX' : 'Quitado',
                trendPositive: !hasOpenInvoice,
                subtitle: finSubtitle,
                onTap: firstOpenInvoice != null
                    ? () => _paySingleBoleto(firstOpenInvoice)
                    : _openPaymentDialog,
              ),
              SaaSMetricCard(
                title: 'Comunicados',
                value: totalAnnouncements > 0
                    ? '$totalAnnouncements ${totalAnnouncements == 1 ? 'Novo' : 'Novos'}'
                    : '0 Novos',
                icon: Icons.campaign_outlined,
                iconColor: SaaSColors.purple,
                subtitle: annSubtitle,
                onTap: () => setState(() => _tab = 7),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Quick Actions Grid
          _buildQuickActionShortcuts(),
          const SizedBox(height: 18),

          // Responsive Columns for Widgets
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildResidentPendingInvoiceCard(isDark),
                      const SizedBox(height: 16),
                      _buildUpcomingReservationsSection(),
                      const SizedBox(height: 16),
                      _buildResidentVisitorsAndTicketsSection(isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildRecentAnnouncementsSection(),
                      const SizedBox(height: 16),
                      _buildActivePollsSection(isDark),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildResidentPendingInvoiceCard(isDark),
            const SizedBox(height: 16),
            _buildUpcomingReservationsSection(),
            const SizedBox(height: 16),
            _buildRecentAnnouncementsSection(),
            const SizedBox(height: 16),
            _buildActivePollsSection(isDark),
            const SizedBox(height: 16),
            _buildResidentVisitorsAndTicketsSection(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildResidentContextBanner(bool isDark, String condoName) {
    final condoImg = _condominium?['imageUrl'] as String?;
    final imgProvider = resolveAvatarImageProvider(condoImg);

    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: SaaSColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: imgProvider != null
            ? Image(image: imgProvider, fit: BoxFit.cover)
            : const Icon(
                Icons.apartment_rounded,
                color: SaaSColors.primary,
                size: 28,
              ),
      ),
    );

    final greetingCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olá, $_residentFirstName!',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: SaaSColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$_unitDisplay - $_sectorDisplay • $condoName',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SaaSColors.textSecondary(isDark),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final actionsWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_memberships.length > 1)
          AncoraDropdown<int>(
            compact: true,
            prefixIcon: Icons.apartment_rounded,
            value: (_activeMembership?['id'] as num?)?.toInt() ??
                _selectedCondominiumId,
            items: _memberships
                .where((m) => m['condominiumId'] != null)
                .map((m) {
                  final memId =
                      (m['id'] as num?)?.toInt() ??
                      (m['condominiumId'] as num).toInt();
                  final unitIdPart =
                      m['unitLabel']?.toString() ??
                      (m['unitIdentifier'] != null
                          ? 'Unidade ${m['unitIdentifier']}'
                          : null);
                  return AncoraMenuOption<int>(
                    value: memId,
                    label: m['condominiumName']?.toString() ?? 'Condomínio',
                    subtitle: unitIdPart,
                  );
                })
                .toList(),
            onChanged: (selectedKey) {
              Map<String, dynamic>? chosen;
              for (final m in _memberships) {
                final key =
                    (m['id'] as num?)?.toInt() ??
                    (m['condominiumId'] as num?)?.toInt();
                if (key == selectedKey) {
                  chosen = m;
                  break;
                }
              }
              final nextCondoId = (chosen?['condominiumId'] as num?)?.toInt();
              setState(() {
                _selectedMembershipId = selectedKey;
                if (nextCondoId != null) _selectedCondominiumId = nextCondoId;
              });
              _load();
            },
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _tab = 4),
          icon: const Icon(Icons.person_outline_rounded, size: 16),
          label: const Text('Meus dados'),
        ),
      ],
    );

    return SaaSGlassCard(
      padding: const EdgeInsets.all(18),
      accentGlowColor: SaaSColors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(child: greetingCol),
                  ],
                ),
                const SizedBox(height: 12),
                actionsWrap,
              ],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: 14),
              Expanded(child: greetingCol),
              const SizedBox(width: 12),
              actionsWrap,
            ],
          );
        },
      ),
    );
  }

  Widget _buildResidentPendingInvoiceCard(bool isDark) {
    return _buildPendingBoletoSection();
  }

  Widget _buildQuickActionShortcuts() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SaaSSectionHeader(
          title: 'Ações Rápidas',
          subtitle: 'Acesse os serviços da sua unidade em um clique',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final cols = maxW >= 1000 ? 6 : (maxW >= 620 ? 3 : 2);
            const gap = 12.0;
            final tileW = (maxW - gap * (cols - 1)) / cols;
            final actions = <(String, IconData, Color, VoidCallback)>[
              if (_hasFeature('FINANCIAL'))
                (
                  'Pagar Condomínio / PIX',
                  Icons.qr_code_2_rounded,
                  SaaSColors.success,
                  _openPaymentDialog,
                ),
              if (_hasFeature('RESERVATIONS'))
                (
                  'Reservar Área Comum',
                  Icons.event_available_rounded,
                  SaaSColors.primary,
                  _createReservation,
                ),
              if (_hasFeature('VISITORS'))
                (
                  'Liberar Visitante (QR Code)',
                  Icons.badge_outlined,
                  SaaSColors.purple,
                  _openQuickVisitorDialog,
                ),
              if (_hasFeature('DOORMAN_CHAT'))
                (
                  'Chat com Portaria',
                  Icons.chat_bubble_outline_rounded,
                  const Color(0xFF06B6D4),
                  () => setState(() => _tab = 3),
                ),
              if (_hasFeature('COMMUNITY_TICKETS'))
                (
                  'Registrar Ocorrência',
                  Icons.report_problem_outlined,
                  SaaSColors.warning,
                  _openQuickTicketDialog,
                ),
              (
                'Mural da Comunidade',
                Icons.diversity_3_outlined,
                isDark ? const Color(0xFF60A5FA) : const Color(0xFF4F46E5),
                () => setState(() => _tab = 6),
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: actions
                  .map(
                    (a) => SizedBox(
                      width: tileW > 0 ? tileW : maxW,
                      child: SaaSQuickActionCard(
                        title: a.$1,
                        icon: a.$2,
                        color: a.$3,
                        onTap: a.$4,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivePollsSection(bool isDark) {
    final activePolls = _polls.where((p) => p['active'] != false).toList();
    return SaaSGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaaSSectionHeader(
            title: 'Enquetes Ativas',
            badge: SaaSBadge(
              label: '${activePolls.length}',
              variant: activePolls.isNotEmpty
                  ? SaaSBadgeVariant.purple
                  : SaaSBadgeVariant.neutral,
            ),
            action: TextButton(
              onPressed: () => setState(() => _tab = 6),
              child: const Text('Ver comunidade'),
            ),
          ),
          if (activePolls.isEmpty)
            const SaaSEmptyState(
              icon: Icons.poll_outlined,
              title: 'Nenhuma enquete ativa',
              subtitle: 'Quando o síndico abrir uma votação rápida, ela aparecerá aqui.',
            )
          else
            ...activePolls.take(2).map((poll) {
              final options = (poll['options'] is List)
                  ? (poll['options'] as List)
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList()
                  : <Map<String, dynamic>>[];
              final votedOptionId =
                  poll['myOptionId'] ?? poll['userVotedOptionId'];
              final totalVotes = (poll['totalVotes'] as num?)?.toInt() ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SaaSColors.surfaceSubtle(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : SaaSColors.border(isDark),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poll['title']?.toString() ?? 'Enquete',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if ((poll['description']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        poll['description'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: SaaSColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    ...options.map((opt) {
                      final optId = opt['id'] as num?;
                      final isChosen =
                          votedOptionId != null && votedOptionId == optId;
                      final count =
                          (opt['votes'] as num?)?.toInt() ??
                          (opt['voteCount'] as num?)?.toInt() ??
                          0;
                      final pct = totalVotes > 0
                          ? ((count / totalVotes) * 100).round()
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: (optId != null && poll['id'] is num)
                              ? () => _votePoll(poll['id'] as num, optId)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isChosen
                                  ? SaaSColors.primary.withValues(alpha: 0.16)
                                  : SaaSColors.surface(isDark),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isChosen
                                    ? SaaSColors.primary
                                    : SaaSColors.border(isDark),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isChosen
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 16,
                                  color: isChosen
                                      ? SaaSColors.primary
                                      : SaaSColors.textSecondary(isDark),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    opt['label']?.toString() ??
                                        opt['optionText']?.toString() ??
                                        opt['text']?.toString() ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$pct% ($count)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: SaaSColors.textSecondary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildResidentVisitorsAndTicketsSection(bool isDark) {
    return SaaSGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaaSSectionHeader(
            title: 'Meus Visitantes & Ocorrências',
            action: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openQuickVisitorDialog,
                  icon: const Icon(Icons.qr_code_rounded, size: 15),
                  label: const Text('Novo Visitante'),
                ),
                OutlinedButton.icon(
                  onPressed: _openQuickTicketDialog,
                  icon: const Icon(Icons.add_comment_outlined, size: 15),
                  label: const Text('Ocorrência'),
                ),
              ],
            ),
          ),
          if (_visitors.isEmpty && _tickets.isEmpty)
            const SaaSEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Nenhum visitante ou ocorrência ativa',
              subtitle:
                  'Libere visitantes com QR Code ou registre uma ocorrência para a administração.',
            )
          else ...[
            if (_visitors.isNotEmpty) ...[
              Text(
                'Visitantes autorizados (${_visitors.length})',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: SaaSColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              ..._visitors.take(3).map((v) {
                final st = v['status']?.toString() ?? 'AUTHORIZED';
                final variant = switch (st) {
                  'CHECKED_IN' => SaaSBadgeVariant.success,
                  'DENIED' || 'CANCELLED' => SaaSBadgeVariant.error,
                  _ => SaaSBadgeVariant.primary,
                };
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: SaaSColors.surfaceSubtle(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : SaaSColors.border(isDark),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v['visitorName']?.toString() ?? 'Visitante',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Código: ${v['accessCode'] ?? '—'} • ${_formatDate(v['expectedAt'] ?? v['createdAt'])}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: SaaSColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SaaSBadge(label: st, variant: variant),
                      if (v['id'] is num) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Ver Convite QR / WhatsApp',
                          icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                          onPressed: () => showAncoraDialog<void>(
                            context: context,
                            builder: (_) => VisitorDigitalPassDialog(
                              visitorId: v['id'] as num,
                              api: _communityApi,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
            if (_tickets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Minhas ocorrências (${_tickets.length})',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: SaaSColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              ..._tickets.take(3).map((t) {
                final st = t['status']?.toString() ?? 'OPEN';
                final variant = switch (st) {
                  'RESOLVED' || 'CLOSED' => SaaSBadgeVariant.success,
                  'IN_PROGRESS' => SaaSBadgeVariant.primary,
                  'CANCELLED' => SaaSBadgeVariant.neutral,
                  _ => SaaSBadgeVariant.warning,
                };
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: SaaSColors.surfaceSubtle(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : SaaSColors.border(isDark),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['title']?.toString() ?? 'Ocorrência',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${t['category'] ?? 'Geral'} • ${_formatDate(t['createdAt'])}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: SaaSColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SaaSBadge(label: st, variant: variant),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openEmergencySos() async {
    final condoId = _condominium?['id'] as num?;
    if (condoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vincule-se a um condomínio para acionar o alerta SOS.',
          ),
        ),
      );
      return;
    }
    if (!_hasFeature('EMERGENCY_SOS')) {
      SaaSFeedback.showWarning(
        context,
        'O alerta SOS está bloqueado no plano atual ou assinatura inativa.',
      );
      return;
    }
    final unitId = _activeMembership?['unitId'] as num?;
    await showAncoraDialog<void>(
      context: context,
      builder: (_) => EmergencySOSDialog(
        condominiumId: condoId,
        api: _communityApi,
        unitId: unitId,
        onAlertSent: _refreshNotifications,
      ),
    );
  }

  Widget _empty(String message, IconData icon) =>
      SaaSEmptyState(icon: icon, title: message);

  Widget _errorPanel() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SaaSErrorState(message: _error!, onRetry: _load),
    ),
  );

  Widget _noCondominiumNotice() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFE0E7FF),
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 38,
                    color: Color(0xFF2F3FB0),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Sua conta ainda não está vinculada a um condomínio.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Solicite entrada em um condomínio existente para aprovação do síndico.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openJoinCondominiumDialog,
                    icon: const Icon(Icons.add_home_work_rounded),
                    label: const Text('Solicitar entrada em condomínio'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

}
