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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um email válido.')));
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
                  ? 'Síndico adicionado ao condomínio.'
                  : 'Convite enviado. O usuário precisa aceitá-lo pela notificação.',
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
          widget.isSystemAdmin ? 'Remover síndico?' : 'Remover porteiro?',
        ),
        content: const Text(
          'A pessoa perderá o acesso correspondente a este condomínio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _memberships
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
    final title = widget.isSystemAdmin
        ? 'Síndicos do condomínio'
        : 'Moradores e porteiros';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.isSystemAdmin
                ? 'Adicione uma conta existente como síndico deste condomínio.'
                : 'Convide moradores ou porteiros pelo email cadastrado. O acesso só é ativado depois do aceite na notificação.',
          ),
          const SizedBox(height: 16),
          if (!widget.isSystemAdmin)
            DropdownButtonFormField<String>(
              initialValue: _authority,
              decoration: const InputDecoration(labelText: 'Tipo de vínculo'),
              items: const [
                DropdownMenuItem(
                  value: 'ROLE_RESIDENT',
                  child: Text('Morador'),
                ),
                DropdownMenuItem(
                  value: 'ROLE_DOORMAN',
                  child: Text('Porteiro'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _authority = value ?? _authority),
            ),
          if (!widget.isSystemAdmin) const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sending ? null : _add(),
            decoration: InputDecoration(
              labelText: 'Email da pessoa',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Enviar convite',
                onPressed: _sending ? null : _add,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          EnterSearchField(
            hintText: 'Pesquisar por email ou papel',
            onSubmitted: (query) => setState(() => _query = query),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              ],
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhum vínculo encontrado.'),
            )
          else
            ...filtered.map((membership) {
              final authority = membership['authority']?.toString();
              final removable = widget.isSystemAdmin
                  ? authority == 'ROLE_MANAGER'
                  : authority == 'ROLE_DOORMAN';
              final name = membership['userName'] ?? membership['name'];
              final email = membership['email'] ?? membership['userEmail'];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(
                    name?.toString() ?? email?.toString() ?? 'Usuário',
                  ),
                  subtitle: Text(
                    '${email == null ? '' : '$email · '}${_roleLabel(authority)}${membership['status'] == null ? '' : ' · ${membership['status']}'}',
                  ),
                  trailing: removable
                      ? IconButton(
                          tooltip: 'Remover vínculo',
                          onPressed: () => _remove(membership),
                          icon: const Icon(Icons.person_remove_outlined),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
