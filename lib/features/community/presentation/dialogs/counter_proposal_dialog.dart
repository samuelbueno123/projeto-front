import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class CounterProposalDialog extends StatefulWidget {
  const CounterProposalDialog({
    super.key,
    required this.reservation,
    required this.api,
    required this.onSubmitted,
  });

  final Map<String, dynamic> reservation;
  final CommunityApi api;
  final VoidCallback onSubmitted;

  @override
  State<CounterProposalDialog> createState() => _CounterProposalDialogState();
}

class _CounterProposalDialogState extends State<CounterProposalDialog> {
  late DateTime _proposedDate;
  late TimeOfDay _proposedStartTime;
  late TimeOfDay _proposedEndTime;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rawStart = widget.reservation['startAt']?.toString();
    final dt = rawStart != null ? DateTime.tryParse(rawStart) ?? DateTime.now() : DateTime.now();
    _proposedDate = dt;
    _proposedStartTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    _proposedEndTime = TimeOfDay(hour: (dt.hour + 4) % 24, minute: dt.minute);
    _notesCtrl.text = 'Sugerimos este horário alternativo para melhor acomodar seu evento.';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final areaName = widget.reservation['commonAreaName']?.toString() ??
        widget.reservation['commonArea']?.toString() ??
        'Área Comum';
    final residentName = widget.reservation['residentName']?.toString() ??
        widget.reservation['reservedByName']?.toString() ??
        'Morador';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFFB45309), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enviar Contraproposta',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        Text(
                          '$areaName • $residentName',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
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

              // Date picker
              const Text('Data Proposta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      Text(
                        '${_proposedDate.day.toString().padLeft(2, '0')}/${_proposedDate.month.toString().padLeft(2, '0')}/${_proposedDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Time pickers
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Início Proposto', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Text(_proposedStartTime.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
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
                        const Text('Término Proposto', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Text(_proposedEndTime.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Justification note
              const Text('Mensagem / Justificativa para o Morador', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Explique o motivo do ajuste de horário sugerido...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

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
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_submitting ? 'Enviando contraproposta...' : 'Enviar Contraproposta ao Morador'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _proposedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _proposedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _proposedStartTime);
    if (picked != null) setState(() => _proposedStartTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _proposedEndTime);
    if (picked != null) setState(() => _proposedEndTime = picked);
  }

  Future<void> _submit() async {
    final resId = widget.reservation['id'] as num?;
    if (resId == null) return;

    final startAt = DateTime(
      _proposedDate.year,
      _proposedDate.month,
      _proposedDate.day,
      _proposedStartTime.hour,
      _proposedStartTime.minute,
    );
    final endAt = DateTime(
      _proposedDate.year,
      _proposedDate.month,
      _proposedDate.day,
      _proposedEndTime.hour,
      _proposedEndTime.minute,
    );

    if (!endAt.isAfter(startAt)) {
      setState(() => _error = 'O horário de término deve ser posterior ao de início.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.api.counterProposeReservation(
        reservationId: resId,
        proposedStartAt: startAt,
        proposedEndAt: endAt,
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraproposta enviada com sucesso! O morador foi notificado.'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
      Navigator.of(context).pop();
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Erro ao enviar contraproposta: $e';
      });
    }
  }
}
