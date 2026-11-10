import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class RenovationRequestDialog extends StatefulWidget {
  const RenovationRequestDialog({
    super.key,
    required this.condominiumId,
    required this.units,
    required this.api,
    this.onRequestCreated,
  });

  final num condominiumId;
  final List<Map<String, dynamic>> units;
  final CommunityApi api;
  final VoidCallback? onRequestCreated;

  @override
  State<RenovationRequestDialog> createState() => _RenovationRequestDialogState();
}

class _RenovationRequestDialogState extends State<RenovationRequestDialog> {
  num? _selectedUnitId;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _artCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _noiseLevel = 'MEDIUM';
  DateTime _startDate = DateTime.now().add(const Duration(days: 2));
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.units.isNotEmpty) {
      _selectedUnitId = widget.units.first['id'] as num?;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _artCtrl.dispose();
    _contractorCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Informe o título da obra ou reforma.');
      return;
    }
    if (_selectedUnitId == null) {
      setState(() => _error = 'Selecione a unidade correspondente.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.api.requestRenovation(widget.condominiumId, {
        'unitId': _selectedUnitId,
        'title': title,
        'description': _descCtrl.text.trim(),
        'artRrtNumber': _artCtrl.text.trim(),
        'contractorName': _contractorCtrl.text.trim(),
        'contractorPhone': _phoneCtrl.text.trim(),
        'startDate': '${_startDate.year.toString().padLeft(4, '0')}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
        'expectedEndDate': '${_endDate.year.toString().padLeft(4, '0')}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
        'noiseLevel': _noiseLevel,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRequestCreated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Erro ao enviar solicitação: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: Color(0xFFB45309), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitação de Obra / Reforma',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        Text(
                          'Conformidade com a ABNT NBR 16.280',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Unit
              const Text('Unidade Residencial *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<num>(
                isExpanded: true,
                value: _selectedUnitId,
                items: widget.units.map((u) {
                  final sec = u['sector']?.toString() ?? '';
                  final idf = u['identifier']?.toString() ?? '';
                  return DropdownMenuItem<num>(
                    value: u['id'] as num?,
                    child: Text(sec.isNotEmpty ? '$sec • Unidade $idf' : 'Unidade $idf'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedUnitId = val),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
              const SizedBox(height: 14),

              // Title
              const Text('Título / Escopo Principal *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ex.: Reforma completa de cozinha e banheiro',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // ART/RRT & Noise
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ART / RRT Técnico', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _artCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Nº do Registro',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nível de Ruído', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _noiseLevel,
                          items: const [
                            DropdownMenuItem(value: 'LOW', child: Text('Baixo (Pintura)')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Médio (Marcenaria)')),
                            DropdownMenuItem(value: 'HIGH', child: Text('Alto (Quebradeira)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _noiseLevel = val);
                          },
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Contractor
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Empresa / Responsável', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _contractorCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Nome do empreiteiro',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Telefone da Equipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '(XX) 9XXXX-XXXX',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(_submitting ? 'Enviando solicitação...' : 'Enviar para Aprovação do Síndico'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
