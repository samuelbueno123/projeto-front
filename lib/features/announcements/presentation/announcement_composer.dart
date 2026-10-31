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
  late bool _wholeCondominium =
      widget.allowCondominiumWide && widget.initialUnit == null;
  Map<String, dynamic>? _unit;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
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
      (_wholeCondominium || _unit != null);

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
          if (!_wholeCondominium) 'unitId': _unit!['id'],
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
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.allowCondominiumWide) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.apartment_rounded),
                    label: Text('Todo o condomínio'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.home_outlined),
                    label: Text('Unidade específica'),
                  ),
                ],
                selected: {_wholeCondominium},
                onSelectionChanged: (value) =>
                    setState(() => _wholeCondominium = value.first),
              ),
              const SizedBox(height: 12),
            ],
            if (!_wholeCondominium) ...[
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
