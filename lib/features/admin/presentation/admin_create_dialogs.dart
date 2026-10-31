import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../home/data/home_service.dart';

const List<(String, String, IconData)> kAdminCreatableResources = [
  ('Usuários', 'users', Icons.people_alt_outlined),
  ('Condomínios', 'condominiums', Icons.apartment_outlined),
  ('Vínculos', 'memberships', Icons.admin_panel_settings_outlined),
  ('Setores', 'sectors', Icons.domain_outlined),
  ('Unidades', 'units', Icons.home_work_outlined),
  ('Moradores', 'residents', Icons.groups_outlined),
  ('Encomendas', 'packages', Icons.inventory_2_outlined),
  ('Comunicados', 'announcements', Icons.campaign_outlined),
  ('Áreas comuns', 'common-areas', Icons.deck_outlined),
  ('Reservas', 'reservations', Icons.event_available_outlined),
  ('Planos', 'billing-plans', Icons.receipt_long_outlined),
  ('Recursos do sistema', 'features', Icons.extension_outlined),
];

const List<(String, String)> kSystemRoles = [
  ('ROLE_RESIDENT', 'Morador'),
  ('ROLE_DOORMAN', 'Porteiro'),
  ('ROLE_MANAGER', 'Síndico'),
  ('ROLE_ADMIN', 'Administrador'),
];

const List<(String, String)> kMembershipRoles = [
  ('ROLE_RESIDENT', 'Morador'),
  ('ROLE_DOORMAN', 'Porteiro'),
  ('ROLE_MANAGER', 'Síndico'),
];

const List<(String, String)> kSectorStructuralTypes = [
  ('BLOCK', 'Bloco'),
  ('STREET', 'Rua'),
  ('COURT', 'Quadra'),
  ('GRILL', 'Área gourmet'),
];

const List<(String, String)> kResidentTypes = [
  ('OWNER', 'Proprietário'),
  ('TENANT', 'Inquilino'),
  ('DEPENDENT', 'Dependente'),
];

const List<(String, String)> kFeatureCodes = [
  ('PACKAGES', 'Encomendas (PACKAGES)'),
  ('NOTIFICATIONS', 'Notificações (NOTIFICATIONS)'),
  ('ANNOUNCEMENTS', 'Comunicados (ANNOUNCEMENTS)'),
  ('RESERVATIONS', 'Reservas de áreas comuns (RESERVATIONS)'),
  ('REPORTS', 'Relatórios (REPORTS)'),
  (
    'MARKETPLACE_INTEGRATION',
    'Integração Marketplace (MARKETPLACE_INTEGRATION)',
  ),
];

Future<List<Map<String, dynamic>>> _fetchResourceList(
  HomeService api,
  String resource,
) async {
  try {
    final res = await api.get(
      '/admin/data/$resource?page=0&size=200&sort=id,asc',
    );
    if (res is Map && res['content'] is List) {
      return (res['content'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  } catch (_) {}
  return [];
}

int? _asInt(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

String _userLabel(Map<String, dynamic> u) {
  final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
  final email = u['email']?.toString() ?? '';
  if (name.isNotEmpty && email.isNotEmpty) {
    return '$name ($email)';
  }
  if (name.isNotEmpty) return name;
  if (email.isNotEmpty) return email;
  return 'Usuário cadastrado';
}

String _condoLabel(Map<String, dynamic> c) {
  return c['name']?.toString() ?? 'Condomínio';
}

String _sectorLabel(Map<String, dynamic> s, Map<int, String> condoNames) {
  final condoId = _asInt(s['condominiumId']);
  final condoName =
      s['condominiumName']?.toString() ??
      (condoId != null ? condoNames[condoId] : null) ??
      '';
  final name = s['name']?.toString() ?? 'Setor';
  return condoName.isNotEmpty ? '$condoName • $name' : name;
}

String _unitLabel(
  Map<String, dynamic> u,
  Map<int, Map<String, dynamic>> sectorsById,
  Map<int, String> condoNames,
) {
  final sectorId = _asInt(u['sectorId']);
  final sector = sectorId != null ? sectorsById[sectorId] : null;
  final sectorName =
      u['sectorName']?.toString() ?? sector?['name']?.toString() ?? 'Setor';
  final condoId =
      _asInt(u['condominiumId']) ?? _asInt(sector?['condominiumId']);
  final condoName =
      u['condominiumName']?.toString() ??
      (condoId != null ? condoNames[condoId] : null) ??
      '';
  final identifier = u['identifier']?.toString() ?? '';
  if (condoName.isNotEmpty) {
    return '$condoName • $sectorName • Unidade $identifier';
  }
  return '$sectorName • Unidade $identifier';
}

Future<Map<String, dynamic>?> showCreateAdminResourceDialog({
  required BuildContext context,
  required HomeService api,
  required String resource,
  required String title,
}) async {
  // Load parent datasets needed for the selected resource
  final needsUsers = const {
    'condominiums',
    'memberships',
    'residents',
    'packages',
    'reservations',
  }.contains(resource);
  final needsCondos = const {
    'memberships',
    'sectors',
    'units',
    'residents',
    'packages',
    'announcements',
    'common-areas',
    'reservations',
  }.contains(resource);
  final needsSectors = const {
    'units',
    'residents',
    'packages',
  }.contains(resource);
  final needsUnits = const {'residents', 'packages'}.contains(resource);
  final needsCommonAreas = resource == 'reservations';
  final needsPlans = resource == 'condominiums';

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> condos = [];
  List<Map<String, dynamic>> sectors = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> commonAreas = [];
  List<Map<String, dynamic>> plans = [];

  try {
    final futures = <Future<void>>[
      if (needsUsers) _fetchResourceList(api, 'users').then((v) => users = v),
      if (needsCondos)
        _fetchResourceList(api, 'condominiums').then((v) => condos = v),
      if (needsSectors)
        _fetchResourceList(api, 'sectors').then((v) => sectors = v),
      if (needsUnits) _fetchResourceList(api, 'units').then((v) => units = v),
      if (needsCommonAreas)
        _fetchResourceList(api, 'common-areas').then((v) => commonAreas = v),
      if (needsPlans)
        _fetchResourceList(api, 'billing-plans').then((v) => plans = v),
    ];
    await Future.wait(futures);
  } finally {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  if (!context.mounted) return null;

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AdminResourceCreateDialog(
      api: api,
      resource: resource,
      title: title,
      users: users,
      condos: condos,
      sectors: sectors,
      units: units,
      commonAreas: commonAreas,
      plans: plans,
    ),
  );
}

class _AdminResourceCreateDialog extends StatefulWidget {
  const _AdminResourceCreateDialog({
    required this.api,
    required this.resource,
    required this.title,
    required this.users,
    required this.condos,
    required this.sectors,
    required this.units,
    required this.commonAreas,
    required this.plans,
  });

  final HomeService api;
  final String resource;
  final String title;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> condos;
  final List<Map<String, dynamic>> sectors;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> commonAreas;
  final List<Map<String, dynamic>> plans;

  @override
  State<_AdminResourceCreateDialog> createState() =>
      _AdminResourceCreateDialogState();
}

class _AdminResourceCreateDialogState
    extends State<_AdminResourceCreateDialog> {
  final _text1 = TextEditingController();
  final _text2 = TextEditingController();
  final _text3 = TextEditingController();
  final _text4 = TextEditingController();

  late Map<int, String> _condoNames;
  late Map<int, Map<String, dynamic>> _sectorsById;

  int? _selectedCondoId;
  int? _selectedSectorId;
  int? _selectedUnitId;
  int? _selectedUserId;
  int? _selectedCommonAreaId;
  String? _selectedPlanName;
  String _selectedRole = 'ROLE_RESIDENT';
  final Set<String> _selectedUserRoles = {'ROLE_RESIDENT'};
  String _selectedStructuralType = 'BLOCK';
  String _selectedResidentType = 'OWNER';
  String _selectedPackageInitialStatus = 'RECEIVED';
  String _selectedFeatureCode = 'PACKAGES';
  final Set<String> _selectedPlanFeatures = {
    'PACKAGES',
    'NOTIFICATIONS',
    'ANNOUNCEMENTS',
    'RESERVATIONS',
  };
  bool _boolFlag = true;
  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _expiresAt;
  String? _imageDataUrl;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _condoNames = {
      for (final c in widget.condos)
        if (_asInt(c['id']) != null)
          _asInt(c['id'])!: c['name']?.toString() ?? 'Condomínio',
    };
    _sectorsById = {
      for (final s in widget.sectors)
        if (_asInt(s['id']) != null) _asInt(s['id'])!: s,
    };

    if (widget.condos.isNotEmpty) {
      _selectedCondoId = _asInt(widget.condos.first['id']);
    }
    if (widget.users.isNotEmpty) {
      _selectedUserId = _asInt(widget.users.first['id']);
      if (widget.resource == 'condominiums') {
        _selectedUserId =
            null; // Optional initial manager on condominium creation
      }
    }
    _syncCascadingSelections();

    final availablePlanNames = <String>['Básico', 'Profissional', 'Premium'];
    for (final p in widget.plans) {
      final n = p['name']?.toString().trim() ?? '';
      if (n.isNotEmpty &&
          !availablePlanNames.any((e) => e.toLowerCase() == n.toLowerCase())) {
        availablePlanNames.add(n);
      }
    }
    _selectedPlanName = availablePlanNames.first;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _startAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0);
    _endAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 0);
  }

  void _syncCascadingSelections() {
    final filteredSectors = _filteredSectors;
    if (filteredSectors.isEmpty) {
      _selectedSectorId = null;
    } else if (_selectedSectorId == null ||
        !filteredSectors.any((s) => _asInt(s['id']) == _selectedSectorId)) {
      _selectedSectorId = _asInt(filteredSectors.first['id']);
    }

    final filteredUnits = _filteredUnits;
    if (filteredUnits.isEmpty) {
      _selectedUnitId = null;
    } else if (_selectedUnitId == null ||
        !filteredUnits.any((u) => _asInt(u['id']) == _selectedUnitId)) {
      _selectedUnitId = _asInt(filteredUnits.first['id']);
    }

    final filteredAreas = _filteredCommonAreas;
    if (filteredAreas.isEmpty) {
      _selectedCommonAreaId = null;
    } else if (_selectedCommonAreaId == null ||
        !filteredAreas.any((a) => _asInt(a['id']) == _selectedCommonAreaId)) {
      _selectedCommonAreaId = _asInt(filteredAreas.first['id']);
    }
  }

  List<Map<String, dynamic>> get _filteredSectors {
    if (_selectedCondoId == null) return widget.sectors;
    return widget.sectors
        .where((s) => _asInt(s['condominiumId']) == _selectedCondoId)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredUnits {
    if (widget.resource == 'packages' || widget.resource == 'residents') {
      if (_selectedCondoId == null) return widget.units;
      return widget.units.where((u) {
        final directCondoId = _asInt(u['condominiumId']);
        if (directCondoId != null) return directCondoId == _selectedCondoId;
        final sectorId = _asInt(u['sectorId']);
        final sector = sectorId != null ? _sectorsById[sectorId] : null;
        return _asInt(sector?['condominiumId']) == _selectedCondoId;
      }).toList();
    }
    return widget.units;
  }

  List<Map<String, dynamic>> get _filteredCommonAreas {
    if (_selectedCondoId == null) return widget.commonAreas;
    return widget.commonAreas
        .where((a) => _asInt(a['condominiumId']) == _selectedCondoId)
        .toList();
  }

  @override
  void dispose() {
    _text1.dispose();
    _text2.dispose();
    _text3.dispose();
    _text4.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1000000) {
      setState(() => _errorMessage = 'A imagem deve ter no máximo 1 MB.');
      return;
    }
    final name = file.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    setState(() {
      _imageDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Selecionar data e horário';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _saving = true;
    });

    try {
      dynamic response;
      switch (widget.resource) {
        case 'users':
          final firstName = _text1.text.trim();
          final lastName = _text2.text.trim();
          final email = _text3.text.trim().toLowerCase();
          final password = _text4.text.trim();
          if (firstName.isEmpty || email.isEmpty || !email.contains('@')) {
            throw Exception('Informe o nome e um e-mail válido.');
          }
          if (password.length < 8) {
            throw Exception('A senha deve ter no mínimo 8 caracteres.');
          }
          if (_selectedUserRoles.isEmpty) {
            throw Exception('Selecione pelo menos um perfil de acesso.');
          }
          response = await widget.api.send(
            'POST',
            '/users',
            body: {
              'firstName': firstName,
              'lastName': lastName,
              'email': email,
              'password': password,
              'roles': _selectedUserRoles
                  .map((authority) => {'authority': authority})
                  .toList(),
            },
          );

        case 'condominiums':
          final name = _text1.text.trim();
          final address = _text2.text.trim();
          if (name.isEmpty || address.isEmpty) {
            throw Exception('Informe o nome e o endereço do condomínio.');
          }
          response = await widget.api.send(
            'POST',
            '/condominiums',
            body: {
              'name': name,
              'address': address,
              'billingPlan': _selectedPlanName ?? 'Básico',
              'isActive': _boolFlag,
            },
          );
          final condoId = response is Map ? _asInt(response['id']) : null;
          if (condoId != null && _selectedUserId != null) {
            final managerUser = widget.users
                .where((u) => _asInt(u['id']) == _selectedUserId)
                .firstOrNull;
            final managerEmail = managerUser?['email']?.toString().trim() ?? '';
            if (managerEmail.isNotEmpty) {
              await widget.api.send(
                'POST',
                '/admin/condominiums/$condoId/managers',
                body: {'email': managerEmail},
              );
            }
          }

        case 'memberships':
          if (_selectedCondoId == null || _selectedUserId == null) {
            throw Exception('Selecione o condomínio pai e o usuário.');
          }
          response = await widget.api.send(
            'POST',
            '/memberships',
            body: {
              'userId': _selectedUserId,
              'condominiumId': _selectedCondoId,
              'authority': _selectedRole,
            },
          );

        case 'sectors':
          final name = _text1.text.trim();
          if (_selectedCondoId == null) {
            throw Exception('Selecione o condomínio pai.');
          }
          if (name.isEmpty) {
            throw Exception('Informe o nome do setor (ex.: Bloco A).');
          }
          response = await widget.api.send(
            'POST',
            '/sectors',
            body: {
              'name': name,
              'structuralType': _selectedStructuralType,
              'condominiumId': _selectedCondoId,
            },
          );

        case 'units':
          final identifier = _text1.text.trim();
          if (_selectedSectorId == null) {
            throw Exception(
              'Selecione o setor pai onde a unidade será acoplada.',
            );
          }
          if (identifier.isEmpty) {
            throw Exception('Informe o identificador da unidade (ex.: 101).');
          }
          response = await widget.api.send(
            'POST',
            '/units',
            body: {'identifier': identifier, 'sectorId': _selectedSectorId},
          );

        case 'residents':
          if (_selectedUnitId == null || _selectedUserId == null) {
            throw Exception('Selecione a unidade pai e o usuário morador.');
          }
          response = await widget.api.send(
            'POST',
            '/residents',
            body: {
              'userId': _selectedUserId,
              'unitId': _selectedUnitId,
              'type': _selectedResidentType,
            },
          );

        case 'packages':
          final description = _text1.text.trim();
          if (_selectedCondoId == null ||
              _selectedUnitId == null ||
              _selectedUserId == null) {
            throw Exception(
              'Selecione o condomínio, a unidade e o morador destinatário.',
            );
          }
          if (description.isEmpty) {
            throw Exception('Informe a descrição da encomenda.');
          }
          final endpoint = _selectedPackageInitialStatus == 'EXPECTED'
              ? '/packages/expected'
              : '/packages';
          response = await widget.api.send(
            'POST',
            endpoint,
            body: {
              'condominiumId': _selectedCondoId,
              'unitId': _selectedUnitId,
              'recipientId': _selectedUserId,
              'description': description,
            },
          );

        case 'announcements':
          final title = _text1.text.trim();
          final content = _text2.text.trim();
          if (_selectedCondoId == null) {
            throw Exception('Selecione o condomínio pai do comunicado.');
          }
          if (title.isEmpty || content.isEmpty) {
            throw Exception('Informe o título e o conteúdo do comunicado.');
          }
          response = await widget.api.send(
            'POST',
            '/condominiums/$_selectedCondoId/announcements',
            body: {
              'title': title,
              'content': content,
              'expiresAt': _expiresAt?.toIso8601String(),
              'imageUrl': _imageDataUrl,
            },
          );

        case 'common-areas':
          final name = _text1.text.trim();
          final description = _text2.text.trim();
          final capacity = int.tryParse(_text3.text.trim());
          if (_selectedCondoId == null) {
            throw Exception('Selecione o condomínio pai da área comum.');
          }
          if (name.isEmpty) {
            throw Exception('Informe o nome da área comum.');
          }
          if (capacity == null || capacity < 1) {
            throw Exception('A capacidade deve ser de pelo menos 1 pessoa.');
          }
          response = await widget.api.send(
            'POST',
            '/condominiums/$_selectedCondoId/common-areas',
            body: {
              'name': name,
              'description': description.isEmpty ? null : description,
              'capacity': capacity,
            },
          );

        case 'reservations':
          if (_selectedCommonAreaId == null) {
            throw Exception('Selecione a área comum pai para a reserva.');
          }
          if (_selectedUserId == null) {
            throw Exception('Selecione o usuário responsável pela reserva.');
          }
          if (_startAt == null || _endAt == null) {
            throw Exception('Informe a data/hora de início e término.');
          }
          if (!_endAt!.isAfter(_startAt!)) {
            throw Exception(
              'O horário de término deve ser posterior ao início.',
            );
          }
          response = await widget.api.send(
            'POST',
            '/common-areas/$_selectedCommonAreaId/reservations',
            body: {
              'startAt': _startAt!.toIso8601String(),
              'endAt': _endAt!.toIso8601String(),
              'reservedById': _selectedUserId,
            },
          );

        case 'billing-plans':
          final name = _text1.text.trim();
          final fee = double.tryParse(_text2.text.trim().replaceAll(',', '.'));
          if (name.isEmpty) {
            throw Exception('Informe o nome do plano comercial.');
          }
          if (fee == null || fee < 0) {
            throw Exception('Informe um valor mensal válido (ex.: 199.90).');
          }
          response = await widget.api.send(
            'POST',
            '/billing/plans',
            body: {
              'name': name,
              'monthlyFee': fee,
              'features': _selectedPlanFeatures.toList(),
            },
          );

        case 'features':
          final featureName = _text1.text.trim();
          final featureDesc = _text2.text.trim();
          if (featureName.isEmpty) {
            throw Exception('Informe o nome do recurso.');
          }
          response = await widget.api.send(
            'POST',
            '/billing/features',
            body: {
              'code': _selectedFeatureCode,
              'name': featureName,
              'description': featureDesc.isEmpty ? null : featureDesc,
            },
          );
      }

      if (mounted) {
        Navigator.of(context).pop(
          response is Map<String, dynamic>
              ? response
              : <String, dynamic>{'created': true},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE8ECFF),
            child: Icon(Icons.add_circle_outline, color: Color(0xFF2F3FB0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Novo registro • ${widget.title}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildFields(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Salvando...' : 'Criar registro'),
        ),
      ],
    );
  }

  List<Widget> _buildFields() {
    switch (widget.resource) {
      case 'users':
        return [
          const Text(
            'Cadastre uma nova conta de usuário respeitando os campos e perfis de acesso.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text1,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Nome (firstName) *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text2,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Sobrenome (lastName - opcional)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text3,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail (email) *',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text4,
            enabled: !_saving,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Senha inicial (mínimo 8 caracteres) *',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Perfis de acesso (roles) *',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kSystemRoles.map((role) {
              final selected = _selectedUserRoles.contains(role.$1);
              return FilterChip(
                label: Text(role.$2),
                selected: selected,
                onSelected: _saving
                    ? null
                    : (val) {
                        setState(() {
                          if (val) {
                            _selectedUserRoles.add(role.$1);
                          } else if (_selectedUserRoles.length > 1) {
                            _selectedUserRoles.remove(role.$1);
                          }
                        });
                      },
              );
            }).toList(),
          ),
        ];

      case 'condominiums':
        final availablePlans = <String>['Básico', 'Profissional', 'Premium'];
        for (final p in widget.plans) {
          final n = p['name']?.toString().trim() ?? '';
          if (n.isNotEmpty &&
              !availablePlans.any((e) => e.toLowerCase() == n.toLowerCase())) {
            availablePlans.add(n);
          }
        }
        return [
          const Text(
            'Cadastre um novo condomínio acoplando-o a um plano comercial e, opcionalmente, a um síndico.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text1,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Nome do condomínio (name) *',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text2,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Endereço completo (address) *',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedPlanName,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Plano comercial pai (billingPlan) *',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
            items: availablePlans
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _selectedPlanName = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _selectedUserId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Usuário síndico inicial (opcional)',
              prefixIcon: Icon(Icons.admin_panel_settings_outlined),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Não atribuir síndico agora'),
              ),
              ...widget.users.map(
                (u) => DropdownMenuItem<int?>(
                  value: _asInt(u['id']),
                  child: Text(_userLabel(u), overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() => _selectedUserId = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Condomínio ativo (isActive)'),
            value: _boolFlag,
            onChanged: _saving ? null : (v) => setState(() => _boolFlag = v),
          ),
        ];

      case 'memberships':
        return [
          const Text(
            'Vincule um usuário existente a um condomínio pai escolhendo a função.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(label: 'Condomínio *'),
          const SizedBox(height: 12),
          _buildUserDropdown(label: 'Usuário vinculado *'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Função no condomínio (authority) *',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
            items: kMembershipRoles
                .map(
                  (r) => DropdownMenuItem(
                    value: r.$1,
                    child: Text('${r.$2} (${r.$1})'),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _selectedRole = v ?? _selectedRole),
          ),
        ];

      case 'sectors':
        return [
          const Text(
            'Selecione o condomínio pai para acoplar o novo setor, bloco ou quadra.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(label: 'Condomínio *'),
          const SizedBox(height: 12),
          TextField(
            controller: _text1,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Nome do setor (name) *',
              hintText: 'Ex.: Bloco A, Torre Sul, Quadra 1',
              prefixIcon: Icon(Icons.domain_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedStructuralType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo estrutural (structuralType) *',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: kSectorStructuralTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t.$1,
                    child: Text('${t.$2} (${t.$1})'),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(
                    () =>
                        _selectedStructuralType = v ?? _selectedStructuralType,
                  ),
          ),
        ];

      case 'units':
        final filteredSectors = _filteredSectors;
        return [
          const Text(
            'Selecione o condomínio e o setor pai onde a unidade residencial será acoplada.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(
            label: 'Filtrar por condomínio pai',
            onChanged: (v) {
              setState(() {
                _selectedCondoId = v;
                _syncCascadingSelections();
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('sector_${_selectedCondoId}_$_selectedSectorId'),
            initialValue: _selectedSectorId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Setor *',
              prefixIcon: Icon(Icons.domain_outlined),
            ),
            items: filteredSectors
                .map(
                  (s) => DropdownMenuItem<int>(
                    value: _asInt(s['id']),
                    child: Text(
                      _sectorLabel(s, _condoNames),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _selectedSectorId = v),
          ),
          if (filteredSectors.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Este condomínio ainda não possui setores cadastrados. Crie um setor primeiro.',
                style: TextStyle(color: Color(0xFFB45309), fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _text1,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Identificador da unidade (identifier) *',
              hintText: 'Ex.: 101, 202-B, Casa 05',
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
          ),
        ];

      case 'residents':
        final filteredUnits = _filteredUnits;
        return [
          const Text(
            'Acople um usuário a uma unidade residencial indicando o tipo de morador.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(
            label: 'Filtrar unidades por condomínio',
            onChanged: (v) {
              setState(() {
                _selectedCondoId = v;
                _syncCascadingSelections();
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('unit_${_selectedCondoId}_$_selectedUnitId'),
            initialValue: _selectedUnitId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Unidade residencial *',
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
            items: filteredUnits
                .map(
                  (u) => DropdownMenuItem<int>(
                    value: _asInt(u['id']),
                    child: Text(
                      _unitLabel(u, _sectorsById, _condoNames),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _selectedUnitId = v),
          ),
          const SizedBox(height: 12),
          _buildUserDropdown(label: 'Morador *'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedResidentType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de vínculo (type) *',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
            items: kResidentTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t.$1,
                    child: Text('${t.$2} (${t.$1})'),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(
                    () => _selectedResidentType = v ?? _selectedResidentType,
                  ),
          ),
        ];

      case 'packages':
        final filteredUnits = _filteredUnits;
        return [
          const Text(
            'Registre uma encomenda selecionando o condomínio, a unidade e o morador destinatário.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(
            label: 'Condomínio *',
            onChanged: (v) {
              setState(() {
                _selectedCondoId = v;
                _syncCascadingSelections();
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('pkg_unit_${_selectedCondoId}_$_selectedUnitId'),
            initialValue: _selectedUnitId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Unidade de destino *',
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
            items: filteredUnits
                .map(
                  (u) => DropdownMenuItem<int>(
                    value: _asInt(u['id']),
                    child: Text(
                      _unitLabel(u, _sectorsById, _condoNames),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _selectedUnitId = v),
          ),
          const SizedBox(height: 12),
          _buildUserDropdown(label: 'Destinatário *'),
          const SizedBox(height: 12),
          TextField(
            controller: _text1,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Descrição da encomenda (description) *',
              hintText: 'Ex.: Caixa Mercado Livre / Envelope bancário',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedPackageInitialStatus,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status inicial da encomenda *',
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'RECEIVED',
                child: Text('Recebida na portaria (RECEIVED)'),
              ),
              DropdownMenuItem(
                value: 'EXPECTED',
                child: Text('Aguardando chegada (EXPECTED)'),
              ),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(
                    () => _selectedPackageInitialStatus =
                        v ?? _selectedPackageInitialStatus,
                  ),
          ),
        ];

      case 'announcements':
        return [
          const Text(
            'Publique um comunicado acoplado a um condomínio específico.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(label: 'Condomínio *'),
          const SizedBox(height: 12),
          TextField(
            controller: _text1,
            enabled: !_saving,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Título do comunicado (title) *',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text2,
            enabled: !_saving,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Conteúdo (content) *',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final picked = await _pickDateTime(
                      _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) {
                      setState(() => _expiresAt = picked);
                    }
                  },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _expiresAt == null
                  ? 'Data de expiração (opcional)'
                  : 'Expira em: ${_formatDateTime(_expiresAt)}',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _imageDataUrl == null ? 'Anexar imagem' : 'Trocar imagem',
                ),
              ),
              if (_imageDataUrl != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _imageDataUrl = null),
                  child: const Text('Remover'),
                ),
              ],
            ],
          ),
          if (_imageDataUrl != null) ...[
            const SizedBox(height: 10),
            ClickableImagePreview(
              imageSource: _imageDataUrl!,
              title: _text1.text.trim(),
              height: 150,
            ),
          ],
        ];

      case 'common-areas':
        return [
          const Text(
            'Cadastre uma nova área comum acoplada ao condomínio pai selecionado.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(label: 'Condomínio *'),
          const SizedBox(height: 12),
          TextField(
            controller: _text1,
            enabled: !_saving,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Nome da área comum (name) *',
              hintText: 'Ex.: Salão de Festas, Churrasqueira Gourmet',
              prefixIcon: Icon(Icons.deck_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text2,
            enabled: !_saving,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Descrição / regras (description - opcional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text3,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Capacidade máxima de pessoas (capacity) *',
              hintText: 'Ex.: 40',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
        ];

      case 'reservations':
        final filteredAreas = _filteredCommonAreas;
        return [
          const Text(
            'Agende uma reserva acoplando-a ao condomínio, à área comum e ao morador responsável.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          _buildCondoDropdown(
            label: 'Condomínio pai',
            onChanged: (v) {
              setState(() {
                _selectedCondoId = v;
                _syncCascadingSelections();
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('area_${_selectedCondoId}_$_selectedCommonAreaId'),
            initialValue: _selectedCommonAreaId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Área comum *',
              prefixIcon: Icon(Icons.deck_outlined),
            ),
            items: filteredAreas
                .map(
                  (a) => DropdownMenuItem<int>(
                    value: _asInt(a['id']),
                    child: Text(
                      '${a['name']} (Cap.: ${a['capacity'] ?? '—'})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _selectedCommonAreaId = v),
          ),
          const SizedBox(height: 12),
          _buildUserDropdown(label: 'Reservado por *'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final picked = await _pickDateTime(
                      _startAt ?? DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setState(() {
                        _startAt = picked;
                        if (_endAt == null || !_endAt!.isAfter(picked)) {
                          _endAt = picked.add(const Duration(hours: 2));
                        }
                      });
                    }
                  },
            icon: const Icon(Icons.schedule_outlined),
            label: Text('Início (startAt): ${_formatDateTime(_startAt)}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final picked = await _pickDateTime(
                      _endAt ??
                          (_startAt ?? DateTime.now()).add(
                            const Duration(hours: 2),
                          ),
                    );
                    if (picked != null) {
                      setState(() => _endAt = picked);
                    }
                  },
            icon: const Icon(Icons.event_available_outlined),
            label: Text('Término (endAt): ${_formatDateTime(_endAt)}'),
          ),
        ];

      case 'billing-plans':
        return [
          const Text(
            'Crie um plano comercial definindo a mensalidade e os recursos habilitados.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text1,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Nome do plano (name) *',
              hintText: 'Ex.: Empresarial Plus',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text2,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Mensalidade em R\$ (monthlyFee) *',
              hintText: 'Ex.: 249.90',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Recursos vinculados ao plano (features) *',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kFeatureCodes.map((f) {
              final selected = _selectedPlanFeatures.contains(f.$1);
              return FilterChip(
                label: Text(f.$2),
                selected: selected,
                onSelected: _saving
                    ? null
                    : (val) {
                        setState(() {
                          if (val) {
                            _selectedPlanFeatures.add(f.$1);
                          } else {
                            _selectedPlanFeatures.remove(f.$1);
                          }
                        });
                      },
              );
            }).toList(),
          ),
        ];

      case 'features':
        return [
          const Text(
            'Cadastre ou atualize um recurso do sistema respeitando código, nome e descrição.',
            style: TextStyle(color: Color(0xFF5C6179)),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedFeatureCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Código do recurso (code) *',
              prefixIcon: Icon(Icons.extension_outlined),
            ),
            items: kFeatureCodes
                .map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2)))
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(
                    () => _selectedFeatureCode = v ?? _selectedFeatureCode,
                  ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text1,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Nome do recurso (name) *',
              hintText: 'Ex.: Gestão de Encomendas',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text2,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Descrição (description - opcional)',
              hintText: 'Ex.: Controle de recebimento e retirada na portaria',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ];

      default:
        return [const Text('Recurso não suportado para criação direta.')];
    }
  }

  Widget _buildCondoDropdown({
    required String label,
    ValueChanged<int?>? onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedCondoId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.apartment_outlined),
      ),
      items: widget.condos
          .map(
            (c) => DropdownMenuItem<int>(
              value: _asInt(c['id']),
              child: Text(_condoLabel(c), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (onChanged ?? (v) => setState(() => _selectedCondoId = v)),
    );
  }

  Widget _buildUserDropdown({required String label}) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedUserId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.person_outline),
      ),
      items: widget.users
          .map(
            (u) => DropdownMenuItem<int>(
              value: _asInt(u['id']),
              child: Text(_userLabel(u), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _saving ? null : (v) => setState(() => _selectedUserId = v),
    );
  }
}
