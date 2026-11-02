import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class GenerateBoletoDialog extends StatefulWidget {
  const GenerateBoletoDialog({
    super.key,
    required this.condominiumId,
    required this.units,
    required this.api,
    required this.onGenerated,
  });

  final num condominiumId;
  final List<Map<String, dynamic>> units;
  final CommunityApi api;
  final VoidCallback onGenerated;

  @override
  State<GenerateBoletoDialog> createState() => _GenerateBoletoDialogState();
}

class _GenerateBoletoDialogState extends State<GenerateBoletoDialog> {
  num? _selectedUnitId;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.units.isNotEmpty) {
      _selectedUnitId = widget.units.first['id'] as num?;
    }
    final now = DateTime.now();
    _titleCtrl = TextEditingController(text: 'Taxa de Condomínio - ${now.month}/${now.year}');
    _amountCtrl = TextEditingController(text: '450.00');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
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
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_rounded, color: Color(0xFF15803D), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gerar Boleto Condominial',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        Text(
                          'Emita cobrança com código de barras para a unidade',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
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
              const SizedBox(height: 20),

              // Unit selector
              const Text('Selecione a Unidade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<num>(
                value: _selectedUnitId,
                items: widget.units.map((u) {
                  final sector = u['sector']?.toString() ?? '';
                  final idf = u['identifier']?.toString() ?? '';
                  final label = sector.isNotEmpty ? '$sector • Unidade $idf' : 'Unidade $idf';
                  return DropdownMenuItem<num>(
                    value: u['id'] as num?,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedUnitId = val),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
              const SizedBox(height: 14),

              // Title
              const Text('Descrição da Cobrança', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ex: Taxa Condominial Ordinária - Novembro/2026',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Amount & Due Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Valor (R\$)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            prefixText: 'R\$ ',
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
                        const Text('Vencimento', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDueDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Text(
                                  '${_dueDate.day.toString().padLeft(2, '0')}/${_dueDate.month.toString().padLeft(2, '0')}/${_dueDate.year}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ),

              // Submit
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(_submitting ? 'Gerando boleto...' : 'Gerar e Enviar Cobrança'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedUnitId == null) {
      setState(() => _error = 'Selecione a unidade.');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Informe um valor válido maior que zero.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.generateBoleto(
        widget.condominiumId,
        _selectedUnitId!,
        amount: amount,
        dueDate: _dueDate,
        title: _titleCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boleto gerado com sucesso!'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
      Navigator.of(context).pop();
      widget.onGenerated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Erro ao gerar boleto: $e';
      });
    }
  }
}
