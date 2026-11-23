import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/saas_design_system.dart';
import '../../home/data/home_service.dart';

/// Opens the governed, schema-driven Admin Database Record Editor.
/// Loads `/admin/data/{resource}/schema` (and `/{id}` when editing), renders
/// typed controls + async searchable relation pickers + immutable field guards,
/// and enforces a mandatory Before -> After diff preview + audit reason before saving.
Future<Map<String, dynamic>?> showSchemaAdminRecordDialog({
  required BuildContext context,
  required HomeService api,
  required String resource,
  String? title,
  Map<String, dynamic>? existingItem,
}) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdminSchemaRecordDialog(
      api: api,
      resource: resource,
      title: title,
      existingItem: existingItem,
    ),
  );
}

class AdminSchemaRecordDialog extends StatefulWidget {
  const AdminSchemaRecordDialog({
    super.key,
    required this.api,
    required this.resource,
    this.title,
    this.existingItem,
  });

  final HomeService api;
  final String resource;
  final String? title;
  final Map<String, dynamic>? existingItem;

  @override
  State<AdminSchemaRecordDialog> createState() =>
      _AdminSchemaRecordDialogState();
}

class _AdminSchemaRecordDialogState extends State<AdminSchemaRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  final Map<String, String> _relationLabels = {};

  Map<String, dynamic>? _schema;
  Map<String, dynamic>? _beforeRecord;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _submitError;

  bool get _isEdit => widget.existingItem?['id'] != null;
  num? get _recordId => widget.existingItem?['id'] as num?;

  @override
  void initState() {
    super.initState();
    _loadSchemaAndRecord();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSchemaAndRecord() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final futures = <Future<dynamic>>[
        widget.api.get('/admin/data/${widget.resource}/schema'),
        if (_isEdit) widget.api.get('/admin/data/${widget.resource}/$_recordId'),
      ];
      final results = await Future.wait(futures);
      final rawSchema = results[0];
      if (rawSchema is! Map<String, dynamic>) {
        throw Exception('Schema inválido para ${widget.resource}');
      }
      final record = _isEdit && results.length > 1 && results[1] is Map<String, dynamic>
          ? Map<String, dynamic>.from(results[1] as Map)
          : (widget.existingItem != null
              ? Map<String, dynamic>.from(widget.existingItem!)
              : <String, dynamic>{});

      final fields = (rawSchema['fields'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];

      for (final ctrl in _controllers.values) {
        ctrl.dispose();
      }
      _controllers.clear();
      _values.clear();
      _relationLabels.clear();

      for (final field in fields) {
        final name = field['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        final type = (field['type']?.toString() ?? 'STRING').toUpperCase();
        final rawVal = _isEdit ? record[name] : field['defaultValue'];
        if (type == 'MULTI_ENUM') {
          _values[name] = rawVal is Iterable
              ? rawVal.map((e) => e.toString()).toSet()
              : <String>{};
        } else if (type == 'BOOLEAN') {
          _values[name] = rawVal == true;
        } else if (type == 'ENUM') {
          _values[name] = rawVal?.toString();
        } else if (type == 'RELATION') {
          _values[name] = rawVal;
          if (rawVal != null) {
            final labelKey = name.endsWith('Id')
                ? '${name.substring(0, name.length - 2)}Name'
                : '${name}Name';
            final altEmailKey = name.endsWith('Id')
                ? '${name.substring(0, name.length - 2)}Email'
                : '';
            final label = record[labelKey]?.toString() ??
                (altEmailKey.isNotEmpty ? record[altEmailKey]?.toString() : null) ??
                record['condominiumName']?.toString();
            _relationLabels[name] = label != null && label.isNotEmpty
                ? '#$rawVal • $label'
                : 'ID #$rawVal';
          }
        } else {
          final textVal = rawVal?.toString() ?? '';
          _values[name] = textVal;
          _controllers[name] = TextEditingController(text: textVal);
        }
      }

      if (!mounted) return;
      setState(() {
        _schema = rawSchema;
        _beforeRecord = _isEdit ? record : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _fields =>
      (_schema?['fields'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      const [];

  bool _isFieldEditable(Map<String, dynamic> field) {
    if (_schema?['immutableLedger'] == true) return false;
    final editable = field['editable'] != false;
    final immutableOnUpdate = field['immutableOnUpdate'] == true;
    return editable && !(_isEdit && immutableOnUpdate);
  }

  dynamic _currentValueForField(Map<String, dynamic> field) {
    final name = field['name']?.toString() ?? '';
    final type = (field['type']?.toString() ?? 'STRING').toUpperCase();
    if (_controllers.containsKey(name)) {
      final rawText = _controllers[name]!.text.trim();
      if (rawText.isEmpty) return null;
      if (type == 'INTEGER') return int.tryParse(rawText) ?? rawText;
      if (type == 'DECIMAL') {
        return num.tryParse(rawText.replaceAll(',', '.')) ?? rawText;
      }
      return rawText;
    }
    final val = _values[name];
    if (val is Set<String>) return val.toList()..sort();
    return val;
  }

  Map<String, dynamic> _collectPayload() {
    final payload = <String, dynamic>{};
    for (final field in _fields) {
      if (!_isFieldEditable(field)) continue;
      final name = field['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final val = _currentValueForField(field);
      if (_isEdit && _beforeRecord != null) {
        final prev = _normalizeCompare(_beforeRecord![name]);
        final next = _normalizeCompare(val);
        if (prev == next) continue;
      } else if (val == null) {
        continue;
      }
      payload[name] = val;
    }
    return payload;
  }

  String _normalizeCompare(dynamic raw) {
    if (raw == null) return '';
    if (raw is Iterable) {
      final list = raw.map((e) => e.toString()).toList()..sort();
      return list.join(',');
    }
    return raw.toString().trim();
  }

  List<_DiffRow> _buildDiffRows(Map<String, dynamic> payload) {
    final rows = <_DiffRow>[];
    for (final field in _fields) {
      final name = field['name']?.toString() ?? '';
      if (!payload.containsKey(name)) continue;
      final label = field['label']?.toString() ?? name;
      final beforeVal = _beforeRecord?[name];
      final afterVal = payload[name];
      rows.add(
        _DiffRow(
          label: label,
          beforeText: _formatDisplayValue(beforeVal),
          afterText: _formatDisplayValue(afterVal),
        ),
      );
    }
    return rows;
  }

  String _formatDisplayValue(dynamic raw) {
    if (raw == null) return '(vazio)';
    if (raw is Iterable) {
      final items = raw.map((e) => e.toString()).toList();
      return items.isEmpty ? '(nenhum)' : items.join(', ');
    }
    if (raw is bool) return raw ? 'Sim' : 'Não';
    final s = raw.toString().trim();
    return s.isEmpty ? '(vazio)' : s;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final payload = _collectPayload();
    if (_isEdit && payload.isEmpty) {
      setState(() => _submitError = 'Nenhuma alteração detectada neste registro.');
      return;
    }

    String? reason;
    if (_isEdit) {
      final requiresReason = _schema?['requiresReason'] == true;
      reason = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DiffConfirmationDialog(
          title: 'Confirmar Alteração Auditada',
          diffs: _buildDiffRows(payload),
          requiresReason: requiresReason,
        ),
      );
      if (reason == null) return;
    }

    setState(() {
      _saving = true;
      _submitError = null;
    });

    try {
      final body = <String, dynamic>{
        'data': payload,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };
      final response = _isEdit
          ? await widget.api.send(
              'PUT',
              '/admin/data/${widget.resource}/$_recordId',
              body: body,
            )
          : await widget.api.send(
              'POST',
              '/admin/data/${widget.resource}',
              body: body,
            );
      if (!mounted) return;
      final out = response is Map<String, dynamic>
          ? response
          : <String, dynamic>{'status': 'OK'};
      Navigator.of(context).pop(out);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _submitError = e.toString();
      });
    }
  }

  Future<void> _deleteRecord() async {
    if (!_isEdit || _recordId == null) return;
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DiffConfirmationDialog(
        title: 'Confirmar Exclusão Auditada',
        diffs: [],
        requiresReason: true,
        isDelete: true,
      ),
    );
    if (reason == null) return;

    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      final res = await widget.api.send(
        'DELETE',
        '/admin/data/${widget.resource}/$_recordId?reason=${Uri.encodeQueryComponent(reason.trim())}',
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        res is Map<String, dynamic> ? res : <String, dynamic>{'deleted': true},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _submitError = e.toString();
      });
    }
  }

  Future<void> _pickRelation(Map<String, dynamic> field) async {
    final name = field['name']?.toString() ?? '';
    final relationResource = field['relationResource']?.toString() ?? '';
    final displayField = field['relationDisplayField']?.toString() ?? 'name';
    if (relationResource.isEmpty) return;

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AsyncRelationPickerDialog(
        api: widget.api,
        relationResource: relationResource,
        displayField: displayField,
        label: field['label']?.toString() ?? name,
      ),
    );
    if (selected == null || !mounted) return;
    final id = selected['id'];
    final labelVal = selected[displayField] ??
        selected['name'] ??
        selected['email'] ??
        selected['identifier'] ??
        'ID #$id';
    setState(() {
      _values[name] = id;
      _relationLabels[name] = '#$id • $labelVal';
    });
  }

  Future<void> _pickDate(String name) async {
    final currentText = _controllers[name]?.text ?? '';
    final initial = DateTime.tryParse(currentText) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      _controllers[name]?.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _schema?['label']?.toString() ?? widget.title ?? widget.resource;
    final immutableLedger = _schema?['immutableLedger'] == true;
    final canSave = _isEdit
        ? (_schema?['editable'] == true && !immutableLedger)
        : (_schema?['creatable'] == true && !immutableLedger);
    final canDelete = _isEdit && (_schema?['deletable'] == true && !immutableLedger);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: SaaSColors.primary.withValues(alpha: 0.14),
            child: Icon(
              _isEdit ? Icons.edit_note_rounded : Icons.add_box_outlined,
              color: SaaSColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Editar $label (#$_recordId)' : 'Novo em $label',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Editor Estruturado • Validação & Auditoria',
                  style: TextStyle(
                    fontSize: 12,
                    color: SaaSColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: SaaSLoadingState(message: 'Carregando schema do recurso...'),
              )
            : _loadError != null
            ? SaaSErrorState(
                message: _loadError!,
                onRetry: _loadSchemaAndRecord,
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (immutableLedger)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SaaSColors.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: SaaSColors.warning.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'Ledger imutável: registros de auditoria não podem ser alterados ou removidos.',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ),
                      if (_submitError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SaaSColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: SaaSColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            _submitError!,
                            style: const TextStyle(
                              color: SaaSColors.error,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ..._fields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFieldControl(field, isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        if (canDelete)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: SaaSColors.error),
            onPressed: _saving ? null : _deleteRecord,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Excluir'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (!_loading && _loadError == null && canSave)
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isEdit ? Icons.fact_check_outlined : Icons.check_rounded,
                    size: 18,
                  ),
            label: Text(_isEdit ? 'Revisar Diff & Salvar' : 'Criar Registro'),
          ),
      ],
    );
  }

  Widget _buildFieldControl(Map<String, dynamic> field, bool isDark) {
    final name = field['name']?.toString() ?? '';
    final label = field['label']?.toString() ?? name;
    final type = (field['type']?.toString() ?? 'STRING').toUpperCase();
    final requiredField = field['required'] == true;
    final editable = _isFieldEditable(field);
    final helper = field['helperText']?.toString();

    if (type == 'PASSWORD' && _isEdit) {
      return _buildReadOnlyChip(label, 'Protegida (alterável apenas pelo titular)');
    }

    if (!editable) {
      return _buildReadOnlyChip(
        label,
        _relationLabels[name] ??
            _formatDisplayValue(_values[name] ?? _controllers[name]?.text),
        helper: helper,
      );
    }

    if (type == 'BOOLEAN') {
      return SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: SaaSColors.border(isDark)),
        ),
        title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        subtitle: helper != null ? Text(helper, style: const TextStyle(fontSize: 11.5)) : null,
        value: _values[name] == true,
        onChanged: (v) => setState(() => _values[name] = v),
      );
    }

    if (type == 'ENUM') {
      final options = (field['enumOptions'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      final current = _values[name]?.toString();
      final validValue = options.any((o) => o['value']?.toString() == current)
          ? current
          : null;
      return DropdownButtonFormField<String>(
        initialValue: validValue,
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          helperText: helper,
        ),
        items: options
            .map(
              (o) => DropdownMenuItem<String>(
                value: o['value']?.toString(),
                child: Text(o['label']?.toString() ?? o['value'].toString()),
              ),
            )
            .toList(),
        validator: requiredField
            ? (v) => (v == null || v.isEmpty) ? 'Selecione uma opção.' : null
            : null,
        onChanged: (v) => setState(() => _values[name] = v),
      );
    }

    if (type == 'MULTI_ENUM') {
      final options = (field['enumOptions'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      final selected = (_values[name] as Set<String>?) ?? <String>{};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiredField ? '$label *' : label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((o) {
              final val = o['value']?.toString() ?? '';
              final optLabel = o['label']?.toString() ?? val;
              final isSelected = selected.contains(val);
              return FilterChip(
                label: Text(optLabel, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                onSelected: (on) {
                  setState(() {
                    final next = Set<String>.from(selected);
                    if (on) {
                      next.add(val);
                    } else {
                      next.remove(val);
                    }
                    _values[name] = next;
                  });
                },
              );
            }).toList(),
          ),
        ],
      );
    }

    if (type == 'RELATION') {
      final display = _relationLabels[name] ??
          (_values[name] != null ? 'ID #${_values[name]}' : 'Nenhum selecionado');
      return InputDecorator(
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          helperText: helper,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!requiredField && _values[name] != null)
                IconButton(
                  tooltip: 'Limpar vínculo',
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() {
                    _values[name] = null;
                    _relationLabels.remove(name);
                  }),
                ),
              IconButton(
                tooltip: 'Buscar ${field['relationResource']}',
                icon: const Icon(Icons.search_rounded),
                onPressed: () => _pickRelation(field),
              ),
            ],
          ),
        ),
        child: InkWell(
          onTap: () => _pickRelation(field),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              display,
              style: TextStyle(
                color: _values[name] == null ? SaaSColors.muted(context) : null,
                fontWeight: _values[name] == null ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final ctrl = _controllers[name]!;
    return TextFormField(
      controller: ctrl,
      obscureText: type == 'PASSWORD',
      maxLines: type == 'TEXT' ? 3 : 1,
      maxLength: field['maxLength'] as int?,
      keyboardType: switch (type) {
        'INTEGER' => TextInputType.number,
        'DECIMAL' => const TextInputType.numberWithOptions(decimal: true),
        'EMAIL' => TextInputType.emailAddress,
        _ => TextInputType.text,
      },
      readOnly: type == 'DATE',
      onTap: type == 'DATE' ? () => _pickDate(name) : null,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        helperText: helper,
        counterText: '',
        suffixIcon: type == 'DATE' ? const Icon(Icons.calendar_today_outlined, size: 18) : null,
      ),
      validator: (raw) {
        final v = raw?.trim() ?? '';
        if (requiredField && v.isEmpty) return 'Campo obrigatório.';
        if (v.isEmpty) return null;
        if (type == 'EMAIL' && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
          return 'Informe um e-mail válido.';
        }
        if (type == 'INTEGER' && int.tryParse(v) == null) {
          return 'Informe um número inteiro válido.';
        }
        if (type == 'DECIMAL' && num.tryParse(v.replaceAll(',', '.')) == null) {
          return 'Informe um valor decimal válido.';
        }
        if (type == 'PASSWORD' && v.length < 8) {
          return 'A senha deve ter pelo menos 8 caracteres.';
        }
        return null;
      },
    );
  }

  Widget _buildReadOnlyChip(String label, String value, {String? helper}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaaSColors.border(isDark)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label • Somente leitura',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: SaaSColors.muted(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (helper != null)
                  Text(
                    helper,
                    style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffRow {
  const _DiffRow({
    required this.label,
    required this.beforeText,
    required this.afterText,
  });

  final String label;
  final String beforeText;
  final String afterText;
}

class _DiffConfirmationDialog extends StatefulWidget {
  const _DiffConfirmationDialog({
    required this.title,
    required this.diffs,
    required this.requiresReason,
    this.isDelete = false,
  });

  final String title;
  final List<_DiffRow> diffs;
  final bool requiresReason;
  final bool isDelete;

  @override
  State<_DiffConfirmationDialog> createState() =>
      _DiffConfirmationDialogState();
}

class _DiffConfirmationDialogState extends State<_DiffConfirmationDialog> {
  final _reasonCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isDelete)
              const Text(
                'Esta operação removerá o registro permanentemente e ficará gravada na trilha imutável de auditoria.',
                style: TextStyle(color: SaaSColors.error, fontWeight: FontWeight.w600),
              )
            else ...[
              const Text(
                'Revise as alterações que serão registradas na auditoria (Antes → Depois):',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.diffs.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, idx) {
                    final d = widget.diffs[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.label,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: SaaSColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                d.beforeText,
                                style: const TextStyle(fontSize: 12, color: SaaSColors.error),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: SaaSColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                d.afterText,
                                style: const TextStyle(fontSize: 12, color: SaaSColors.success),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: widget.requiresReason
                    ? 'Motivo operacional (Auditoria) *'
                    : 'Motivo operacional (opcional)',
                hintText: 'Ex.: Correção cadastral solicitada pelo síndico',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          style: widget.isDelete
              ? FilledButton.styleFrom(backgroundColor: SaaSColors.error)
              : null,
          onPressed: () {
            final r = _reasonCtrl.text.trim();
            if (widget.requiresReason && r.isEmpty) {
              setState(() => _error = 'Informe o motivo para a auditoria.');
              return;
            }
            Navigator.of(context).pop(r);
          },
          child: Text(widget.isDelete ? 'Confirmar Exclusão' : 'Confirmar & Gravar'),
        ),
      ],
    );
  }
}

class _AsyncRelationPickerDialog extends StatefulWidget {
  const _AsyncRelationPickerDialog({
    required this.api,
    required this.relationResource,
    required this.displayField,
    required this.label,
  });

  final HomeService api;
  final String relationResource;
  final String displayField;
  final String label;

  @override
  State<_AsyncRelationPickerDialog> createState() =>
      _AsyncRelationPickerDialogState();
}

class _AsyncRelationPickerDialogState extends State<_AsyncRelationPickerDialog> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = query.trim();
      final res = await widget.api.get(
        '/admin/data/${widget.relationResource}?page=0&size=20&sort=id,asc${q.isEmpty ? '' : '&query=${Uri.encodeQueryComponent(q)}'}',
      );
      if (!mounted) return;
      final content = res is Map && res['content'] is List
          ? (res['content'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : (res is List
              ? res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[]);
      setState(() {
        _items = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Selecionar ${widget.label}'),
      content: SizedBox(
        width: 440,
        height: 380,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Filtrar registros remotamente...',
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 280),
                  () => _fetch(v),
                );
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _items.isEmpty
                  ? const Center(child: Text('Nenhum registro encontrado.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, idx) {
                        final item = _items[idx];
                        final id = item['id'];
                        final primary = item[widget.displayField]?.toString() ??
                            item['name']?.toString() ??
                            item['email']?.toString() ??
                            item['identifier']?.toString() ??
                            'Registro #$id';
                        final secondary = item['email']?.toString() ??
                            item['condominiumName']?.toString() ??
                            item['address']?.toString() ??
                            'ID #$id';
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text('$id', style: const TextStyle(fontSize: 11)),
                          ),
                          title: Text(primary),
                          subtitle: secondary == primary ? null : Text(secondary),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
