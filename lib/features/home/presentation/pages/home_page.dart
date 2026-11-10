import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/services/realtime_service.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/enter_search_field.dart';
import '../../../../core/widgets/role_switcher_pill.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/pages/user_profile_page.dart';
import '../../../community/data/community_api.dart';
import '../../../community/presentation/dialogs/boleto_payment_dialog.dart';
import '../../../community/presentation/dialogs/common_area_booking_dialog.dart';
import '../../../community/presentation/dialogs/discord_welcome_dialog.dart';
import '../../../community/presentation/dialogs/join_condominium_dialog.dart';
import '../../../community/presentation/views/community_hub_view.dart';
import '../../../community/presentation/views/condominium_gallery_view.dart';
import '../../../community/presentation/views/doorman_chat_view.dart';
import '../../data/home_service.dart';
import 'notifications_page.dart';

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
  });

  final Future<void> Function() onLogout;
  final String? token;
  final String? userName;
  final String? userEmail;
  final String authProvider;
  final Future<String> Function() reauthenticateWithGoogle;
  final Future<void> Function(String email, String password) refreshWithCredentials;
  final Future<void> Function() refreshGoogleSession;
  final String? currentRole;
  final List<String> availableRoles;
  final ValueChanged<String>? onSwitchRole;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeService _api;
  late CommunityApi _communityApi;
  StreamSubscription<RealtimeEvent>? _realtimeSub;
  int _tab = 0; // 0: Início, 1: Acesso/Encomendas, 2: Reservas, 3: Mensagens/Chat, 4: Perfil, 5: Galeria, 6: Hub
  final int _communityCategoryIndex = 0;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _memberships = [];
  Map<String, dynamic>? _condominium;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _profile = {};

  String _packageQuery = '';
  String _reservationQuery = '';
  String _reservationFilter = 'SCHEDULED'; // SCHEDULED, PAST, CANCELLED
  String _announcementQuery = '';

  String get _residentFirstName {
    final fromProfile = firstNameOf(_profile['firstName']?.toString());
    if (fromProfile.isNotEmpty) return fromProfile;
    final fromSession = firstNameOf(widget.userName);
    if (fromSession.isNotEmpty && !fromSession.contains('@')) {
      return fromSession;
    }
    return 'Lucas';
  }

  String get _unitDisplay {
    if (_memberships.isNotEmpty) {
      final mem = _memberships.first;
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
    if (_memberships.isNotEmpty) {
      final mem = _memberships.first;
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
    _api = HomeService(token: widget.token);
    _communityApi = CommunityApi(api: _api);
    _initRealtime();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _api = HomeService(token: widget.token);
      _communityApi = CommunityApi(api: _api);
      _initRealtime();
      _load();
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
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
    switch (event.type) {
      case 'NOTIFICATION':
      case 'SYSTEM_ANNOUNCEMENT':
        _refreshNotifications();
        break;
      case 'PACKAGE_UPDATED':
        _refreshPackages();
        _refreshNotifications();
        break;
      case 'ANNOUNCEMENT':
        _refreshAnnouncements();
        _refreshNotifications();
        break;
      case 'RESERVATION_UPDATED':
        _refreshReservations();
        _refreshNotifications();
        break;
      case 'INVOICE_UPDATED':
        _refreshInvoices();
        break;
      case 'CHAT_MESSAGE':
        _refreshNotifications();
        break;
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      final res = await _safeGet('/notifications/my');
      if (!mounted) return;
      setState(() => _notifications = _list(res));
    } catch (_) {}
  }

  Future<void> _refreshPackages() async {
    try {
      final res = await _safeGet('/packages/my?page=0&size=20');
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
        _safeGet('/notifications/my'),
      ]);
      final profile = _map(initial[0]);
      final memberships = _list(initial[1]);
      final notifications = _list(initial[2]);

      // Apply saved theme preference
      final themePref = profile['themePreference']?.toString();
      if (themePref != null && themePref.isNotEmpty) {
        AppTheme.setThemePreference(themePref);
      }

      Map<String, dynamic>? condominium;
      List<Map<String, dynamic>> announcements = [];
      List<Map<String, dynamic>> packages = [];
      List<Map<String, dynamic>> reservations = [];
      List<Map<String, dynamic>> invoices = [];

      if (memberships.isNotEmpty) {
        final id = memberships.first['condominiumId'];
        condominium = _map(await _api.get('/condominiums/$id'));

        final results = await Future.wait([
          _safeGet('/condominiums/$id/announcements'),
          _safeGet('/packages/my?page=0&size=20'),
          _safeGet('/condominiums/$id/reservations/my'),
          _safeGet('/condominiums/$id/my-invoices'),
        ]);

        announcements = _list(results[0]);
        packages = _list(results[1]);
        reservations = _list(results[2]);
        invoices = _list(results[3]);

        // Discord welcome dialog on first access
        final firstMem = memberships.first;
        if (firstMem['hasSeenWelcome'] != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => DiscordWelcomeDialog(
                condominiumName: condominium?['name']?.toString() ?? 'nosso Condomínio',
                membershipId: firstMem['id'] as num,
                api: _communityApi,
                onExplored: () {
                  firstMem['hasSeenWelcome'] = true;
                },
              ),
            );
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _memberships = memberships;
        _condominium = condominium;
        _announcements = announcements;
        _packages = packages;
        _reservations = reservations;
        _notifications = notifications;
        _invoices = invoices;
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

  void _toggleTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextPref = isDark ? 'LIGHT' : 'DARK';
    AppTheme.setThemePreference(nextPref);
    _communityApi.updateThemePreference(nextPref);
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      drawer: isDesktop ? null : _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top curved header (Royal Blue / Dark Slate)
            _buildHeader(isDesktop, isDark, unreadCount),

            // Content Area
            Expanded(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: SaaSLoadingState(
                          message: 'Carregando suas informações e comunicados...',
                        ),
                      ),
                    )
                  : _error != null
                      ? _errorPanel()
                      : _memberships.isEmpty && _tab == 0
                          ? _noCondominiumNotice()
                          : _buildBody(isDesktop),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNavigation(),
    );
  }

  Widget _buildHeader(bool isDesktop, bool isDark, int unreadCount) {
    if (isDesktop) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.apartment_rounded, color: SaaSColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _text(_condominium?['name'], 'Condomínio Digital'),
                  style: TextStyle(
                    color: SaaSColors.textPrimary(isDark),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Olá, $_residentFirstName! • $_unitDisplay',
                  style: TextStyle(
                    color: SaaSColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 28),

            // Horizontal navigation tabs for desktop
            _desktopNavTab('Início', 0),
            _desktopNavTab('Acesso & Encomendas', 1),
            _desktopNavTab('Reservas', 2),
            _desktopNavTab('Chat Portaria', 3),
            _desktopNavTab('Galeria de Fotos', 5),
            _desktopNavTab('Comunidade', 6),
            _desktopNavTab('Comunicados', 7),

            const Spacer(),

            if (widget.currentRole != null && widget.onSwitchRole != null) ...[
              RoleSwitcherPill(
                currentRole: widget.currentRole!,
                availableRoles: widget.availableRoles,
                onSwitchRole: widget.onSwitchRole!,
                isLight: !isDark,
              ),
              const SizedBox(width: 8),
            ],

            IconButton(
              tooltip: 'Assistente IA do Condomínio',
              onPressed: _openAssistantModal,
              icon: const Icon(
                Icons.auto_awesome,
                color: Color(0xFFEAB308),
                size: 20,
              ),
            ),

            IconButton(
              tooltip: isDark ? 'Modo Claro' : 'Modo Noturno',
              onPressed: _toggleTheme,
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                size: 20,
              ),
            ),

            IconButton(
              tooltip: 'Central de Notificações',
              onPressed: _showNotifications,
              icon: Badge(
                label: Text('$unreadCount'),
                isLabelVisible: unreadCount > 0,
                backgroundColor: const Color(0xFFEF4444),
                child: Icon(
                  Icons.notifications_outlined,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 8),

            UserAvatar(
              imageSource: _profile['profileImage']?.toString(),
              name: _profile['firstName']?.toString() ?? widget.userName,
              radius: 18,
              onTap: () => setState(() => _tab = 4),
              tooltip: 'Meu Perfil',
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet Header
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1D4ED8),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              const Spacer(),
              if (widget.currentRole != null && widget.onSwitchRole != null) ...[
                RoleSwitcherPill(
                  currentRole: widget.currentRole!,
                  availableRoles: widget.availableRoles,
                  onSwitchRole: widget.onSwitchRole!,
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                tooltip: 'Assistente IA',
                onPressed: _openAssistantModal,
                icon: const Icon(Icons.auto_awesome, color: Color(0xFFFDE047), size: 22),
              ),
              IconButton(
                tooltip: isDark ? 'Modo Claro' : 'Modo Noturno',
                onPressed: _toggleTheme,
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              IconButton(
                tooltip: 'Central de Notificações',
                onPressed: _showNotifications,
                icon: Badge(
                  label: Text('$unreadCount'),
                  isLabelVisible: unreadCount > 0,
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 4),
              UserAvatar(
                imageSource: _profile['profileImage']?.toString(),
                name: _profile['firstName']?.toString() ?? widget.userName,
                radius: 17,
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                borderColor: Colors.white38,
                onTap: () => setState(() => _tab = 4),
                tooltip: 'Meu Perfil',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Olá, $_residentFirstName! 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bem-vindo ao ${_text(_condominium?['name'], 'Residencial Vila das Flores')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopNavTab(String title, int tabIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _tab == tabIndex;
    final hasNew = (tabIndex == 1 && _packages.any((p) => p['status'] == 'WAITING_PICKUP' || p['status'] == 'RECEIVED')) ||
                   (tabIndex == 2 && _reservations.any((r) => r['status'] == 'COUNTER_PROPOSED')) ||
                   (tabIndex == 6 && _announcements.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _tab = tabIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? (isDark ? const Color(0xFF60A5FA) : SaaSColors.primary)
                      : SaaSColors.textSecondary(isDark),
                ),
              ),
              if (hasNew) ...[
                const SizedBox(width: 5),
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
            accountName: Text('$_residentFirstName (${widget.userName ?? ''})'),
            accountEmail: Text(widget.userEmail ?? ''),
            currentAccountPicture: UserAvatar(
              imageSource: _profile['profileImage']?.toString(),
              name: _profile['firstName']?.toString() ?? widget.userName,
              radius: 36,
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
              borderColor: Colors.white38,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Início'),
            selected: _tab == 0,
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Encomendas & Acesso'),
            selected: _tab == 1,
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Reservas de Áreas'),
            selected: _tab == 2,
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: const Text('Chat com a Portaria'),
            selected: _tab == 3,
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeria do Condomínio'),
            selected: _tab == 5,
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 5);
            },
          ),
          ListTile(
            leading: const Icon(Icons.diversity_3_outlined),
            title: const Text('Central da Comunidade'),
            selected: _tab == 6,
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 6);
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Mural de Comunicados'),
            selected: _tab == 7,
            onTap: () {
              Navigator.pop(context);
              setState(() => _tab = 7);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Boletos & Taxa'),
            onTap: () {
              Navigator.pop(context);
              _openPaymentDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_medium_rounded),
            title: const Text('Alternar Tema Noturno/Claro'),
            onTap: () {
              Navigator.pop(context);
              _toggleTheme();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              widget.onLogout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: NavigationBar(
        height: 64,
        selectedIndex: _tab > 4 ? 0 : _tab,
        onDestinationSelected: (idx) {
          if (idx == 1) {
            setState(() => _tab = 1);
          } else if (idx == 2) {
            // Center action opens quick services menu
            _showMoreMenus();
          } else if (idx == 3) {
            setState(() => _tab = 3);
          } else if (idx == 4) {
            setState(() => _tab = 4);
          } else {
            setState(() => _tab = 0);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF1E3A8A)),
            label: 'Início',
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1E3A8A)),
            label: 'Acesso',
          ),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
            ),
            label: 'Ações',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: Color(0xFF1E3A8A)),
            label: 'Mensagens',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF1E3A8A)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDesktop) {
    switch (_tab) {
      case 1:
        return _wrapPage(_packagesPage());
      case 2:
        return _wrapPage(_reservationsPage());
      case 3:
        return _condominium != null
            ? DoormanChatView(
                condominiumId: _condominium!['id'],
                api: _communityApi,
                isDoormanMode: false,
              )
            : const SaaSEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Nenhum condomínio ativo',
                subtitle: 'Vincule-se a um condomínio para conversar com a portaria.',
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
                subtitle: 'Vincule-se a um condomínio para visualizar a galeria de fotos.',
              );
      case 6:
        return _condominium != null
            ? CommunityHubView(
                api: _communityApi,
                condominiumId: _condominium!['id'],
                initialCategoryIndex: _communityCategoryIndex,
                canManage: _canManage,
                enabledFeatures: (_condominium!['features'] as List?)?.map((e) => e.toString()).toList(),
              )
            : _wrapPage(_announcementsPage());
      case 7:
        return _wrapPage(_announcementsPage());
      default:
        return isDesktop ? _desktopDashboard() : _mobileDashboard();
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

  // ----------------------------------------------------
  // MOBILE DASHBOARD (EXACT VISUAL MATCH TO SCREENSHOT)
  // ----------------------------------------------------
  Widget _mobileDashboard() {
    final hasNewPackage = _packages.any((p) => p['status'] == 'WAITING_PICKUP' || p['status'] == 'RECEIVED');
    final hasNewAnnouncement = _announcements.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (hasNewPackage || hasNewAnnouncement) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (hasNewPackage) '📦 Nova encomenda na portaria',
                        if (hasNewAnnouncement) '📢 Novo comunicado no condomínio',
                      ].join('  •  '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Unit Card
          _buildUnitCard(),
          const SizedBox(height: 18),

          // Atalhos rápidos (5 pastel boxes)
          _buildQuickActionShortcuts(),
          const SizedBox(height: 20),

          // Boletos em aberto
          _buildPendingBoletoSection(),
          const SizedBox(height: 20),

          // Comunicados recentes
          _buildRecentAnnouncementsSection(),
          const SizedBox(height: 20),

          // Próximas reservas & contrapropostas
          _buildUpcomingReservationsSection(),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // DESKTOP DASHBOARD (HORIZONTAL MULTI-COLUMN NO SCROLL)
  // ----------------------------------------------------
  Widget _desktopDashboard() {
    final pendingPkgs = _packages
        .where((e) => e['status'] == 'WAITING_PICKUP' || e['status'] == 'PENDING')
        .length;
    final activeRes = _reservations
        .where((r) => r['status'] == 'APPROVED' || r['status'] == 'PENDING')
        .length;
    final totalAnnouncements = _announcements.length;
    final hasOverdueInvoices = _invoices.any((i) => i['status'] == 'OVERDUE');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
        child: Column(
          children: [
            // KPI Stat strip
            Row(
              children: [
                Expanded(
                  child: SaaSMetricCard(
                    title: 'Encomendas a Retirar',
                    value: '$pendingPkgs',
                    icon: Icons.inventory_2_outlined,
                    iconColor: pendingPkgs > 0
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                    subtitle: pendingPkgs > 0 ? 'Na portaria' : 'Tudo retirado',
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SaaSMetricCard(
                    title: 'Reservas Ativas',
                    value: '$activeRes',
                    icon: Icons.event_available_outlined,
                    iconColor: const Color(0xFF2563EB),
                    subtitle: activeRes > 0 ? 'Próximos agendamentos' : 'Nenhuma reserva',
                    onTap: () => setState(() => _tab = 2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SaaSMetricCard(
                    title: 'Comunicados Recentes',
                    value: '$totalAnnouncements',
                    icon: Icons.campaign_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    subtitle: 'Mural do condomínio',
                    onTap: () => setState(() => _tab = 7),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SaaSMetricCard(
                    title: 'Taxa Condominial',
                    value: hasOverdueInvoices ? 'Pendente' : 'Em dia',
                    icon: Icons.receipt_long_outlined,
                    iconColor: hasOverdueInvoices
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    subtitle: hasOverdueInvoices
                        ? 'Boleto em aberto'
                        : 'Sem pendências',
                    onTap: _openPaymentDialog,
                  ),
                ),
              ],
            ),
            if (pendingPkgs > 0 || totalAnnouncements > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          if (pendingPkgs > 0) '📦 Você tem $pendingPkgs encomenda(s) aguardando retirada na portaria',
                          if (totalAnnouncements > 0) '📢 $totalAnnouncements novo(s) comunicado(s) no condomínio',
                        ].join('   •   '),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    if (pendingPkgs > 0)
                      TextButton(
                        onPressed: () => setState(() => _tab = 1),
                        child: const Text('Ver encomendas'),
                      )
                    else
                      TextButton(
                        onPressed: () => setState(() => _tab = 6),
                        child: const Text('Ver comunicados'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 3-Column main area filling 100% height (Left: Comunicados, Middle: Unidade/Ações/Boletos, Right: Reservas)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Comunicados recentes
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildRecentAnnouncementsSection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Middle Column: Unit Card, Atalhos rápidos, Boletos
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Minha unidade',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _tab = 4),
                              child: const Text('Ver perfil'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildUnitCard(),
                        const SizedBox(height: 14),
                        _buildQuickActionShortcuts(),
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildPendingBoletoSection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right Column: Próximas reservas & Contrapropostas
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildUpcomingReservationsSection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // UNIT CARD
  // ----------------------------------------------------
  Widget _buildUnitCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final condoImg = _condominium?['imageUrl'] as String?;
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: (condoImg != null && condoImg.isNotEmpty)
                  ? (condoImg.startsWith('data:')
                      ? Image.memory(
                          base64Decode(condoImg.split(',').last),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.apartment_rounded, color: Color(0xFF3B82F6), size: 28),
                        )
                      : Image.network(
                          condoImg,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.apartment_rounded, color: Color(0xFF3B82F6), size: 28),
                        ))
                  : const Icon(Icons.apartment_rounded, color: Color(0xFF3B82F6), size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _unitDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sectorDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => setState(() => _tab = 4),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Meus dados',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ATALHOS RÁPIDOS (6 PASTEL SQUARES ROBUSTOS)
  // ----------------------------------------------------
  Widget _buildQuickActionShortcuts() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            'Ações Rápidas do Condomínio',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _quickActionItem(
                title: 'Boletos / PIX',
                icon: Icons.qr_code_2_rounded,
                bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F8F0),
                iconColor: const Color(0xFF10B981),
                onTap: _openPaymentDialog,
              ),
              const SizedBox(width: 8),
              _quickActionItem(
                title: 'Reservas',
                icon: Icons.event_available_rounded,
                bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3E2),
                iconColor: const Color(0xFFF59E0B),
                onTap: () => setState(() => _tab = 2),
              ),
              const SizedBox(width: 8),
              _quickActionItem(
                title: 'Encomendas',
                icon: Icons.inventory_2_outlined,
                bgColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                onTap: () => setState(() => _tab = 1),
              ),
              const SizedBox(width: 8),
              _quickActionItem(
                title: 'Portaria / Chat',
                icon: Icons.chat_bubble_outline_rounded,
                bgColor: isDark ? const Color(0xFF164E63) : const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF06B6D4),
                onTap: () => setState(() => _tab = 3),
              ),
              const SizedBox(width: 8),
              _quickActionItem(
                title: 'Comunidade',
                icon: Icons.diversity_3_outlined,
                bgColor: isDark ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF8B5CF6),
                onTap: () => setState(() => _tab = 6),
              ),
              const SizedBox(width: 8),
              _quickActionItem(
                title: 'Emergência',
                icon: Icons.local_hospital_outlined,
                bgColor: isDark ? const Color(0xFF831843) : const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFE11D48),
                onTap: _showEmergencyContactsDialog,
              ),
            ],
          ),
        ),
      ),
    ],
  );
  }

  void _showEmergencyContactsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFFFE4E6),
              child: Icon(Icons.emergency_rounded, color: Color(0xFFBE123C)),
            ),
            SizedBox(width: 12),
            Text('Contatos de Emergência'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home_work_outlined, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_unitDisplay • $_sectorDisplay\n${_text(_condominium?['name'], 'Condomínio Âncora')}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _emergencyContactTile('Portaria 24h', '(21) 3333-1000 / Ramal 94', Icons.shield_outlined, const Color(0xFF2563EB)),
              _emergencyContactTile('Bombeiros', '193', Icons.local_fire_department_outlined, const Color(0xFFDC2626)),
              _emergencyContactTile('Polícia Militar', '190', Icons.local_police_outlined, const Color(0xFF1E3A8A)),
              _emergencyContactTile('SAMU (Ambulância)', '192', Icons.medical_services_outlined, const Color(0xFF059669)),
              _emergencyContactTile('Zeladoria / Emergência Predial', '(21) 98888-2020', Icons.build_outlined, const Color(0xFFD97706)),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _emergencyContactTile(String title, String phone, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(phone, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
        trailing: IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          tooltip: 'Copiar número',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phone));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Número $phone copiado!'), backgroundColor: color),
            );
          },
        ),
      ),
    );
  }

  Widget _quickActionItem({
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // BOLETOS EM ABERTO
  // ----------------------------------------------------
  Widget _buildPendingBoletoSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingInvoices = _invoices.where((i) => i['status'] != 'PAID').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Taxas & Boletos',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: _openPaymentDialog,
              child: const Text('Histórico'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (pendingInvoices.isEmpty)
          InkWell(
            onTap: _openPaymentDialog,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDCFCE7),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tudo em dia!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nenhum boleto em aberto para a sua unidade.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          )
        else
          ...pendingInvoices.take(1).map((invoice) {
            final isOverdue = invoice['status'] == 'OVERDUE';
            final amountVal = (invoice['amount'] as num?)?.toDouble() ?? 0.00;

            return InkWell(
              onTap: () => _paySingleBoleto(invoice),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isOverdue ? const Color(0xFFFCA5A5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2))
                            : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice['title']?.toString() ?? 'Taxa de Condomínio',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Vencimento: ${_formatDueDate(invoice['dueDate'])}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R\$ ${amountVal.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOverdue ? 'Vencido' : 'Em aberto',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: const Size(0, 32),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF),
                            foregroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _paySingleBoleto(invoice),
                          child: const Text('Pagar agora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatDueDate(dynamic raw) {
    if (raw == null) return '10/08/2026';
    return formatDate(raw);
  }

  Future<void> _paySingleBoleto(Map<String, dynamic> invoice) async {
    final condoId = _condominium?['id'] ?? 1;
    final unitId = _memberships.isNotEmpty ? (_memberships.first['unitId'] ?? 1) : 1;

    await showDialog<void>(
      context: context,
      builder: (ctx) => BoletoPaymentDialog(
        condominiumId: condoId,
        unitId: unitId,
        unitLabel: _unitDisplay,
        title: invoice['title']?.toString() ?? 'Taxa de Condomínio',
        amount: (invoice['amount'] as num?)?.toDouble() ?? 450.00,
        dueDate: _formatDueDate(invoice['dueDate']),
        digitableLine: invoice['digitableLine']?.toString() ?? '34191.79001 01043.510047 91020.150008 8 98010000045000',
        status: invoice['status']?.toString() ?? 'PENDING',
        api: _communityApi,
        onPaid: () {
          setState(() {
            invoice['status'] = 'PAID';
          });
          _load();
        },
      ),
    );
  }

  // ----------------------------------------------------
  // COMUNICADOS RECENTES (THEMATIC PASTEL ICONS)
  // ----------------------------------------------------
  Widget _buildRecentAnnouncementsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comunicados recentes',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _tab = 7),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_announcements.isEmpty)
          InkWell(
            onTap: () => setState(() => _tab = 7),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.campaign_outlined, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Nenhum comunicado recente publicado para o condomínio.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._announcements.take(2).map((a) {
            final title = a['title']?.toString() ?? 'Comunicado';
            final content = a['content']?.toString() ?? '';
            final dateStr = _formatDate(a['createdAt']);
            final isSustainability = title.toLowerCase().contains('sustentab') || title.toLowerCase().contains('recicl');
            final iconBg = isSustainability
                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F8F0))
                : (isDark ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF));
            final iconColor = isSustainability ? const Color(0xFF10B981) : const Color(0xFF8B5CF6);
            final iconData = isSustainability ? Icons.eco_rounded : Icons.campaign_rounded;

            return InkWell(
              onTap: () => setState(() => _tab = 7),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 84,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(iconData, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ----------------------------------------------------
  // PRÓXIMAS RESERVAS & CONTRAPROPOSTAS
  // ----------------------------------------------------
  Widget _buildUpcomingReservationsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final counterProposals = _reservations.where((r) => r['status'] == 'COUNTER_PROPOSED').toList();
    final scheduledReservations = _reservations.where((r) {
      final s = (r['status']?.toString() ?? '').toUpperCase();
      if (s == 'CANCELLED' || s == 'REJECTED' || s == 'DENIED') return false;
      final end = DateTime.tryParse(r['endAt']?.toString() ?? '');
      return end == null || end.isAfter(DateTime.now());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Próximas reservas',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _tab = 2),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (counterProposals.isNotEmpty) ...[
          ...counterProposals.map((cp) => _buildCounterProposalCard(cp, isDark)),
          const SizedBox(height: 10),
        ],

        if (scheduledReservations.isEmpty)
          InkWell(
            onTap: _createReservation,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.deck_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Nenhuma reserva agendada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Toque para agendar salão ou área comum.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          )
        else
          ...scheduledReservations.take(1).map((res) {
            final status = (res['status']?.toString() ?? 'PENDING').toUpperCase();
            final isApproved = status == 'APPROVED' || status == 'CONFIRMED';
            final statusLabel = isApproved ? 'Confirmada' : (status == 'PENDING' ? 'Aguardando' : _text(status));
            final badgeBg = isApproved
                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDBEAFE));
            final badgeFg = isApproved ? const Color(0xFF15803D) : const Color(0xFF1D4ED8);
            final imgUrl = (res['imageUrl'] ?? res['commonAreaImageUrl'])?.toString();

            return InkWell(
              onTap: () => setState(() => _tab = 2),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 84,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: (imgUrl != null && imgUrl.isNotEmpty)
                            ? (imgUrl.startsWith('data:')
                                ? Image.memory(
                                    base64Decode(imgUrl.split(',').last),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.deck_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 26,
                                    ),
                                  )
                                : Image.network(
                                    imgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.deck_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 26,
                                    ),
                                  ))
                            : const Icon(
                                Icons.deck_rounded,
                                color: Color(0xFF3B82F6),
                                size: 26,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            res['commonAreaName']?.toString() ?? 'Área Comum',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatReservationDateTime(res),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

      ],
    );
  }

  Widget _buildCounterProposalCard(Map<String, dynamic> r, bool isDark) {
    final areaName = r['commonAreaName'] ?? 'Espaço Comum';
    final start = _formatDate(r['startAt']);
    final end = _formatDate(r['endAt']);
    final notes = r['notes'] ?? 'Portaria sugeriu alteração de horário.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Contraproposta da Portaria: $areaName',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Novo horário sugerido: De $start até $end',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (notes.toString().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Observação: $notes', style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                  onPressed: () => _acceptCounterProposal(r['id'] as num),
                  child: const Text('Aceitar Proposta'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFF87171)),
                  ),
                  onPressed: () => _declineCounterProposal(r['id'] as num),
                  child: const Text('Recusar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatReservationDateTime(Map<String, dynamic> r) {
    final start = r['startAt'];
    final end = r['endAt'];
    if (start == null) return '20/08/2026\n14:00 - 18:00';
    try {
      final s = parseUtcToLocal(start);
      if (s == null) return '20/08/2026\n14:00 - 18:00';
      final e = end != null ? parseUtcToLocal(end) : s.add(const Duration(hours: 4));
      final dateStr = DateFormat('dd/MM/yyyy').format(s);
      final sTime = DateFormat('HH:mm').format(s);
      final eTime = e != null ? DateFormat('HH:mm').format(e) : '';
      return '$dateStr\n$sTime - $eTime';
    } catch (_) {
      return '20/08/2026\n14:00 - 18:00';
    }
  }

  Future<void> _acceptCounterProposal(num id) async {
    try {
      await _communityApi.acceptCounterProposal(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraproposta aceita! Sua reserva está confirmada.'), backgroundColor: Color(0xFF15803D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _declineCounterProposal(num id) async {
    try {
      await _communityApi.declineCounterProposal(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraproposta recusada.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _cancelReservation(num id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação?'),
        content: const Text('Deseja realmente cancelar esta solicitação de reserva? O horário voltará a ficar disponível para outros moradores.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar Reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _communityApi.rejectReservation(id, 'Cancelado pelo morador');
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação de reserva cancelada com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cancelar: $e')));
    }
  }

  bool _hasFeature(String code) {
    if (_condominium == null) return true;
    final f = _condominium!['features'];
    if (f is List && f.isNotEmpty) {
      return f.map((e) => e.toString().toUpperCase()).contains(code.toUpperCase());
    }
    return true;
  }

  void _showPackageQrDialog(Map<String, dynamic> pkg) {
    final pin = pkg['pickupPin']?.toString() ?? pkg['id'].toString().padLeft(6, '0');
    final desc = pkg['description'] ?? 'Encomenda';
    final tracking = pkg['trackingCode']?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Retirada Rápida', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  Text('Apresente este código na portaria', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), textAlign: TextAlign.center),
              if (tracking != null && tracking.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Rastreio: $tracking', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
              const SizedBox(height: 16),
              Container(
                width: 170,
                height: 170,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                      ),
                      itemCount: 49,
                      itemBuilder: (context, idx) {
                        final isCorner = (idx < 3 && idx % 7 < 3) ||
                            (idx % 7 > 3 && idx < 3) ||
                            (idx >= 42 && idx % 7 < 3);
                        final isPattern = idx % 2 == 0 || idx % 3 == 0 || isCorner;
                        return Container(
                          decoration: BoxDecoration(
                            color: isPattern ? const Color(0xFF1E293B) : Colors.transparent,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, size: 24, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('CÓDIGO PIN DE RETIRADA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pin,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 4,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copiar PIN',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: pin));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN copiado para a área de transferência!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          if (pkg['status'] == 'RECEIVED' || pkg['status'] == 'NOTIFIED')
            FilledButton.icon(
              icon: const Icon(Icons.hail_rounded, size: 16),
              label: const Text('Avisar Portaria'),
              onPressed: () {
                Navigator.pop(ctx);
                _requestPickup(pkg['id']);
              },
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SUB-PAGES (ENCOMENDAS, RESERVAS, COMUNICADOS)
  // SPACES ARE ROOMY AS REQUIRED BY USER RULE
  // ----------------------------------------------------
  Widget _packagesPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Suas encomendas', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    const Text('Acompanhe o recebimento e retirada das entregas da sua unidade.'),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openExpectedPackageDialog,
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Avisar Encomenda'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          EnterSearchField(
            hintText: 'Pesquisar encomendas (Enter)',
            onSubmitted: (query) => setState(() => _packageQuery = query),
          ),
          const SizedBox(height: 12),
          if (_packages.where((e) => recordMatchesQuery(e, _packageQuery)).isEmpty)
            _empty('Nenhuma encomenda encontrada.', Icons.inventory_2_outlined)
          else
            ..._packages.where((e) => recordMatchesQuery(e, _packageQuery)).map((e) {
              final isWaitingPickup = e['status'] == 'RECEIVED' || e['status'] == 'NOTIFIED';
              final pin = e['pickupPin']?.toString() ?? e['id'].toString().padLeft(6, '0');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: isWaitingPickup ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: isWaitingPickup ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_text(e['description'], 'Encomenda'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text('Recebida em: ${_formatDate(e['receivedAt'])}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                if (e['trackingCode'] != null && e['trackingCode'].toString().isNotEmpty)
                                  Text('Rastreio: ${e['trackingCode']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isWaitingPickup ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isWaitingPickup ? 'Disponível' : _text(e['status']),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isWaitingPickup ? const Color(0xFF15803D) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pin_rounded, size: 14, color: Color(0xFF4338CA)),
                                  const SizedBox(width: 4),
                                  Text('PIN: $pin', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF4338CA))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                              label: const Text('QR / PIN', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showPackageQrDialog(e),
                            ),
                            if (isWaitingPickup) ...[
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.hail_rounded, size: 16),
                                label: const Text('Solicitar Retirada', style: TextStyle(fontSize: 12)),
                                onPressed: () => _requestPickup(e['id']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      );

  Widget _reservationsPage() {
    final hasReservationsFeature = _hasFeature('RESERVATIONS');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reservas de áreas comuns', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  const Text('Agende salão de festas, churrasqueira e outros espaços.'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: hasReservationsFeature ? _createReservation : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Módulo de reservas disponível nos planos Profissional ou Premium.')),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova reserva'),
            ),
          ],
        ),
        if (!hasReservationsFeature) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seu condomínio está no plano Básico. O agendamento online de áreas comuns requer o plano Profissional.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Builder(
          builder: (context) {
            final now = DateTime.now();
            bool isCancelled(Map<String, dynamic> r) {
              final s = (r['status']?.toString() ?? '').toUpperCase();
              return s == 'CANCELLED' || s == 'REJECTED' || s == 'DENIED';
            }

            bool isPast(Map<String, dynamic> r) {
              if (isCancelled(r)) return false;
              final end = DateTime.tryParse(r['endAt']?.toString() ?? '');
              return end != null && end.isBefore(now);
            }

            bool isScheduled(Map<String, dynamic> r) {
              return !isCancelled(r) && !isPast(r);
            }

            final scheduled = _reservations.where(isScheduled).toList();
            final past = _reservations.where(isPast).toList();
            final cancelled = _reservations.where(isCancelled).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'SCHEDULED',
                      label: Text('Agendadas (${scheduled.length})'),
                      icon: const Icon(Icons.event_available_rounded),
                    ),
                    ButtonSegment(
                      value: 'PAST',
                      label: Text('Já passaram (${past.length})'),
                      icon: const Icon(Icons.history_rounded),
                    ),
                    ButtonSegment(
                      value: 'CANCELLED',
                      label: Text('Canceladas (${cancelled.length})'),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ],
                  selected: {_reservationFilter},
                  onSelectionChanged: (val) => setState(() => _reservationFilter = val.first),
                ),
                const SizedBox(height: 14),
                EnterSearchField(
                  hintText: 'Pesquisar reservas por área ou data (Enter)',
                  onSubmitted: (query) => setState(() => _reservationQuery = query),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final currentList = switch (_reservationFilter) {
                      'PAST' => past,
                      'CANCELLED' => cancelled,
                      _ => scheduled,
                    };
                    final filtered = currentList
                        .where((e) => recordMatchesQuery(e, _reservationQuery))
                        .toList();

                    if (filtered.isEmpty) {
                      final emptyLabel = switch (_reservationFilter) {
                        'PAST' => 'Nenhuma reserva passada encontrada.',
                        'CANCELLED' => 'Nenhuma reserva cancelada.',
                        _ => 'Você não possui reservas agendadas no momento.',
                      };
                      return _empty(emptyLabel, Icons.event_available_outlined);
                    }

                    return Column(
                      children: filtered.map((e) {
                        final status = e['status']?.toString().toUpperCase() ?? '';
                        final isCounter = status == 'COUNTER_PROPOSED';
                        final isPending = status == 'PENDING';
                        final isWaitlisted = status == 'WAITLISTED';
                        final isApproved = status == 'APPROVED' || status == 'CONFIRMED';
                        final isItemCancelled = isCancelled(e);
                        final notes = e['notes']?.toString();
                        final reason = e['rejectionReason']?.toString();

                        Color badgeBg = const Color(0xFFF1F5F9);
                        Color badgeFg = const Color(0xFF475569);
                        String statusLabel = _text(e['status']);
                        if (isItemCancelled) {
                          badgeBg = const Color(0xFFDC2626);
                          badgeFg = Colors.white;
                          statusLabel = 'CANCELADA';
                        } else if (isCounter) {
                          badgeBg = const Color(0xFFFEF3C7);
                          badgeFg = const Color(0xFFB45309);
                          statusLabel = 'Contraproposta';
                        } else if (isWaitlisted) {
                          badgeBg = const Color(0xFFF3E8FF);
                          badgeFg = const Color(0xFF6D28D9);
                          statusLabel = 'Lista de Espera (#${e['waitlistPosition'] ?? 1})';
                        } else if (isPending) {
                          badgeBg = const Color(0xFFDBEAFE);
                          badgeFg = const Color(0xFF1D4ED8);
                          statusLabel = 'Aguardando Aprovação';
                        } else if (isApproved) {
                          badgeBg = const Color(0xFFDCFCE7);
                          badgeFg = const Color(0xFF15803D);
                          statusLabel = 'Confirmada';
                        } else {
                          badgeBg = const Color(0xFFF1F5F9);
                          badgeFg = const Color(0xFF475569);
                          statusLabel = 'Concluída';
                        }

                        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isItemCancelled
                              ? (isDarkTheme ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFEF2F2))
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isItemCancelled
                                  ? const Color(0xFFFCA5A5)
                                  : (isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: isItemCancelled ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: (e['imageUrl'] != null && e['imageUrl'].toString().isNotEmpty)
                                            ? (e['imageUrl'].toString().startsWith('data:')
                                                ? Image.memory(
                                                    base64Decode(e['imageUrl'].toString().split(',').last),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => CircleAvatar(
                                                      backgroundColor: isItemCancelled ? const Color(0xFFFEE2E2) : badgeBg,
                                                      child: Icon(
                                                        isItemCancelled
                                                            ? Icons.cancel_rounded
                                                            : (isCounter
                                                                ? Icons.swap_horiz_rounded
                                                                : (isApproved
                                                                    ? Icons.check_circle_outline_rounded
                                                                    : Icons.event_available_outlined)),
                                                        color: isItemCancelled ? const Color(0xFFDC2626) : badgeFg,
                                                      ),
                                                    ),
                                                  )
                                                : Image.network(
                                                    e['imageUrl'].toString(),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => CircleAvatar(
                                                      backgroundColor: isItemCancelled ? const Color(0xFFFEE2E2) : badgeBg,
                                                      child: Icon(
                                                        isItemCancelled
                                                            ? Icons.cancel_rounded
                                                            : (isCounter
                                                                ? Icons.swap_horiz_rounded
                                                                : (isApproved
                                                                    ? Icons.check_circle_outline_rounded
                                                                    : Icons.event_available_outlined)),
                                                        color: isItemCancelled ? const Color(0xFFDC2626) : badgeFg,
                                                      ),
                                                    ),
                                                  ))
                                            : CircleAvatar(
                                                backgroundColor: isItemCancelled ? const Color(0xFFFEE2E2) : badgeBg,
                                                child: Icon(
                                                  isItemCancelled
                                                      ? Icons.cancel_rounded
                                                      : (isCounter
                                                          ? Icons.swap_horiz_rounded
                                                          : (isApproved
                                                              ? Icons.check_circle_outline_rounded
                                                              : Icons.event_available_outlined)),
                                                  color: isItemCancelled ? const Color(0xFFDC2626) : badgeFg,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _text(e['commonAreaName']),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isItemCancelled ? const Color(0xFF991B1B) : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Período: ${_formatDate(e['startAt'])} até ${_formatDate(e['endAt'])}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isItemCancelled) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDarkTheme ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.highlight_off_rounded, size: 16, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            reason != null && reason.isNotEmpty
                                                ? 'Motivo: $reason'
                                                : 'Esta reserva foi cancelada e o espaço foi liberado para novos agendamentos.',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (isCounter && notes != null && notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text('Proposta da portaria: $notes', style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (!isItemCancelled && (isCounter || isPending || isWaitlisted)) ...[
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                            if (isCounter) ...[
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Aceitar Proposta', style: TextStyle(fontSize: 12)),
                                onPressed: () => _acceptCounterProposal(e['id'] as num),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFF87171)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Recusar', style: TextStyle(fontSize: 12)),
                                onPressed: () => _declineCounterProposal(e['id'] as num),
                              ),
                            ] else if (isPending || isWaitlisted) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: Text(isWaitlisted ? 'Sair da Fila de Espera' : 'Cancelar Solicitação', style: const TextStyle(fontSize: 12)),
                                onPressed: () => _cancelReservation(e['id'] as num),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  ],
);
},
),
],
);
}

  Widget _announcementsPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mural de comunicados', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Avisos oficiais publicados pela administração do seu condomínio.'),
          const SizedBox(height: 14),
          EnterSearchField(
            hintText: 'Pesquisar comunicados (Enter)',
            onSubmitted: (query) => setState(() => _announcementQuery = query),
          ),
          const SizedBox(height: 12),
          if (_announcements.where((e) => recordMatchesQuery(e, _announcementQuery)).isEmpty)
            _empty('Nenhum comunicado ativo no momento.', Icons.campaign_outlined)
          else
            ..._announcements.where((e) => recordMatchesQuery(e, _announcementQuery)).map((e) {
              final isRead = e['readByCurrentUser'] == true;
              final readCount = e['readCount'] ?? 0;
              final targetDesc = e['targetDescription']?.toString() ?? 'Todo o condomínio';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFEF3C7),
                            child: Icon(Icons.campaign_outlined, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_text(e['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                Text('${_formatDate(e['createdAt'])} • Público: $targetDesc', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRead ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRead ? 'Lido' : 'Novo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isRead ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_text(e['content'])),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$readCount confirmação(ões) de leitura',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          if (!isRead && e['id'] != null)
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.done_all_rounded, size: 16),
                              label: const Text('Confirmar leitura', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                try {
                                  await _communityApi.markAnnouncementAsRead(e['id'] as num);
                                  await _refreshAnnouncements();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Leitura confirmada com sucesso!')),
                                    );
                                  }
                                } catch (err) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro: $err')),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      );

  Widget _empty(String message, IconData icon) => SaaSEmptyState(
        icon: icon,
        title: message,
      );

  Widget _errorPanel() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SaaSErrorState(
            message: _error!,
            onRetry: _load,
          ),
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
                      child: Icon(Icons.apartment_rounded, size: 38, color: Color(0xFF2F3FB0)),
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

  Future<void> _openAssistantModal() async {
    final condoId = (_condominium?['id'] as num?)?.toInt() ??
        (_memberships.isNotEmpty ? (_memberships.first['condominiumId'] as num?)?.toInt() : null);
    if (condoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ou vincule-se a um condomínio para usar o Assistente.')),
      );
      return;
    }

    final questionCtrl = TextEditingController();
    Map<String, dynamic>? assistantResponse;
    bool asking = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 650),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assistente Inteligente do Condomínio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          Text('Tire dúvidas sobre regimento interno, barulho, mudanças, pets e assembleias', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: questionCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Pergunte sobre regras, horários, multas...',
                          isDense: true,
                        ),
                        onSubmitted: (q) async {
                          if (q.trim().isEmpty) return;
                          setModalState(() => asking = true);
                          try {
                            final res = await _communityApi.askAssistant(condoId, q.trim());
                            setModalState(() { assistantResponse = res; asking = false; });
                          } catch (e) {
                            setModalState(() => asking = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                      onPressed: asking ? null : () async {
                        final q = questionCtrl.text.trim();
                        if (q.isEmpty) return;
                        setModalState(() => asking = true);
                        try {
                          final res = await _communityApi.askAssistant(condoId, q);
                          setModalState(() { assistantResponse = res; asking = false; });
                        } catch (e) {
                          setModalState(() => asking = false);
                        }
                      },
                      child: asking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Consultar'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (assistantResponse != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology_outlined, size: 18, color: Color(0xFF1E3A8A)),
                                SizedBox(width: 6),
                                Text('Orientação das Normas Condominiais:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              assistantResponse!['answer'] ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF1E293B)),
                            ),
                            if (assistantResponse!['legalBasis'] != null) ...[
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.gavel_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Base normativa: ${assistantResponse!['legalBasis']}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (assistantResponse!['suggestedFollowUps'] is List) ...[
                              const SizedBox(height: 12),
                              const Text('Perguntas frequentes:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (assistantResponse!['suggestedFollowUps'] as List).map((f) => ActionChip(
                                  label: Text(f.toString(), style: const TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    questionCtrl.text = f.toString();
                                  },
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.volume_off_outlined, size: 16),
                        label: const Text('Horário de Silêncio'),
                        onPressed: () => questionCtrl.text = 'Qual o horário de silêncio e multas por barulho?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                        label: const Text('Regras de Mudança'),
                        onPressed: () => questionCtrl.text = 'Quais os horários permitidos e regras para mudanças?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.pets_outlined, size: 16),
                        label: const Text('Animais de Estimação (Pets)'),
                        onPressed: () => questionCtrl.text = 'Quais as regras e direitos para animais de estimação?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.construction_outlined, size: 16),
                        label: const Text('Reformas & Obras'),
                        onPressed: () => questionCtrl.text = 'O que é exigido para reformas e ART nos apartamentos?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.how_to_vote_outlined, size: 16),
                        label: const Text('Votar em Assembleia'),
                        onPressed: () => questionCtrl.text = 'Quem pode votar na assembleia do condomínio?',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          api: _api,
          condominiumId: (_condominium?['id'] as num?)?.toInt(),
          onInvitationChanged: _load,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _showMoreMenus() async {
    final entries = <(String, String, IconData, String)>[
      ('Áreas Comuns', '/condominiums/{id}/common-areas', Icons.deck_outlined, 'Espaços de lazer e agendamentos'),
      ('Galeria de Fotos', 'gallery', Icons.photo_library_outlined, 'Fotos das áreas do condomínio'),
      ('Chat com a Portaria', 'chat', Icons.chat_bubble_outline_rounded, 'Conversa em tempo real com a portaria'),
      ('Planos e Serviços', '/billing/plans?page=0&size=50', Icons.receipt_long_outlined, 'Planos do condomínio'),
    ];

    final selected = await showModalBottomSheet<(String, String, IconData, String)>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Serviços do Condomínio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                subtitle: Text('Selecione uma área para navegar'),
              ),
              const Divider(height: 1),
              ...entries.map(
                (entry) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8ECFF),
                    child: Icon(entry.$3, color: const Color(0xFF2F3FB0)),
                  ),
                  title: Text(entry.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(entry.$4),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, entry),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    if (selected.$2 == 'gallery') {
      setState(() => _tab = 5);
    } else if (selected.$2 == 'chat') {
      setState(() => _tab = 3);
    }
  }

  Future<void> _createReservation() async {
    if (_condominium == null) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => CommonAreaBookingDialog(
        api: _communityApi,
        condominiumId: _condominium!['id'],
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openJoinCondominiumDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => JoinCondominiumDialog(api: _communityApi),
    );
    if (sent == true) _load();
  }

  Future<void> _openPaymentDialog() async {
    if (_condominium == null) return;
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma fatura ou boleto registrado para a sua unidade no momento.'),
        ),
      );
      return;
    }
    final targetInvoice = _invoices.firstWhere(
      (i) => i['status'] != 'PAID',
      orElse: () => _invoices.first,
    );
    await _paySingleBoleto(targetInvoice);
  }

  Future<void> _openExpectedPackageDialog() async {
    if (_condominium == null) return;
    final desc = TextEditingController();
    final tracking = TextEditingController();
    final sender = TextEditingController();

    final unitId = _memberships.isNotEmpty ? (_memberships.first['unitId'] as num?)?.toInt() : null;
    if (unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua conta precisa estar vinculada a uma unidade para pré-cadastrar encomenda.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avisar Encomenda Prevista'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cadastre o pacote para a portaria já saber de quem se trata na entrega.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrição do pacote *', hintText: 'Ex: Livros da Amazon')),
              const SizedBox(height: 10),
              TextField(controller: tracking, decoration: const InputDecoration(labelText: 'Código de rastreio (opcional)')),
              const SizedBox(height: 10),
              TextField(controller: sender, decoration: const InputDecoration(labelText: 'Remetente / Transportadora')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar Aviso')),
        ],
      ),
    );

    if (ok == true && desc.text.trim().isNotEmpty) {
      await _communityApi.registerExpectedPackage(
        condoId: _condominium!['id'],
        unitId: unitId,
        description: desc.text.trim(),
        trackingCode: tracking.text.trim().isEmpty ? null : tracking.text.trim(),
        sender: sender.text.trim().isEmpty ? null : sender.text.trim(),
      );
      _load();
    }
  }

  Future<void> _requestPickup(num packageId) async {
    try {
      await _communityApi.requestPackagePickup(packageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portaria avisada que você está a caminho para retirar a encomenda!')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }
}
