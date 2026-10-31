import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/enter_search_field.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../home/data/home_service.dart';
import '../../auth/presentation/pages/user_profile_page.dart';
import '../../manager/presentation/membership_management_page.dart';
import 'admin_create_dialogs.dart';
import 'system_announcement_page.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      title: const Text('Painel administrativo'),
      backgroundColor: const Color(0xFF2F3FB0),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Criar entrada no banco',
          onPressed: _openCreateAnyEntityMenu,
          icon: const Icon(Icons.add_circle_outline),
        ),
        IconButton(
          tooltip: 'Novo condomínio',
          onPressed: _openCreateCondominium,
          icon: const Icon(Icons.domain_add_outlined),
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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2F3FB0), Color(0xFF4B5DE7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F2F3FB0),
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
                                'Olá, ${firstNameOf(widget.userName, fallback: 'administrador')}! 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.userEmail ??
                                    'Visão global do aplicativo',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2F3FB0),
                          ),
                          onPressed: _openCreateCondominium,
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text('Novo condomínio'),
                        ),
                      ],
                    ),
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
                        subtitle:
                            'Cadastrar qualquer entidade e acoplar ao pai',
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
                        onTap: () =>
                            _openResource('Condomínios', 'condominiums'),
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
                    ],
                  ),
                  const SizedBox(height: 22),
                  _AdminSearch(api: _api, onChanged: _refresh),
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
        );
      },
    ),
  );

  String _countKey(String resource) => switch (resource) {
    'common-areas' => 'commonAreas',
    'billing-plans' => 'billingPlans',
    _ => resource,
  };

  Future<void> _openResource(String label, String resource) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _AdminResourcePage(api: _api, title: label, resource: resource),
      ),
    );
    if (mounted) _refresh();
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
    child: Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF13162A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF5C6179),
                ),
              ),
            ],
          ),
        ),
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

  final created = await showDialog<Map<String, dynamic>>(
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
                      final createdMap = response is Map<String, dynamic>
                          ? response
                          : <String, dynamic>{
                              'name': name,
                              'address': address,
                              'billingPlan': selectedPlan,
                              'isActive': isActive,
                            };
                      final condoId = (createdMap['id'] as num?)?.toInt();
                      if (condoId != null && managerEmail.isNotEmpty) {
                        await api.send(
                          'POST',
                          '/admin/condominiums/$condoId/managers',
                          body: {'email': managerEmail},
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, createdMap);
                      }
                    } catch (e) {
                      setDialogState(() {
                        saving = false;
                        errorMessage = e.toString();
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

  Future<void> _createRecord() async {
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      title: Text(widget.title),
      backgroundColor: const Color(0xFF2F3FB0),
      foregroundColor: Colors.white,
      actions: [
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
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _createRecord,
      icon: const Icon(Icons.add),
      label: Text('Novo em ${widget.title}'),
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  await showDialog<void>(
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: Color(0xFFE2E8F0)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _fieldIcon(entries[i].key),
                  size: 18,
                  color: const Color(0xFF475569),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 135,
                  child: Text(
                    _fieldLabel(entries[i].key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
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
  const _AdminSearch({required this.api, this.onChanged});
  final HomeService api;
  final VoidCallback? onChanged;

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

  Future<void> _openSearchResultDetails(
    String key,
    Map<String, dynamic> summaryItem,
  ) async {
    final id = summaryItem['id'];
    var fullItem = summaryItem;
    if (id != null) {
      try {
        final pageData = await widget.api.get(
          '/admin/data/$key?page=0&size=25&query=${Uri.encodeQueryComponent(id.toString())}',
        );
        if (pageData is Map && pageData['content'] is List) {
          final match = (pageData['content'] as List)
              .whereType<Map<String, dynamic>>()
              .where((e) => e['id'] == id)
              .firstOrNull;
          if (match != null) {
            fullItem = match;
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await showRecordDetailsDialog(
      context: context,
      resource: key,
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pesquisar cadastros (pressione Enter)',
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
            onTap: () => _openSearchResultDetails(key, item),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE8ECFF),
              child: Icon(icon, color: const Color(0xFF3E4CDF), size: 18),
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
