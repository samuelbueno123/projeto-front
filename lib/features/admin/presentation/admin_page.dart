import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/widgets/enter_search_field.dart';
import '../../home/data/home_service.dart';
import '../../auth/presentation/pages/user_profile_page.dart';
import '../../manager/presentation/membership_management_page.dart';
import 'system_announcement_page.dart';
import '../../home/presentation/pages/notifications_page.dart';

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

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late HomeService _api = HomeService(token: widget.token);
  Map<String, dynamic> _profile = {};
  late Future<Map<String, dynamic>> _summary;

  static const _resources = <(String, String, IconData)>[
    ('Usuários', 'users', Icons.people_alt_outlined),
    ('Condomínios', 'condominiums', Icons.apartment_outlined),
    ('Vínculos', 'memberships', Icons.admin_panel_settings_outlined),
    ('Setores', 'sectors', Icons.domain_outlined),
    ('Unidades', 'units', Icons.home_work_outlined),
    ('Moradores', 'residents', Icons.groups_outlined),
    ('Encomendas', 'packages', Icons.inventory_2_outlined),
    ('Comunicados', 'announcements', Icons.campaign_outlined),
    ('Reservas', 'reservations', Icons.event_available_outlined),
    ('Áreas comuns', 'common-areas', Icons.deck_outlined),
    ('Notificações', 'notifications', Icons.notifications_outlined),
    ('Planos', 'billing-plans', Icons.receipt_long_outlined),
    ('Recursos do sistema', 'features', Icons.extension_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _api = HomeService(token: widget.token);
      _summary = _loadSummary();
      _loadProfile();
    }
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
    final result = await _api.get('/admin/dashboard');
    if (result is! Map<String, dynamic>) {
      throw const FormatException(
        'Resposta inválida do painel administrativo.',
      );
    }
    return result;
  }

  Future<void> _refresh() async => setState(() => _summary = _loadSummary());

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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      title: const Text('Painel administrativo'),
      backgroundColor: const Color(0xFF2F3FB0),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Notificações',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NotificationsPage(api: _api),
            ),
          ),
          icon: const Icon(Icons.notifications_none),
        ),
        IconButton(
          tooltip: 'Publicar aviso geral',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SystemAnnouncementPage(api: _api),
            ),
          ),
          icon: const Icon(Icons.campaign_outlined),
        ),
        IconButton(
          tooltip: 'Minha conta',
          onPressed: _openProfile,
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            backgroundImage: _profileAvatarImage,
            child: _profileAvatarImage == null
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Sair',
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _summary,
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
                  const Icon(Icons.cloud_off_outlined, size: 42),
                  const SizedBox(height: 12),
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
        final data = snapshot.data!;
        return LayoutBuilder(
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
                  Text(
                    'Olá, ${widget.userName ?? 'administrador'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.userEmail ?? 'Visão global do aplicativo'),
                  const SizedBox(height: 20),
                  _AdminSearch(api: _api),
                  const SizedBox(height: 20),
                  Text(
                    'Resumo geral',
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
        );
      },
    ),
  );

  String _countKey(String resource) => switch (resource) {
    'common-areas' => 'commonAreas',
    'billing-plans' => 'billingPlans',
    _ => resource,
  };

  void _openResource(String label, String resource) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _AdminResourcePage(api: _api, title: label, resource: resource),
      ),
    );
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
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF3E4CDF)),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Color(0xFF13162A),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF5C6179))),
          ],
        ),
      ),
    ),
  );
}

class _AdminResourcePage extends StatefulWidget {
  const _AdminResourcePage({
    required this.api,
    required this.title,
    required this.resource,
  });
  final HomeService api;
  final String title;
  final String resource;

  @override
  State<_AdminResourcePage> createState() => _AdminResourcePageState();
}

class _AdminResourcePageState extends State<_AdminResourcePage> {
  int _page = 0;
  String _query = '';
  late Future<dynamic> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.api.get(
      '/admin/data/${widget.resource}?page=$_page&size=25&sort=id,desc${_query.trim().isEmpty ? '' : '&query=${Uri.encodeQueryComponent(_query.trim())}'}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => setState(_load),
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
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: EnterSearchField(
                hintText: 'Pesquisar registros',
                onSubmitted: (query) => setState(() {
                  _query = query;
                  _page = 0;
                  _load();
                }),
              ),
            ),
            if (rows.isEmpty)
              const Expanded(
                child: Center(child: Text('Nenhum registro encontrado.')),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final item = rows[index];
                    final title = _primaryValue(item);
                    final details = const JsonEncoder.withIndent(
                      '  ',
                    ).convert(item);
                    return Card(
                      child: ExpansionTile(
                        title: Text(title),
                        subtitle: Text('Registro #${item['id'] ?? '—'}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              details,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                          if (widget.resource == 'condominiums')
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MembershipManagementPage(
                                        api: widget.api,
                                        condominiumId: (item['id'] as num)
                                            .toInt(),
                                        isSystemAdmin: true,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                  ),
                                  label: const Text('Gerenciar síndicos'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SafeArea(
              top: false,
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
                  Text('Página ${_page + 1} de $totalPages'),
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
          ],
        );
      },
    ),
  );

  String _primaryValue(Map<String, dynamic> item) {
    for (final key in [
      'name',
      'title',
      'description',
      'email',
      'identifier',
      'code',
    ]) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return 'Registro ${item['id'] ?? ''}';
  }
}

class _AdminSearch extends StatefulWidget {
  const _AdminSearch({required this.api});
  final HomeService api;

  @override
  State<_AdminSearch> createState() => _AdminSearchState();
}

class _AdminSearchState extends State<_AdminSearch> {
  final _controller = TextEditingController();
  int _requestNumber = 0;
  bool _loading = false;
  String _query = '';
  Map<String, dynamic>? _results;
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
      _error = null;
    });
    if (query.isEmpty) return;
    _search(query, requestNumber);
  }

  Future<void> _search(String query, int requestNumber) async {
    if (!mounted || requestNumber != _requestNumber) return;
    setState(() => _loading = true);
    try {
      final value = await widget.api.get(
        '/admin/search?query=${Uri.encodeQueryComponent(query)}',
      );
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _results = value is Map<String, dynamic> ? value : <String, dynamic>{};
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pesquisar cadastros',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            maxLength: 100,
            onSubmitted: _onSubmitted,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Nome de usuário, condomínio ou setor',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      onPressed: () {
                        _controller.clear();
                        _onSubmitted('');
                      },
                      icon: const Icon(Icons.close),
                    ),
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
          if (_results != null && _query.isNotEmpty && !_loading) ...[
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
      ),
    ),
  );

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
            leading: Icon(icon, color: const Color(0xFF3E4CDF)),
            title: Text(item['name']?.toString() ?? '—'),
            subtitle: item['details'] == null
                ? null
                : Text(item['details'].toString()),
            trailing: key == 'condominiums'
                ? IconButton(
                    tooltip: 'Gerenciar síndicos',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MembershipManagementPage(
                          api: widget.api,
                          condominiumId: (item['id'] as num).toInt(),
                          isSystemAdmin: true,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                  )
                : Text('#${item['id'] ?? '—'}'),
          ),
        ),
      ],
    );
  }
}
