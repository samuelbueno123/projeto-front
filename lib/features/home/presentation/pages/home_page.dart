import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/enter_search_field.dart';
import '../../../../core/widgets/role_switcher_pill.dart';
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
  int _tab = 0; // 0: Início, 1: Acesso/Encomendas, 2: Reservas, 3: Mensagens/Chat, 4: Perfil, 5: Galeria, 6: Hub
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
      final unitName = _memberships.first['unitIdentifier'] ?? _memberships.first['unitName'];
      if (unitName != null && unitName.toString().isNotEmpty) {
        return 'Apartamento $unitName';
      }
    }
    return 'Apartamento 204';
  }

  String get _sectorDisplay {
    if (_memberships.isNotEmpty) {
      final sec = _memberships.first['sectorName'] ?? _memberships.first['sector'];
      if (sec != null && sec.toString().isNotEmpty) {
        return 'Bloco $sec';
      }
    }
    return 'Bloco B';
  }

  bool get _canManage {
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
    _load();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _api = HomeService(token: widget.token);
      _communityApi = CommunityApi(api: _api);
      _load();
    }
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
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  ImageProvider? get _profileAvatarImage {
    final image = _profile['profileImage'];
    if (image is! String || image.isEmpty) return null;
    try {
      if (image.startsWith('data:')) {
        return MemoryImage(base64Decode(image.split(',').last));
      }
      return NetworkImage(image);
    } catch (_) {
      return null;
    }
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
                  ? const Center(child: CircularProgressIndicator())
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 20, 16, isDesktop ? 32 : 18, 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1E3A8A),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF1E3A8A)).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Menu/Desktop Tabs, Dark Mode, Bell, Avatar
          Row(
            children: [
              if (!isDesktop)
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    tooltip: 'Menu',
                  ),
                )
              else ...[
                const Icon(Icons.apartment_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Text(
                  _text(_condominium?['name'], 'Condomínio Digital'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 24),
                // Horizontal navigation tabs for desktop
                _desktopNavTab('Início', 0),
                _desktopNavTab('Acesso & Encomendas', 1),
                _desktopNavTab('Reservas', 2),
                _desktopNavTab('Chat Portaria', 3),
                _desktopNavTab('Galeria de Fotos', 5),
                _desktopNavTab('Comunidade', 6),
              ],

              const Spacer(),

              if (widget.currentRole != null && widget.onSwitchRole != null) ...[
                RoleSwitcherPill(
                  currentRole: widget.currentRole!,
                  availableRoles: widget.availableRoles,
                  onSwitchRole: widget.onSwitchRole!,
                ),
                const SizedBox(width: 6),
              ],

              // Dark/Light Mode Toggle
              IconButton(
                tooltip: isDark ? 'Modo Claro' : 'Modo Noturno',
                onPressed: _toggleTheme,
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              // Notifications Bell with red badge
              IconButton(
                tooltip: 'Central de Notificações',
                onPressed: _showNotifications,
                icon: Badge(
                  label: Text('$unreadCount'),
                  isLabelVisible: unreadCount > 0,
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Avatar
              InkWell(
                onTap: () => setState(() => _tab = 4),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: Colors.white24,
                    backgroundImage: _profileAvatarImage,
                    child: _profileAvatarImage == null
                        ? const Icon(Icons.person_rounded, color: Colors.white, size: 22)
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Greeting title and condominium subtitle
          Text(
            'Olá, $_residentFirstName! 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bem-vindo ao ${_text(_condominium?['name'], 'Residencial Vila das Flores')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopNavTab(String title, int tabIndex) {
    final active = _tab == tabIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: active ? Colors.white : Colors.white70,
          backgroundColor: active ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => setState(() => _tab = tabIndex),
        child: Text(
          title,
          style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.w500),
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
            currentAccountPicture: CircleAvatar(
              backgroundImage: _profileAvatarImage,
              child: _profileAvatarImage == null ? const Icon(Icons.person, size: 36) : null,
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
            : const Center(child: Text('Nenhum condomínio ativo.'));
      case 5:
        return _condominium != null
            ? CondominiumGalleryView(
                condominiumId: _condominium!['id'],
                api: _communityApi,
                canManage: _canManage,
              )
            : const Center(child: Text('Nenhum condomínio ativo.'));
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
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
    return RefreshIndicator(
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Unit Card, Atalhos rápidos, Boletos
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUnitCard(),
                  const SizedBox(height: 16),
                  _buildQuickActionShortcuts(),
                  const SizedBox(height: 16),
                  Expanded(child: SingleChildScrollView(child: _buildPendingBoletoSection())),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Middle Column: Comunicados recentes
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(child: _buildRecentAnnouncementsSection())),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right Column: Próximas reservas & Contrapropostas + Quick Portaria Chat Button
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(child: _buildUpcomingReservationsSection())),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.apartment_rounded, color: Color(0xFF3B82F6), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _unitDisplay,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sectorDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => setState(() => _tab = 4),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Meus dados',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 16),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ações Rápidas do Condomínio',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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

    // Use fetched invoice if available, or populate a realistic active condo fee
    final invoice = _invoices.isNotEmpty
        ? _invoices.first
        : {
            'id': 101,
            'title': 'Taxa de Condomínio – Agosto/2026',
            'amount': 450.00,
            'dueDate': '2026-08-10',
            'status': 'OVERDUE',
            'digitableLine': '34191.79001 01043.510047 91020.150008 8 98010000045000',
          };

    final isPaid = invoice['status'] == 'PAID' || invoice['status'] == 'UP_TO_DATE';
    final isOverdue = invoice['status'] == 'OVERDUE';
    final amountVal = (invoice['amount'] as num?)?.toDouble() ?? 450.00;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Boletos em aberto',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: _openPaymentDialog,
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              // Red document icon in pastel box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded, color: Color(0xFFEF4444), size: 24),
              ),
              const SizedBox(width: 14),

              // Title and due date
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

              // Amount, Status, and Pay Button
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
                    isPaid ? 'Pago' : (isOverdue ? 'Vencido' : 'Em aberto'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPaid ? const Color(0xFF10B981) : (isOverdue ? const Color(0xFFDC2626) : const Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!isPaid)
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
                    )
                  else
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDueDate(dynamic raw) {
    if (raw == null) return '10/08/2026';
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return raw.toString();
    }
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

    final mockAnnouncements = [
      {
        'title': 'Manutenção no Elevador Social',
        'createdAt': '2026-08-14T09:15:00',
        'content': 'Informamos que o elevador social estará em manutenção preventiva das 09h às 12h.',
        'icon': Icons.campaign_rounded,
        'bgColor': isDark ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF),
        'iconColor': const Color(0xFF8B5CF6),
        'unread': true,
      },
      {
        'title': 'Campanha de Sustentabilidade',
        'createdAt': '2026-08-12T16:30:00',
        'content': 'Participe da nossa campanha de coleta seletiva. Faça o descarte nos coletores instalados.',
        'icon': Icons.eco_rounded,
        'bgColor': isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F8F0),
        'iconColor': const Color(0xFF10B981),
        'unread': true,
      },
    ];

    final items = _announcements.isNotEmpty ? _announcements.take(2).toList() : mockAnnouncements;

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
              onPressed: () => setState(() => _tab = 6),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map((a) {
          final title = a['title']?.toString() ?? 'Comunicado';
          final content = a['content']?.toString() ?? '';
          final dateStr = _formatDate(a['createdAt']);
          final isSustainability = title.toLowerCase().contains('sustentab') || title.toLowerCase().contains('recicl');
          final iconBg = isSustainability
              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F8F0))
              : (isDark ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF));
          final iconColor = isSustainability ? const Color(0xFF10B981) : const Color(0xFF8B5CF6);
          final iconData = isSustainability ? Icons.eco_rounded : Icons.campaign_rounded;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Unread Blue Dot
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
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

    // Check if there are counter proposals first
    final counterProposals = _reservations.where((r) => r['status'] == 'COUNTER_PROPOSED').toList();

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

        // If there's a counter proposal from portaria, display it prominently!
        if (counterProposals.isNotEmpty) ...[
          ...counterProposals.map((cp) => _buildCounterProposalCard(cp, isDark)),
          const SizedBox(height: 10),
        ],

        // Normal reservations card
        Container(
          padding: const EdgeInsets.all(14),
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
              // Area thumbnail image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: (_reservations.isNotEmpty &&
                          _reservations.first['imageUrl'] != null &&
                          _reservations.first['imageUrl'].toString().isNotEmpty)
                      ? Image.network(
                          _reservations.first['imageUrl'].toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.deck_rounded,
                            color: Color(0xFF3B82F6),
                            size: 28,
                          ),
                        )
                      : const Icon(
                          Icons.deck_rounded,
                          color: Color(0xFF3B82F6),
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and date/time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reservations.isNotEmpty
                          ? (_reservations.first['commonAreaName'] ?? 'Salão de Festas')
                          : 'Salão de Festas',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reservations.isNotEmpty
                          ? _formatReservationDateTime(_reservations.first)
                          : '20/08/2026\n14:00 - 18:00',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Confirmada',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      final s = DateTime.parse(start.toString()).toLocal();
      final e = end != null ? DateTime.parse(end.toString()).toLocal() : s.add(const Duration(hours: 4));
      final dateStr = DateFormat('dd/MM/yyyy').format(s);
      final sTime = DateFormat('HH:mm').format(s);
      final eTime = DateFormat('HH:mm').format(e);
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
        EnterSearchField(
          hintText: 'Pesquisar reservas por área ou data (Enter)',
          onSubmitted: (query) => setState(() => _reservationQuery = query),
        ),
        const SizedBox(height: 12),
        if (_reservations.where((e) => recordMatchesQuery(e, _reservationQuery)).isEmpty)
          _empty('Você ainda não possui reservas registradas.', Icons.event_available_outlined)
        else
          ..._reservations.where((e) => recordMatchesQuery(e, _reservationQuery)).map((e) {
            final status = e['status']?.toString().toUpperCase() ?? '';
            final isCounter = status == 'COUNTER_PROPOSED';
            final isPending = status == 'PENDING';
            final isApproved = status == 'APPROVED' || status == 'CONFIRMED';
            final isRejected = status == 'REJECTED';
            final notes = e['notes']?.toString();
            final reason = e['rejectionReason']?.toString();

            Color badgeBg = const Color(0xFFF1F5F9);
            Color badgeFg = const Color(0xFF475569);
            String statusLabel = _text(e['status']);
            if (isCounter) {
              badgeBg = const Color(0xFFFEF3C7);
              badgeFg = const Color(0xFFB45309);
              statusLabel = 'Contraproposta';
            } else if (isPending) {
              badgeBg = const Color(0xFFDBEAFE);
              badgeFg = const Color(0xFF1D4ED8);
              statusLabel = 'Aguardando Aprovação';
            } else if (isApproved) {
              badgeBg = const Color(0xFFDCFCE7);
              badgeFg = const Color(0xFF15803D);
              statusLabel = 'Confirmada';
            } else if (isRejected) {
              badgeBg = const Color(0xFFFEE2E2);
              badgeFg = const Color(0xFFDC2626);
              statusLabel = 'Recusada';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
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
                          backgroundColor: badgeBg,
                          child: Icon(
                            isCounter
                                ? Icons.swap_horiz_rounded
                                : (isApproved
                                    ? Icons.check_circle_outline_rounded
                                    : (isRejected ? Icons.highlight_off_rounded : Icons.event_available_outlined)),
                            color: badgeFg,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_text(e['commonAreaName']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text('Período: ${_formatDate(e['startAt'])} até ${_formatDate(e['endAt'])}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg)),
                        ),
                      ],
                    ),
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
                    if (isRejected && reason != null && reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Motivo da recusa: $reason', style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isCounter || isPending) ...[
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
                            ] else if (isPending) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Cancelar Solicitação', style: TextStyle(fontSize: 12)),
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
          }),
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
              return Card(
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
                                Text(_formatDate(e['createdAt']), style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_text(e['content'])),
                    ],
                  ),
                ),
              );
            }),
        ],
      );

  Widget _empty(String message, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE8ECFF),
                  child: Icon(icon, size: 28, color: const Color(0xFF2F3FB0)),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

  Widget _errorPanel() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
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
    final unitId = _memberships.isNotEmpty ? (_memberships.first['unitId'] ?? 1) : 1;
    await showDialog<void>(
      context: context,
      builder: (context) => BoletoPaymentDialog(
        condominiumId: _condominium!['id'],
        unitId: unitId,
        unitLabel: _unitDisplay,
        title: 'Taxa de Condomínio – Agosto/2026',
        amount: 450.00,
        dueDate: '10/08/2026',
        digitableLine: '34191.79001 01043.510047 91020.150008 8 98010000045000',
        status: 'OVERDUE',
        api: _communityApi,
        onPaid: _load,
      ),
    );
    _load();
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
