import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/home_service.dart';
import '../../../admin/presentation/admin_page.dart';
import '../../../auth/presentation/pages/user_profile_page.dart';
import '../../../community/data/community_api.dart';
import '../../../community/presentation/dialogs/common_area_booking_dialog.dart';
import '../../../community/presentation/dialogs/join_condominium_dialog.dart';
import '../../../community/presentation/dialogs/unit_payment_confirmation_dialog.dart';
import '../../../community/presentation/views/community_hub_view.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/enter_search_field.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
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

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeService _api;
  late CommunityApi _communityApi;
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _memberships = [];
  Map<String, dynamic>? _condominium;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _notifications = [];
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
    return 'morador';
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
      Map<String, dynamic>? condominium;
      List<Map<String, dynamic>> announcements = [],
          packages = [],
          reservations = [];
      if (memberships.isNotEmpty) {
        final id = memberships.first['condominiumId'];
        condominium = _map(await _api.get('/condominiums/$id'));
        final results = await Future.wait([
          _safeGet('/condominiums/$id/announcements'),
          _safeGet('/packages/my?page=0&size=20'),
          _safeGet('/condominiums/$id/reservations/my'),
        ]);
        announcements = _list(results[0]);
        packages = _list(results[1]);
        reservations = _list(results[2]);
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

  (String, Color, Color) _packageStatusStyle(dynamic status) =>
      switch (status) {
        'EXPECTED' => (
          'Aguardando chegada',
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
        ),
        'RECEIVED' => (
          'Na portaria',
          const Color(0xFFDBEAFE),
          const Color(0xFF1D4ED8),
        ),
        'NOTIFIED' => (
          'Pronta para retirada',
          const Color(0xFFE0E7FF),
          const Color(0xFF2F3FB0),
        ),
        'PICKED_UP' || 'DELIVERED' => (
          'Entregue',
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
        ),
        'RETURNED' => (
          'Devolvida',
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C),
        ),
        'CANCELLED' => (
          'Cancelada',
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
        ),
        _ => (
          _text(status, 'Registrada'),
          const Color(0xFFF1F5F9),
          const Color(0xFF334155),
        ),
      };

  (String, Color, Color) _reservationStatusStyle(dynamic status) =>
      switch (status) {
        'CONFIRMED' => (
          'Confirmada',
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
        ),
        'PENDING' => (
          'Aguardando aprovação do síndico',
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
        ),
        'REJECTED' => (
          'Recusada',
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
        ),
        'CANCELLED' => (
          'Cancelada',
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
        ),
        _ => (
          _text(status, 'Agendada'),
          const Color(0xFFF1F5F9),
          const Color(0xFF334155),
        ),
      };

  @override
  Widget build(BuildContext context) {
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

    final unreadCount = _notifications.where((e) => e['read'] != true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF243296), Color(0xFF3E51D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x222F3FB0),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, $_residentFirstName! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.apartment_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _text(
                                  _condominium?['name'],
                                  widget.userEmail ?? 'Bem-vindo ao app',
                                ),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_memberships.isNotEmpty)
                    IconButton(
                      tooltip: 'Mais serviços do condomínio',
                      onPressed: _showMoreMenus,
                      icon: const Icon(
                        Icons.grid_view_rounded,
                        color: Colors.white,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Central de notificações',
                    onPressed: _showNotifications,
                    icon: Badge(
                      label: Text('$unreadCount'),
                      isLabelVisible: unreadCount > 0,
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _tab = 4),
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.white24,
                      backgroundImage: _profileAvatarImage,
                      child: _profileAvatarImage == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 21,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _errorPanel()
                  : _memberships.isEmpty && _tab != 4
                  ? _noCondominiumNotice()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 840),
                          child: ListView(
                            padding: const EdgeInsets.all(18),
                            children: [_pageContent()],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _memberships.isEmpty ? (_tab == 4 ? 1 : 0) : _tab,
        onDestinationSelected: (value) => setState(
          () => _tab = _memberships.isEmpty ? (value == 1 ? 4 : 0) : value,
        ),
        destinations: _memberships.isEmpty
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Meu perfil',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded),
                  label: 'Encomendas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_available_outlined),
                  selectedIcon: Icon(Icons.event_available_rounded),
                  label: 'Reservas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.diversity_3_outlined),
                  selectedIcon: Icon(Icons.diversity_3_rounded),
                  label: 'Comunidade',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Perfil',
                ),
              ],
      ),
    );
  }

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
                  'Você pode solicitar entrada em um condomínio existente para aprovação do síndico, ou verificar convites recebidos.',
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _showNotifications,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Abrir notificações e convites'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Verificar atualizações'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

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

  Widget _pageContent() {
    switch (_tab) {
      case 1:
        return _packagesPage();
      case 2:
        return _reservationsPage();
      case 3:
        return _condominium != null
            ? CommunityHubView(
                api: _communityApi,
                condominiumId: _condominium!['id'],
              )
            : _announcementsPage();
      case 4:
        return _profilePage();
      default:
        return _dashboard();
    }
  }

  Widget _dashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFF2F3FB0),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(_condominium?['name']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_text(_condominium?['address'])),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openPaymentDialog,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Taxa Condominial'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showMoreMenus,
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('Serviços'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Resumo e acesso rápido',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final cardWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _dashboardMetricCard(
                width: cardWidth,
                label: 'Minhas encomendas',
                count: _packages.length,
                icon: Icons.inventory_2_outlined,
                accentBg: const Color(0xFFDBEAFE),
                accentFg: const Color(0xFF1D4ED8),
                cardTint: const Color(0xFFF8FAFF),
                onTap: () => setState(() => _tab = 1),
              ),
              _dashboardMetricCard(
                width: cardWidth,
                label: 'Reservas agendadas',
                count: _reservations
                    .where((e) => e['status'] == 'CONFIRMED' || e['status'] == 'PENDING')
                    .length,
                icon: Icons.event_available_outlined,
                accentBg: const Color(0xFFDCFCE7),
                accentFg: const Color(0xFF15803D),
                cardTint: const Color(0xFFF6FEF9),
                onTap: () => setState(() => _tab = 2),
              ),
              _dashboardMetricCard(
                width: cardWidth,
                label: 'Comunidade (11 áreas)',
                count: 11,
                icon: Icons.diversity_3_outlined,
                accentBg: const Color(0xFFFEF3C7),
                accentFg: const Color(0xFFB45309),
                cardTint: const Color(0xFFFFFBEB),
                onTap: () => setState(() => _tab = 3),
              ),
              _dashboardMetricCard(
                width: cardWidth,
                label: 'Taxa Condominial',
                count: 1,
                icon: Icons.receipt_long_outlined,
                accentBg: const Color(0xFFEDE9FE),
                accentFg: const Color(0xFF6D28D9),
                cardTint: const Color(0xFFFAF8FF),
                onTap: _openPaymentDialog,
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      _section(
        'Encomendas recentes',
        _packages.take(3).map((e) {
          final (statusLabel, bg, fg) = _packageStatusStyle(e['status']);
          return _dataTile(
            Icons.inventory_2_outlined,
            _text(e['description'], 'Encomenda registrada'),
            _formatDate(e['receivedAt']),
            badgeLabel: statusLabel,
            badgeBg: bg,
            badgeFg: fg,
          );
        }).toList(),
        onSeeAll: () => setState(() => _tab = 1),
      ),
      _section(
        'Comunicados recentes',
        _announcements
            .take(3)
            .map(
              (e) => _dataTile(
                Icons.campaign_outlined,
                _text(e['title']),
                _formatDate(e['createdAt']),
              ),
            )
            .toList(),
        onSeeAll: () => setState(() => _tab = 3),
      ),
      _section(
        'Próximas reservas confirmadas',
        _reservations
            .where((e) => e['status'] == 'CONFIRMED')
            .take(3)
            .map(
              (e) => _dataTile(
                Icons.event_available_outlined,
                _text(e['commonAreaName']),
                _formatDate(e['startAt']),
                badgeLabel: 'Confirmada',
                badgeBg: const Color(0xFFDCFCE7),
                badgeFg: const Color(0xFF15803D),
              ),
            )
            .toList(),
        onSeeAll: () => setState(() => _tab = 2),
      ),
    ],
  );

  Widget _dashboardMetricCard({
    required double width,
    required String label,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
    Color accentBg = const Color(0xFFE8ECFF),
    Color accentFg = const Color(0xFF2F3FB0),
    Color cardTint = Colors.white,
  }) => SizedBox(
    width: width,
    child: Card(
      color: cardTint,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accentFg.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accentBg,
                child: Icon(icon, color: accentFg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: accentFg,
                      ),
                    ),
                    Text(
                      label,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: accentFg.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _section(String title, List<Widget> rows, {VoidCallback? onSeeAll}) =>
      Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                  if (onSeeAll != null)
                    TextButton(
                      onPressed: onSeeAll,
                      child: const Text('Ver tudo'),
                    ),
                ],
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum registro recente por aqui.'),
                )
              else
                ...rows,
            ],
          ),
        ),
      );

  Widget _dataTile(
    IconData icon,
    String title,
    String subtitle, {
    String? badgeLabel,
    Color? badgeBg,
    Color? badgeFg,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFE8ECFF),
      child: Icon(icon, color: const Color(0xFF2F3FB0), size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    trailing: badgeLabel != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg ?? const Color(0xFFE8ECFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: badgeFg ?? const Color(0xFF2F3FB0),
              ),
            ),
          )
        : null,
  );

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
                const Text(
                  'Acompanhe o recebimento e a retirada das entregas destinadas à sua unidade.',
                ),
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
        hintText: 'Pesquisar encomendas (pressione Enter)',
        onSubmitted: (query) => setState(() => _packageQuery = query),
      ),
      const SizedBox(height: 12),
      if (_packages.where((e) => recordMatchesQuery(e, _packageQuery)).isEmpty)
        _empty(
          'Nenhuma encomenda encontrada para a sua conta.',
          Icons.inventory_2_outlined,
        )
      else
        ..._packages.where((e) => recordMatchesQuery(e, _packageQuery)).map((
          e,
        ) {
          final (statusLabel, bg, fg) = _packageStatusStyle(e['status']);
          final isWaitingPickup = e['status'] == 'RECEIVED' || e['status'] == 'NOTIFIED';

          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  _dataTile(
                    Icons.inventory_2_outlined,
                    _text(e['description'], 'Encomenda'),
                    'Recebida em: ${_formatDate(e['receivedAt'])}',
                    badgeLabel: statusLabel,
                    badgeBg: bg,
                    badgeFg: fg,
                  ),
                  if (isWaitingPickup) ...[
                    const Divider(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.hail_rounded, size: 16),
                        label: const Text('Solicitar Retirada na Portaria'),
                        onPressed: () => _requestPickup(e['id']),
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

  Widget _reservationsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reservas de áreas comuns',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Agende salão de festas, churrasqueira e outros espaços.',
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _createReservation,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova reserva'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      EnterSearchField(
        hintText: 'Pesquisar reservas por área ou data (Enter)',
        onSubmitted: (query) => setState(() => _reservationQuery = query),
      ),
      const SizedBox(height: 12),
      if (_reservations
          .where((e) => recordMatchesQuery(e, _reservationQuery))
          .isEmpty)
        _empty(
          'Você ainda não possui reservas registradas.',
          Icons.event_available_outlined,
        )
      else
        ..._reservations
            .where((e) => recordMatchesQuery(e, _reservationQuery))
            .map((e) {
              final (statusLabel, bg, fg) = _reservationStatusStyle(
                e['status'],
              );
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: bg,
                    child: Icon(
                      Icons.event_available_outlined,
                      color: fg,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    _text(e['commonAreaName']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'De ${_formatDate(e['startAt'])} até ${_formatDate(e['endAt'])}\nSituação: $statusLabel${e['contactPhone'] != null && e['contactPhone'].toString().isNotEmpty ? ' • Tel.: ${formatPhone(e['contactPhone']?.toString())}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: e['status'] == 'CONFIRMED'
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFECACA)),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancelar'),
                          onPressed: () => _cancelReservation(e),
                        )
                      : null,
                ),
              );
            }),
    ],
  );

  Widget _announcementsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Mural de comunicados',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      const Text(
        'Avisos oficiais publicados pela administração do seu condomínio.',
      ),
      const SizedBox(height: 14),
      EnterSearchField(
        hintText: 'Pesquisar comunicados (pressione Enter)',
        onSubmitted: (query) => setState(() => _announcementQuery = query),
      ),
      const SizedBox(height: 12),
      if (_announcements
          .where((e) => recordMatchesQuery(e, _announcementQuery))
          .isEmpty)
        _empty('Nenhum comunicado ativo no momento.', Icons.campaign_outlined)
      else
        ..._announcements
            .where((e) => recordMatchesQuery(e, _announcementQuery))
            .map(
              (e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFEF3C7),
                            child: Icon(
                              Icons.campaign_outlined,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _text(e['title']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  [
                                    _formatDate(e['createdAt']),
                                    if (e['createdByName'] != null &&
                                        e['createdByName']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                      'Por ${e['createdByName']}',
                                  ].join(' • '),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: e['unitName'] != null
                                  ? const Color(0xFFE0E7FF)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              e['unitName']?.toString() ?? 'Condomínio',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: e['unitName'] != null
                                    ? const Color(0xFF2F3FB0)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _text(e['content']),
                        style: const TextStyle(height: 1.45),
                      ),
                      if (e['imageUrl'] != null &&
                          e['imageUrl'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClickableImagePreview(
                          imageSource: e['imageUrl'].toString(),
                          title: _text(e['title']),
                          height: 190,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    ],
  );

  Widget _profilePage() => Card(
    child: Column(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(widget.userName ?? 'Usuário'),
          subtitle: Text(widget.userEmail ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.apartment),
          title: Text(_text(_condominium?['name'])),
          subtitle: Text(_text(_condominium?['address'])),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sair da conta'),
          onTap: widget.onLogout,
        ),
      ],
    ),
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
      (
        'Áreas comuns',
        '/condominiums/{id}/common-areas',
        Icons.deck_outlined,
        'Espaços disponíveis para lazer e reservas',
      ),
      (
        'Planos comerciais',
        '/billing/plans?page=0&size=50',
        Icons.receipt_long_outlined,
        'Planos e recursos ativos no condomínio',
      ),
      if (_canManage) ...[
        (
          'Setores e blocos',
          '/sectors?page=0&size=50',
          Icons.domain_outlined,
          'Blocos, torres e quadras do condomínio',
        ),
        (
          'Unidades residenciais',
          '/units?page=0&size=50',
          Icons.home_work_outlined,
          'Apartamentos e casas cadastradas',
        ),
        (
          'Moradores',
          '/residents?page=0&size=50',
          Icons.groups_outlined,
          'Cadastro de moradores por unidade',
        ),
        (
          'Vínculos e acessos',
          '/memberships?page=0&size=50',
          Icons.admin_panel_settings_outlined,
          'Permissões de moradores, porteiros e síndicos',
        ),
      ],
    ];
    final selected =
        await showModalBottomSheet<(String, String, IconData, String)>(
          context: context,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(
                    title: Text(
                      'Mais serviços do condomínio',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'Selecione uma área para consultar os registros detalhados',
                    ),
                  ),
                  const Divider(height: 1),
                  ...entries.map(
                    (entry) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE8ECFF),
                        child: Icon(entry.$3, color: const Color(0xFF2F3FB0)),
                      ),
                      title: Text(
                        entry.$1,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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
    final path = selected.$2.replaceAll('{id}', '${_condominium?['id']}');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _CollectionPage(api: _api, title: selected.$1, path: path),
      ),
    );
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
    if (created == true) {
      _load();
    }
  }

  Future<void> _openJoinCondominiumDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => JoinCondominiumDialog(api: _communityApi),
    );
    if (sent == true) {
      _load();
    }
  }

  Future<void> _openPaymentDialog() async {
    if (_condominium == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => UnitPaymentConfirmationDialog(
        api: _communityApi,
        condominiumId: _condominium!['id'],
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
              const Text('Cadastre o pacote previsto para a portaria já saber de quem se trata na entrega.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Descrição do pacote *', hintText: 'Ex: Livros da Amazon / Suplementos'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tracking,
                decoration: const InputDecoration(labelText: 'Código de rastreio (opcional)', hintText: 'Ex: BR123456789BR'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sender,
                decoration: const InputDecoration(labelText: 'Remetente / Transportadora', hintText: 'Ex: Mercado Livre / Total Express'),
              ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encomenda prevista cadastrada com sucesso!')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _cancelReservation(Map<String, dynamic> reservation) async {
    final id = reservation['id'];
    if (id == null) {
      return;
    }
    try {
      await _api.send('PATCH', '/reservations/$id/cancel');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reserva cancelada.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _CollectionPage extends StatefulWidget {
  const _CollectionPage({
    required this.api,
    required this.title,
    required this.path,
  });

  final HomeService api;
  final String title;
  final String path;

  @override
  State<_CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<_CollectionPage> {
  late Future<dynamic> _data;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _data = widget.api.get(widget.path);
  }

  void _refresh() => setState(() => _data = widget.api.get(widget.path));

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    if (value is Map && value['content'] is List) {
      return (value['content'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (value is Map<String, dynamic>) return [value];
    return [];
  }

  String _title(Map<String, dynamic> item) {
    for (final key in [
      'name',
      'title',
      'identifier',
      'description',
      'email',
      'authority',
    ]) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return 'Registro sem identificação';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Atualizar lista',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<dynamic>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
        final items = _items(
          snapshot.data,
        ).where((item) => recordMatchesQuery(item, _query)).toList();
        if (items.isEmpty) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: EnterSearchField(
                  onSubmitted: (query) => setState(() => _query = query),
                ),
              ),
              const Expanded(
                child: Center(child: Text('Nenhum registro encontrado.')),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  EnterSearchField(
                    onSubmitted: (query) => setState(() => _query = query),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) {
                    return Card(
                      child: ListTile(
                        onTap: () => showRecordDetailsDialog(
                          context: context,
                          resource: widget.title,
                          item: item,
                          api: widget.api,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8ECFF),
                          child: Icon(
                            Icons.article_outlined,
                            color: Color(0xFF2F3FB0),
                          ),
                        ),
                        title: Text(
                          _title(item),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Toque para abrir a ficha detalhada',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => showRecordDetailsDialog(
                            context: context,
                            resource: widget.title,
                            item: item,
                            api: widget.api,
                          ),
                          child: const Text('Detalhes'),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
