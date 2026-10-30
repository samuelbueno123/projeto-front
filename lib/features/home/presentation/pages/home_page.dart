import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/home_service.dart';
import '../../../auth/presentation/pages/user_profile_page.dart';
import '../../../../core/widgets/enter_search_field.dart';
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
    _load();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _api = HomeService(token: widget.token);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 16, 18, 22),
              decoration: const BoxDecoration(
                color: Color(0xFF2F3FB0),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, ${widget.userName?.trim().isNotEmpty == true ? widget.userName : 'morador'}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _text(
                            _condominium?['name'],
                            widget.userEmail ?? 'Bem-vindo',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (_memberships.isNotEmpty)
                    IconButton(
                      tooltip: 'Outros menus',
                      onPressed: _showMoreMenus,
                      icon: const Icon(Icons.menu, color: Colors.white),
                    ),
                  IconButton(
                    tooltip: 'Notificações',
                    onPressed: () => _showNotifications(),
                    icon: Badge(
                      label: Text(
                        '${_notifications.where((e) => e['read'] != true).length}',
                      ),
                      isLabelVisible: _notifications.any(
                        (e) => e['read'] != true,
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minha conta',
                    onPressed: () => setState(() => _tab = 4),
                    icon: CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.white24,
                      backgroundImage: _profileAvatarImage,
                      child: _profileAvatarImage == null
                          ? const Icon(
                              Icons.person,
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
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [_pageContent()],
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
                  selectedIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Perfil',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: 'Encomendas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_available_outlined),
                  label: 'Reservas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.campaign_outlined),
                  label: 'Comunicados',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Perfil',
                ),
              ],
      ),
    );
  }

  Widget _noCondominiumNotice() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment_outlined, size: 48),
          const SizedBox(height: 14),
          Text(
            'Sua conta ainda não está vinculada a um condomínio.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enquanto isso, você pode consultar notificações e aceitar convites por lá.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _showNotifications,
            icon: const Icon(Icons.notifications_none),
            label: const Text('Abrir notificações'),
          ),
        ],
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
        return _announcementsPage();
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
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.apartment)),
          title: Text(
            _text(_condominium?['name']),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_text(_condominium?['address'])),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
      const SizedBox(height: 20),
      Text('Atalhos rápidos', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _action('Encomendas', Icons.inventory_2_outlined, 1),
          _action('Reservas', Icons.event_available_outlined, 2),
          _action('Comunicados', Icons.campaign_outlined, 3),
        ],
      ),
      const SizedBox(height: 22),
      _section(
        'Encomendas recentes',
        _packages
            .take(3)
            .map(
              (e) => _dataTile(
                Icons.inventory_2_outlined,
                _text(e['description'], 'Encomenda'),
                _text(e['status']),
              ),
            )
            .toList(),
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
                _text(e['createdAt']),
              ),
            )
            .toList(),
        onSeeAll: () => setState(() => _tab = 3),
      ),
      _section(
        'Próximas reservas',
        _reservations
            .where((e) => e['status'] == 'CONFIRMED')
            .take(3)
            .map(
              (e) => _dataTile(
                Icons.event,
                _text(e['commonAreaName']),
                _text(e['startAt']),
              ),
            )
            .toList(),
        onSeeAll: () => setState(() => _tab = 2),
      ),
    ],
  );

  Widget _action(String label, IconData icon, int tab) => ActionChip(
    avatar: Icon(icon, color: const Color(0xFF2F3FB0)),
    label: Text(label),
    onPressed: () => setState(() => _tab = tab),
  );
  Widget _section(String title, List<Widget> rows, {VoidCallback? onSeeAll}) =>
      Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (onSeeAll != null)
                    TextButton(
                      onPressed: onSeeAll,
                      child: const Text('Ver todos'),
                    ),
                ],
              ),
              if (rows.isEmpty)
                const Text('Nenhum registro encontrado.')
              else
                ...rows,
            ],
          ),
        ),
      );
  Widget _dataTile(IconData icon, String title, String subtitle) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: const Color(0xFF3E4CDF)),
    title: Text(title),
    subtitle: Text(subtitle),
  );

  Widget _packagesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Suas encomendas', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      EnterSearchField(
        hintText: 'Pesquisar encomendas',
        onSubmitted: (query) => setState(() => _packageQuery = query),
      ),
      const SizedBox(height: 12),
      if (_packages.where((e) => recordMatchesQuery(e, _packageQuery)).isEmpty)
        _empty('Nenhuma encomenda encontrada.', Icons.inventory_2_outlined)
      else
        ..._packages
            .where((e) => recordMatchesQuery(e, _packageQuery))
            .map(
              (e) => Card(
                child: _dataTile(
                  Icons.inventory_2_outlined,
                  _text(e['description'], 'Encomenda'),
                  '${_text(e['status'])} · ${_text(e['receivedAt'])}',
                ),
              ),
            ),
    ],
  );

  Widget _reservationsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Reservas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          FilledButton.icon(
            onPressed: _createReservation,
            icon: const Icon(Icons.add),
            label: const Text('Reservar'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      EnterSearchField(
        hintText: 'Pesquisar reservas',
        onSubmitted: (query) => setState(() => _reservationQuery = query),
      ),
      const SizedBox(height: 12),
      if (_reservations
          .where((e) => recordMatchesQuery(e, _reservationQuery))
          .isEmpty)
        _empty(
          'Você ainda não possui reservas.',
          Icons.event_available_outlined,
        )
      else
        ..._reservations
            .where((e) => recordMatchesQuery(e, _reservationQuery))
            .map(
              (e) => Card(
                child: ListTile(
                  title: Text(_text(e['commonAreaName'])),
                  subtitle: Text(
                    '${_text(e['startAt'])} – ${_text(e['endAt'])}\n${_text(e['status'])}',
                  ),
                  isThreeLine: true,
                  trailing: e['status'] == 'CONFIRMED'
                      ? IconButton(
                          tooltip: 'Cancelar reserva',
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () => _cancelReservation(e),
                        )
                      : null,
                ),
              ),
            ),
    ],
  );

  Widget _announcementsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Comunicados', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      EnterSearchField(
        hintText: 'Pesquisar comunicados',
        onSubmitted: (query) => setState(() => _announcementQuery = query),
      ),
      const SizedBox(height: 12),
      if (_announcements
          .where((e) => recordMatchesQuery(e, _announcementQuery))
          .isEmpty)
        _empty('Nenhum comunicado ativo.', Icons.campaign_outlined)
      else
        ..._announcements
            .where((e) => recordMatchesQuery(e, _announcementQuery))
            .map(
              (e) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.campaign_outlined,
                    color: Color(0xFF3E4CDF),
                  ),
                  title: Text(_text(e['title'])),
                  subtitle: Text(
                    '${_text(e['content'])}\n${_text(e['createdAt'])}',
                  ),
                  isThreeLine: true,
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

  Widget _empty(String message, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
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
    final entries = <(String, String, IconData)>[
      ('Áreas comuns', '/condominiums/{id}/common-areas', Icons.deck_outlined),
      ('Planos', '/billing/plans?page=0&size=50', Icons.receipt_long_outlined),
      if (_canManage) ...[
        ('Setores', '/sectors?page=0&size=50', Icons.domain_outlined),
        ('Unidades', '/units?page=0&size=50', Icons.home_work_outlined),
        ('Moradores', '/residents?page=0&size=50', Icons.groups_outlined),
        (
          'Vínculos',
          '/memberships?page=0&size=50',
          Icons.admin_panel_settings_outlined,
        ),
      ],
    ];
    final selected = await showModalBottomSheet<(String, String, IconData)>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Outros menus',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...entries.map(
              (entry) => ListTile(
                leading: Icon(entry.$3),
                title: Text(entry.$1),
                onTap: () => Navigator.pop(context, entry),
              ),
            ),
          ],
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
    try {
      final id = _condominium?['id'];
      final areas = _list(await _api.get('/condominiums/$id/common-areas'));
      if (!mounted) return;
      if (areas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não há áreas comuns disponíveis.')),
        );
        return;
      }
      final area = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Escolha uma área'),
          children: areas
              .map(
                (a) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, a),
                  child: Text(_text(a['name'])),
                ),
              )
              .toList(),
        ),
      );
      if (area == null || !mounted) return;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: tomorrow,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (selectedDate == null || !mounted) return;
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 14, minute: 0),
      );
      if (selectedTime == null || !mounted) return;
      final start = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      await _api.send(
        'POST',
        '/common-areas/${area['id']}/reservations',
        body: {
          'startAt': start.toIso8601String(),
          'endAt': start.add(const Duration(hours: 2)).toIso8601String(),
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reserva criada.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    return 'Registro ${item['id'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
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
                padding: const EdgeInsets.all(12),
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
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              EnterSearchField(
                onSubmitted: (query) => setState(() => _query = query),
              ),
              const SizedBox(height: 12),
              ...items.map((item) {
                final details = item.entries
                    .where((entry) => entry.value != null && entry.key != 'id')
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join('\n');
                return Card(
                  child: ListTile(
                    title: Text(_title(item)),
                    subtitle: Text(
                      details,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text('#${item['id'] ?? ''}'),
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );
}
