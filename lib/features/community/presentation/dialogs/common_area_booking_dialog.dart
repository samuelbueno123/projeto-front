import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/community_api.dart';

class CommonAreaBookingDialog extends StatefulWidget {
  const CommonAreaBookingDialog({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<CommonAreaBookingDialog> createState() => _CommonAreaBookingDialogState();
}

class _CommonAreaBookingDialogState extends State<CommonAreaBookingDialog> {
  bool _loadingAreas = true;
  List<Map<String, dynamic>> _areas = [];
  Map<String, dynamic>? _selectedArea;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  int _durationHours = 4;
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  bool _checkingAvailability = false;
  bool? _isAvailable;
  bool _allowWaitlist = true;
  int _waitlistCount = 0;
  String? _availabilityMessage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    try {
      final res = await widget.api.api.get('/condominiums/${widget.condominiumId}/common-areas');
      final list = res is List ? res.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _areas = list.where((a) => a['active'] != false).toList();
        if (_areas.isNotEmpty) {
          _selectedArea = _areas.first;
        }
        _loadingAreas = false;
      });
      if (_selectedArea != null) {
        _checkAvailability();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _endDateTime => _startDateTime.add(Duration(hours: _durationHours));

  Future<void> _checkAvailability() async {
    if (_selectedArea == null) return;
    setState(() {
      _checkingAvailability = true;
      _isAvailable = null;
      _availabilityMessage = null;
    });

    try {
      final res = await widget.api.checkAreaAvailability(
        areaId: _selectedArea!['id'],
        startAt: _startDateTime,
        endAt: _endDateTime,
      );
      if (!mounted) return;
      setState(() {
        _isAvailable = res['available'] == true;
        _allowWaitlist = res['allowWaitlist'] != false;
        _waitlistCount = (res['waitlistCount'] is num) ? (res['waitlistCount'] as num).toInt() : 0;
        _availabilityMessage = res['message']?.toString() ??
            (_isAvailable == true
                ? 'Espaço livre e disponível para agendamento!'
                : 'Horário já reservado.${_allowWaitlist ? ' Lista de espera disponível ($_waitlistCount na fila).' : ''}');
        _checkingAvailability = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAvailable = false;
        _availabilityMessage = 'Erro ao verificar disponibilidade: $e';
        _checkingAvailability = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedArea == null) return;
    final phoneErr = validatePhone(_phoneController.text);
    if (phoneErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phoneErr)));
      return;
    }
    if (_isAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um horário disponível antes de prosseguir.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await widget.api.requestReservation(
        areaId: _selectedArea!['id'],
        startAt: _startDateTime,
        endAt: _endDateTime,
        contactPhone: _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (!mounted) return;
      final status = res['status']?.toString();
      final isPending = status == 'PENDING';

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isPending ? const Color(0xFFB45309) : const Color(0xFF15803D),
          content: Text(
            isPending
                ? 'Solicitação de reserva enviada! Aguardando aprovação do síndico.'
                : 'Reserva confirmada com sucesso!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao reservar: $e')),
      );
    }
  }

  Future<void> _submitWaitlist() async {
    if (_selectedArea == null) return;
    final phoneErr = validatePhone(_phoneController.text);
    if (phoneErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phoneErr)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await widget.api.joinWaitlist(
        areaId: _selectedArea!['id'],
        startAt: _startDateTime,
        endAt: _endDateTime,
        contactPhone: _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (!mounted) return;
      final pos = res['waitlistPosition'] ?? 1;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2F3FB0),
          content: Text(
            'Você entrou na Lista de Espera (posição #$pos)! Caso haja cancelamento, sua reserva será promovida automaticamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao entrar na lista de espera: $e')),
      );
    }
  }

  void _selectTimeSlot(int hour, int duration) {
    setState(() {
      _startTime = TimeOfDay(hour: hour, minute: 0);
      _durationHours = duration;
    });
    _checkAvailability();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFE0E7FF),
            child: Icon(Icons.event_available_rounded, color: Color(0xFF2F3FB0)),
          ),
          SizedBox(width: 12),
          Text('Reservar Espaço'),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: _loadingAreas
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : _areas.isEmpty
                ? const Text('Nenhuma área comum ativa encontrada neste condomínio.')
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Seleção de Área
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedArea,
                          decoration: const InputDecoration(
                            labelText: 'Espaço / Área Comum',
                            prefixIcon: Icon(Icons.deck_outlined),
                          ),
                          items: _areas.map((a) {
                            final reqApproval = a['requiresApproval'] == true;
                            return DropdownMenuItem(
                              value: a,
                              child: Text(
                                '${a['name']} (${a['capacity'] ?? '—'} pessoas)${reqApproval ? ' • Requer aprovação' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedArea = val);
                            _checkAvailability();
                          },
                        ),
                        const SizedBox(height: 12),

                        // Informações e regras da área
                        if (_selectedArea != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Color(0xFF475569)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Funcionamento: ${_selectedArea!['openingHour'] ?? 8}h às ${_selectedArea!['closingHour'] ?? 22}h'
                                    '${_selectedArea!['requiresApproval'] == true ? ' • Sujeito a aprovação prévia' : ' • Confirmação instantânea'}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Calendário Visual de Dias (Próximos 14 dias)
                        const Text(
                          'Selecione o Dia (Calendário de Disponibilidade)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 14,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final day = DateTime.now().add(Duration(days: idx + 1));
                              final isSelected = day.year == _selectedDate.year &&
                                  day.month == _selectedDate.month &&
                                  day.day == _selectedDate.day;
                              final weekDay = DateFormat('E', 'pt_BR').format(day).toUpperCase();

                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setState(() => _selectedDate = day);
                                  _checkAvailability();
                                },
                                child: Container(
                                  width: 58,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF2F3FB0) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF2F3FB0) : const Color(0xFFE2E8F0),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        weekDay.replaceAll('.', ''),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Horários pré-definidos (Turnos)
                        const Text(
                          'Turnos Rápidos ou Horário Personalizado',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _timeSlotChip(
                                label: 'Manhã (09h-13h)',
                                isSelected: _startTime.hour == 9 && _durationHours == 4,
                                onTap: () => _selectTimeSlot(9, 4),
                              ),
                              const SizedBox(width: 8),
                              _timeSlotChip(
                                label: 'Tarde (14h-18h)',
                                isSelected: _startTime.hour == 14 && _durationHours == 4,
                                onTap: () => _selectTimeSlot(14, 4),
                              ),
                              const SizedBox(width: 8),
                              _timeSlotChip(
                                label: 'Noite (18h-22h)',
                                isSelected: _startTime.hour == 18 && _durationHours == 4,
                                onTap: () => _selectTimeSlot(18, 4),
                              ),
                              const SizedBox(width: 8),
                              _timeSlotChip(
                                label: 'Integral (10h-20h)',
                                isSelected: _startTime.hour == 10 && _durationHours == 10,
                                onTap: () => _selectTimeSlot(10, 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Horário e Duração customizados
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.access_time, size: 18),
                                label: Text('Início: ${timeFormat.format(_startDateTime)}'),
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _startTime,
                                  );
                                  if (t != null) {
                                    setState(() => _startTime = t);
                                    _checkAvailability();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _durationHours,
                                decoration: const InputDecoration(
                                  labelText: 'Duração',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 2, child: Text('2 horas')),
                                  DropdownMenuItem(value: 4, child: Text('4 horas')),
                                  DropdownMenuItem(value: 6, child: Text('6 horas')),
                                  DropdownMenuItem(value: 8, child: Text('8 horas')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _durationHours = val);
                                    _checkAvailability();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Card de Disponibilidade em Tempo Real
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _checkingAvailability
                                ? const Color(0xFFF8FAFC)
                                : (_isAvailable == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2)),
                            border: Border.all(
                              color: _checkingAvailability
                                  ? const Color(0xFFCBD5E1)
                                  : (_isAvailable == true ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _checkingAvailability
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      _isAvailable == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: _isAvailable == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      size: 20,
                                    ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _checkingAvailability
                                      ? 'Consultando disponibilidade em tempo real...'
                                      : (_availabilityMessage ?? 'Selecione data e hora para verificar.'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _isAvailable == true ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                tooltip: 'Reverificar disponibilidade',
                                onPressed: _checkAvailability,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Telefone de contato
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: const [PhoneInputFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Telefone para contato *',
                            hintText: '(21) 99999-9999',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Notas / Motivo
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observações / Motivo (opcional)',
                            hintText: 'Ex: Confraternização de aniversário',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        if (_isAvailable == false && _allowWaitlist)
          FilledButton.tonalIcon(
            onPressed: _submitting ? null : _submitWaitlist,
            icon: const Icon(Icons.hourglass_top_rounded, size: 18),
            label: Text('Entrar na Lista de Espera (${_waitlistCount + 1}º)'),
          ),
        FilledButton.icon(
          onPressed: (_isAvailable == true && !_submitting) ? _submit : null,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_selectedArea?['requiresApproval'] == true ? 'Solicitar Aprovação' : 'Confirmar Reserva'),
        ),
      ],
    );
  }

  Widget _timeSlotChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFE0E7FF),
      checkmarkColor: const Color(0xFF2F3FB0),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? const Color(0xFF2F3FB0) : const Color(0xFF334155),
      ),
    );
  }
}
