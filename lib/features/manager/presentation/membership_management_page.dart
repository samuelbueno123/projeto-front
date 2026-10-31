import 'package:flutter/material.dart';

import '../../../core/widgets/enter_search_field.dart';
import '../../home/data/home_service.dart';

class MembershipManagementPage extends StatefulWidget {
  const MembershipManagementPage({
    super.key,
    required this.api,
    required this.condominiumId,
    this.isSystemAdmin = false,
  });

  final HomeService api;
  final int condominiumId;
  final bool isSystemAdmin;

  @override
  State<MembershipManagementPage> createState() =>
      _MembershipManagementPageState();
}

class _MembershipManagementPageState extends State<MembershipManagementPage> {
  final _emailController = TextEditingController();
  List<Map<String, dynamic>> _memberships = [];
  bool _loading = true;
  bool _sending = false;
  String _query = '';
  String _authority = 'ROLE_RESIDENT';
  String? _error;

  String get _collectionPath => widget.isSystemAdmin
      ? '/admin/condominiums/${widget.condominiumId}/managers'
      : '/manager/condominiums/${widget.condominiumId}/memberships';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.get(_collectionPath);
      final records = response is List
          ? response.whereType<Map<String, dynamic>>().toList()
          : response is Map && response['content'] is List
          ? (response['content'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _memberships = records;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _add() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um endereço de e-mail válido.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      if (widget.isSystemAdmin) {
        await widget.api.send('POST', _collectionPath, body: {'email': email});
      } else {
        await widget.api.send(
          'POST',
          '/manager/condominiums/${widget.condominiumId}/membership-invitations',
          body: {'email': email, 'authority': _authority},
        );
      }
      _emailController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isSystemAdmin
                  ? 'Síndico vinculado ao condomínio com sucesso!'
                  : 'Convite enviado! A pessoa receberá uma notificação para aceitar o acesso.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> membership) async {
    final membershipId = membership['id'];
    if (membershipId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.isSystemAdmin
              ? 'Remover síndico deste condomínio?'
              : 'Remover porteiro deste condomínio?',
        ),
        content: const Text(
          'A conta perderá imediatamente as permissões desta função neste condomínio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar remoção'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final path = widget.isSystemAdmin
          ? '$_collectionPath/$membershipId'
          : '/manager/condominiums/${widget.condominiumId}/memberships/$membershipId';
      await widget.api.send('DELETE', path);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  String _roleLabel(String? authority) => switch (authority) {
    'ROLE_MANAGER' => 'Síndico',
    'ROLE_DOORMAN' => 'Porteiro',
    'ROLE_RESIDENT' => 'Morador',
    _ => authority ?? 'Vínculo',
  };

  (String, Color, Color) _statusBadge(String? status) => switch (status) {
    'ACTIVE' => ('Ativo', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    'REQUESTED' => (
      'Solicitação de entrada',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'PENDING' => (
      'Aguardando aceite',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'DECLINED' => (
      'Recusado',
      const Color(0xFFFEE2E2),
      const Color(0xFFB91C1C),
    ),
    _ => ('Ativo', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
  };

  Future<void> _approveRequest(Map<String, dynamic> membership) async {
    final membershipId = membership['id'];
    try {
      await widget.api.send(
        'POST',
        '/manager/condominiums/${widget.condominiumId}/membership-requests/$membershipId/approve',
        body: {},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação de entrada aprovada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao aprovar: $e')));
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> membership) async {
    final membershipId = membership['id'];
    try {
      await widget.api.send(
        'POST',
        '/manager/condominiums/${widget.condominiumId}/membership-requests/$membershipId/reject',
        body: {},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação recusada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao recusar: $e')));
      }
    }
  }

  Future<void> _createSectorDialog() async {
    final name = TextEditingController();
    String structuralType = 'BLOCK';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Criar Novo Setor / Bloco'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome do Setor / Bloco *', hintText: 'Ex: Bloco C ou Torre Sul'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: structuralType,
                decoration: const InputDecoration(labelText: 'Tipo Estrutural'),
                items: const [
                  DropdownMenuItem(value: 'BLOCK', child: Text('Bloco')),
                  DropdownMenuItem(value: 'TOWER', child: Text('Torre')),
                  DropdownMenuItem(value: 'HOUSE_GROUP', child: Text('Grupo de Casas / Vilas')),
                ],
                onChanged: (v) => setD(() => structuralType = v ?? structuralType),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Criar Setor')),
          ],
        ),
      ),
    );

    if (ok == true && name.text.trim().isNotEmpty) {
      await widget.api.send(
        'POST',
        '/manager/condominiums/${widget.condominiumId}/sectors',
        body: {'name': name.text.trim(), 'structuralType': structuralType},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setor criado com sucesso!')));
      }
    }
  }

  Future<void> _createUnitDialog() async {
    final idCtrl = TextEditingController();
    List<Map<String, dynamic>> sectors = [];
    try {
      final res = await widget.api.get('/sectors?page=0&size=50');
      if (res is List) {
        sectors = res.whereType<Map<String, dynamic>>().toList();
      } else if (res is Map && res['content'] is List) {
        sectors = (res['content'] as List).whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}

    if (sectors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crie um setor antes de cadastrar uma unidade.')),
        );
      }
      return;
    }

    Map<String, dynamic> selectedSector = sectors.first;

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Criar Nova Unidade / Apto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedSector,
                decoration: const InputDecoration(labelText: 'Setor / Bloco'),
                items: sectors.map((s) => DropdownMenuItem(value: s, child: Text(s['name']?.toString() ?? 'Setor'))).toList(),
                onChanged: (v) => setD(() => selectedSector = v ?? selectedSector),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(labelText: 'Identificador da Unidade *', hintText: 'Ex: 101, 102, 201'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Criar Unidade')),
          ],
        ),
      ),
    );

    if (ok == true && idCtrl.text.trim().isNotEmpty) {
      await widget.api.send(
        'POST',
        '/manager/condominiums/${widget.condominiumId}/units',
        body: {'sectorId': selectedSector['id'], 'identifier': idCtrl.text.trim()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidade criada com sucesso!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _memberships
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
    final title = widget.isSystemAdmin
        ? 'Síndicos do condomínio'
        : 'Gestão de moradores e porteiros';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Criar Setor / Bloco',
            onPressed: _createSectorDialog,
            icon: const Icon(Icons.domain_add),
          ),
          IconButton(
            tooltip: 'Criar Unidade',
            onPressed: _createUnitDialog,
            icon: const Icon(Icons.add_home_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar lista',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFE0E7FF),
                            child: Icon(
                              widget.isSystemAdmin
                                  ? Icons.admin_panel_settings_outlined
                                  : Icons.person_add_alt_1_outlined,
                              color: const Color(0xFF2F3FB0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isSystemAdmin
                                      ? 'Atribuir novo síndico'
                                      : 'Convidar pessoa para o condomínio',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.isSystemAdmin
                                      ? 'Informe o e-mail de uma conta cadastrada para conceder acesso imediato de síndico.'
                                      : 'O convite chega nas notificações da pessoa e o acesso só é liberado após o aceite.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!widget.isSystemAdmin) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _authority,
                          decoration: const InputDecoration(
                            labelText: 'Função no condomínio',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ROLE_RESIDENT',
                              child: Text(
                                'Morador (acesso a encomendas e reservas)',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'ROLE_DOORMAN',
                              child: Text(
                                'Porteiro (gestão da portaria e encomendas)',
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _authority = value ?? _authority),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _sending ? null : _add(),
                        decoration: const InputDecoration(
                          labelText: 'E-mail da conta cadastrada',
                          hintText: 'Ex.: morador@email.com',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _sending ? null : _add,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                widget.isSystemAdmin
                                    ? Icons.verified_user_outlined
                                    : Icons.send_rounded,
                              ),
                        label: Text(
                          _sending
                              ? 'Processando…'
                              : widget.isSystemAdmin
                              ? 'Adicionar como síndico'
                              : 'Enviar convite por notificação',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isSystemAdmin
                    ? 'Síndicos vinculados'
                    : 'Pessoas vinculadas e convites enviados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              EnterSearchField(
                hintText: 'Pesquisar por nome, e-mail ou função (Enter)',
                onSubmitted: (query) => setState(() => _query = query),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text(
                        'Nenhum vínculo encontrado para este filtro.',
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map((membership) {
                  final authority = membership['authority']?.toString();
                  final removable = widget.isSystemAdmin
                      ? authority == 'ROLE_MANAGER'
                      : authority == 'ROLE_DOORMAN';
                  final name = membership['userName'] ?? membership['name'];
                  final email = membership['email'] ?? membership['userEmail'];
                  final status = membership['status']?.toString();
                  final (statusText, statusBg, statusFg) = _statusBadge(status);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFE0E7FF),
                            foregroundColor: const Color(0xFF2F3FB0),
                            child: Icon(
                              authority == 'ROLE_MANAGER'
                                  ? Icons.admin_panel_settings_outlined
                                  : authority == 'ROLE_DOORMAN'
                                  ? Icons.security_outlined
                                  : Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name?.toString() ??
                                      email?.toString() ??
                                      'Usuário',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if (email != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    email.toString(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8ECFF),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _roleLabel(authority),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2F3FB0),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: statusFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (status == 'REQUESTED') ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _approveRequest(membership),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Aprovar Vínculo'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFECACA)),
                              ),
                              onPressed: () => _rejectRequest(membership),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Recusar'),
                            ),
                          ] else if (removable)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(
                                  color: Color(0xFFFECACA),
                                ),
                              ),
                              onPressed: () => _remove(membership),
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                size: 18,
                              ),
                              label: const Text('Remover'),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
