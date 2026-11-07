import 'package:flutter/material.dart';

import '../../directory/presentation/unit_directory.dart';
import '../../home/data/home_service.dart';

/// Dialog to publish an announcement. Managers may target the whole
/// condominium or one unit ([allowCondominiumWide] = true); doormen can only
/// target a specific unit.
///
/// Returns `true` when the announcement was sent.
Future<bool> showAnnouncementComposer(
  BuildContext context, {
  required HomeService api,
  required DirectoryApi directory,
  required bool allowCondominiumWide,
  Map<String, dynamic>? initialUnit,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _AnnouncementComposerDialog(
      api: api,
      directory: directory,
      allowCondominiumWide: allowCondominiumWide,
      initialUnit: initialUnit,
    ),
  );
  return sent == true;
}

class _AnnouncementComposerDialog extends StatefulWidget {
  const _AnnouncementComposerDialog({
    required this.api,
    required this.directory,
    required this.allowCondominiumWide,
    this.initialUnit,
  });

  final HomeService api;
  final DirectoryApi directory;
  final bool allowCondominiumWide;
  final Map<String, dynamic>? initialUnit;

  @override
  State<_AnnouncementComposerDialog> createState() =>
      _AnnouncementComposerDialogState();
}

class _AnnouncementComposerDialogState
    extends State<_AnnouncementComposerDialog> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  late String _targetType =
      (widget.allowCondominiumWide && widget.initialUnit == null) ? 'ALL' : 'UNIT';
  Map<String, dynamic>? _unit;
  List<Map<String, dynamic>> _sectors = [];
  num? _selectedSectorId;
  String _selectedRole = 'ROLE_RESIDENT';
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    if (widget.allowCondominiumWide) {
      _loadSectors();
    }
  }

  Future<void> _loadSectors() async {
    try {
      final res = await widget.api.get('/manager/condominiums/${widget.directory.condominiumId}/sectors');
      final list = res is List
          ? res.whereType<Map<String, dynamic>>().toList()
          : (res is Map && res['content'] is List
              ? (res['content'] as List).whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[]);
      if (mounted) {
        setState(() {
          _sectors = list;
          if (_sectors.isNotEmpty) {
            _selectedSectorId = _sectors.first['id'] as num?;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending &&
      _title.text.trim().isNotEmpty &&
      _content.text.trim().isNotEmpty &&
      (_targetType == 'ALL' ||
          (_targetType == 'UNIT' && _unit != null) ||
          (_targetType == 'SECTOR' && _selectedSectorId != null) ||
          _targetType == 'ROLE');

  Future<void> _pickUnit() async {
    final selection = await showUnitResidentPicker(
      context,
      directory: widget.directory,
      pickResident: false,
      title: 'Unidade destinatária',
    );
    if (selection != null) setState(() => _unit = selection.unit);
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.send(
        'POST',
        '/condominiums/${widget.directory.condominiumId}/announcements',
        body: {
          'title': _title.text.trim(),
          'content': _content.text.trim(),
          if (_targetType == 'UNIT' && _unit != null) 'unitId': _unit!['id'],
          if (_targetType == 'SECTOR' && _selectedSectorId != null) 'sectorId': _selectedSectorId,
          if (_targetType == 'ROLE') 'targetRole': _selectedRole,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        CircleAvatar(
          backgroundColor: Color(0xFFFEF3C7),
          child: Icon(Icons.campaign_outlined, color: Color(0xFFD97706)),
        ),
        SizedBox(width: 12),
        Expanded(child: Text('Enviar comunicado')),
      ],
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.allowCondominiumWide) ...[
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(
                  labelText: 'Segmentação / Destinatários',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text('Todo o condomínio'),
                  ),
                  if (_sectors.isNotEmpty)
                    const DropdownMenuItem(
                      value: 'SECTOR',
                      child: Text('Bloco / Setor específico'),
                    ),
                  const DropdownMenuItem(
                    value: 'ROLE',
                    child: Text('Perfil específico (Moradores / Portaria)'),
                  ),
                  const DropdownMenuItem(
                    value: 'UNIT',
                    child: Text('Unidade específica'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _targetType = value ?? 'ALL'),
              ),
              const SizedBox(height: 12),
            ],
            if (_targetType == 'SECTOR' && _sectors.isNotEmpty) ...[
              DropdownButtonFormField<num>(
                value: _selectedSectorId,
                decoration: const InputDecoration(
                  labelText: 'Bloco / Setor destinatário',
                  prefixIcon: Icon(Icons.domain_outlined),
                ),
                items: _sectors
                    .map(
                      (s) => DropdownMenuItem<num>(
                        value: s['id'] as num?,
                        child: Text(s['name']?.toString() ?? 'Bloco'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedSectorId = val),
              ),
              const SizedBox(height: 12),
            ],
            if (_targetType == 'ROLE') ...[
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Perfil destinatário',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ROLE_RESIDENT',
                    child: Text('Somente Moradores'),
                  ),
                  DropdownMenuItem(
                    value: 'ROLE_DOORMAN',
                    child: Text('Somente Portaria / Funcionários'),
                  ),
                ],
                onChanged: (val) =>
                    setState(() => _selectedRole = val ?? 'ROLE_RESIDENT'),
              ),
              const SizedBox(height: 12),
            ],
            if (_targetType == 'UNIT') ...[
              OutlinedButton.icon(
                onPressed: _sending ? null : _pickUnit,
                icon: const Icon(Icons.home_work_outlined),
                label: Text(
                  _unit == null
                      ? 'Escolher a unidade destinatária'
                      : unitLabel(_unit!),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _title,
              maxLength: 150,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Título *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _content,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Mensagem *',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        onPressed: _canSend ? _send : null,
        icon: _sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_rounded),
        label: const Text('Enviar'),
      ),
    ],
  );
}
