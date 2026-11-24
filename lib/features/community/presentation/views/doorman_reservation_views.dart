part of 'doorman_community_views.dart';

class DoormanReservationsView extends StatefulWidget {
  const DoormanReservationsView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanReservationsView> createState() =>
      _DoormanReservationsViewState();
}

class _DoormanReservationsViewState extends State<DoormanReservationsView> {
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String? _error;
  String _category = 'SCHEDULED'; // SCHEDULED, PAST, CANCELLED
  String _subFilter = 'ALL'; // ALL, PENDING, CONFIRMED, COUNTER_PROPOSED

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.getCondominiumReservations(
        widget.condominiumId,
      );
      if (mounted) {
        setState(() {
          _reservations = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  bool _isCancelled(Map<String, dynamic> r) {
    final s = r['status']?.toString().toUpperCase();
    return s == 'CANCELLED' || s == 'REJECTED';
  }

  bool _isPast(Map<String, dynamic> r) {
    if (_isCancelled(r)) return false;
    final endAt = r['endAt']?.toString();
    if (endAt == null || endAt.isEmpty) return false;
    try {
      final dt = parseUtcToLocal(endAt);
      if (dt == null) return false;
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  bool _isScheduled(Map<String, dynamic> r) {
    return !_isCancelled(r) && !_isPast(r);
  }

  List<Map<String, dynamic>> get _currentCategoryReservations {
    return switch (_category) {
      'PAST' => _reservations.where(_isPast).toList(),
      'CANCELLED' => _reservations.where(_isCancelled).toList(),
      _ => _reservations.where(_isScheduled).toList(),
    };
  }

  List<Map<String, dynamic>> get _filtered {
    final catList = _currentCategoryReservations;
    if (_category != 'SCHEDULED' || _subFilter == 'ALL') return catList;
    return catList.where((r) => r['status'] == _subFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scheduled = _reservations.where(_isScheduled).toList();
    final past = _reservations.where(_isPast).toList();
    final cancelled = _reservations.where(_isCancelled).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reservas de Áreas Comuns (${_reservations.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              IconButton(
                tooltip: 'Atualizar',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 3 Main Segmented Categories
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Agendadas (${scheduled.length})'),
                  selected: _category == 'SCHEDULED',
                  avatar: const Icon(Icons.calendar_month_outlined, size: 16),
                  onSelected: (val) {
                    if (val) setState(() => _category = 'SCHEDULED');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Já passaram (${past.length})'),
                  selected: _category == 'PAST',
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  onSelected: (val) {
                    if (val) setState(() => _category = 'PAST');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Canceladas (${cancelled.length})',
                    style: TextStyle(
                      color: _category == 'CANCELLED'
                          ? Colors.white
                          : const Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: _category == 'CANCELLED',
                  selectedColor: const Color(0xFFDC2626),
                  backgroundColor: isDark
                      ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                      : const Color(0xFFFEE2E2),
                  side: BorderSide(
                    color: _category == 'CANCELLED'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFFCA5A5),
                  ),
                  avatar: Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: _category == 'CANCELLED'
                        ? Colors.white
                        : const Color(0xFFDC2626),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _category = 'CANCELLED');
                  },
                ),
              ],
            ),
          ),
          if (_category == 'SCHEDULED') ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _subFilterChip('Todas agendadas', 'ALL'),
                  const SizedBox(width: 8),
                  _subFilterChip('Pendentes de Aprovação', 'PENDING'),
                  const SizedBox(width: 8),
                  _subFilterChip('Contraproposta Enviada', 'COUNTER_PROPOSED'),
                  const SizedBox(width: 8),
                  _subFilterChip('Confirmadas', 'CONFIRMED'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SaaSLoadingState(
                        message: 'Carregando reservas de áreas comuns...',
                      ),
                    ),
                  )
                : _error != null
                ? SaaSErrorState(
                    message: 'Falha ao carregar reservas: $_error',
                    onRetry: _load,
                  )
                : _filtered.isEmpty
                ? SaaSEmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'Nenhuma reserva encontrada',
                    subtitle: _category == 'CANCELLED'
                        ? 'Não há reservas canceladas registradas.'
                        : _category == 'PAST'
                        ? 'Não há reservas finalizadas para este filtro.'
                        : 'Não há agendamentos para este filtro.',
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final r = _filtered[idx];
                      final id = r['id'] as num;
                      final area =
                          r['commonAreaName'] ?? r['commonArea'] ?? 'Área';
                      final resident =
                          r['reservedByName'] ?? r['residentName'] ?? 'Morador';
                      final phone = r['contactPhone'] ?? '';
                      final status = r['status']?.toString() ?? 'PENDING';
                      final isItemCancelled = _isCancelled(r);
                      final startAt = r['startAt']?.toString() ?? '';
                      final endAt = r['endAt']?.toString() ?? '';
                      final notes = r['notes']?.toString();
                      final counterNotes = r['counterProposalNotes']
                          ?.toString();
                      final propStart = r['proposedStartAt']?.toString();
                      final imgUrl = (r['imageUrl'] ?? r['commonAreaImageUrl'])
                          ?.toString();

                      return Card(
                        elevation: 0,
                        color: isItemCancelled
                            ? (isDark
                                  ? const Color(
                                      0xFF450A0A,
                                    ).withValues(alpha: 0.35)
                                  : const Color(0xFFFEF2F2))
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isItemCancelled
                                ? const Color(0xFFFCA5A5)
                                : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                            width: isItemCancelled ? 1.5 : 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: SmartImage(
                                        source: imgUrl,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        placeholderIcon:
                                            Icons.event_available_rounded,
                                        fallbackAsset:
                                            AppAssets.commonAreaDefault,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          area.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: isItemCancelled
                                                ? const Color(0xFFB91C1C)
                                                : null,
                                          ),
                                        ),
                                        Text(
                                          'Morador: $resident ${phone.isNotEmpty ? "• $phone" : ""}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Horário: ${_formatDt(startAt)} até ${_formatDt(endAt)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                          if (isItemCancelled) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF450A0A)
                                                    : const Color(0xFFFEE2E2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFFF87171),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.cancel_rounded,
                                                    size: 13,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFF87171,
                                                          )
                                                        : const Color(
                                                            0xFFDC2626,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'CANCELADA / RECUSADA',
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFF87171,
                                                            )
                                                          : const Color(
                                                              0xFFDC2626,
                                                            ),
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 10.5,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (notes != null &&
                                              notes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Observação: $notes',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                          if (status == 'COUNTER_PROPOSED' &&
                                              counterNotes != null) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF451A03)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'Contraproposta enviada: $counterNotes ${propStart != null ? "(${_formatDt(propStart)})" : ""}',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? const Color(0xFFFCD34D)
                                                      : const Color(0xFFB45309),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (status == 'PENDING') ...[
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF15803D,
                                        ),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Aceitar Reserva'),
                                      onPressed: () => _approve(id),
                                    ),
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: isDark
                                              ? const Color(0xFF451A03)
                                              : const Color(0xFFFEF3C7),
                                          foregroundColor: isDark
                                              ? const Color(0xFFFCD34D)
                                              : const Color(0xFFB45309),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                          Icons.schedule_send_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Contraproposta'),
                                        onPressed: () =>
                                            _openCounterProposal(r),
                                      ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Ajustar & Salvar'),
                                      onPressed: () => _openModifyAndConfirm(r),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Recusar'),
                                      onPressed: () => _reject(id),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _subFilterChip(String label, String code) {
    return ChoiceChip(
      label: Text(label),
      selected: _subFilter == code,
      onSelected: (val) {
        if (val) setState(() => _subFilter = code);
      },
    );
  }

  String _formatDt(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = parseUtcToLocal(raw);
      if (dt == null) return raw;
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _approve(num id) async {
    try {
      await widget.api.approveReservation(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva aprovada com sucesso!'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _reject(num id) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recusar solicitação de reserva?'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Motivo da recusa (opcional)',
          ),
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
            child: const Text('Confirmar Recusa'),
          ),
        ],
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed == true) {
      try {
        await widget.api.rejectReservation(id, reason);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  Future<void> _openCounterProposal(Map<String, dynamic> r) async {
    // Import do CounterProposalDialog
    await showDialog(
      context: context,
      builder: (context) => CounterProposalDialog(
        reservation: r,
        api: widget.api,
        onSubmitted: _load,
      ),
    );
  }

  Future<void> _openModifyAndConfirm(Map<String, dynamic> r) async {
    final startCtrl = TextEditingController(
      text: r['startAt']?.toString() ?? '',
    );
    final endCtrl = TextEditingController(text: r['endAt']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: r['notes']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustar e Confirmar Diretamente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Início (ISO ex: 2026-11-10T14:00:00)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fim (ISO ex: 2026-11-10T18:00:00)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observação do Porteiro',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar Reserva'),
          ),
        ],
      ),
    );

    final startText = startCtrl.text.trim();
    final endText = endCtrl.text.trim();
    final notesText = notesCtrl.text.trim();
    startCtrl.dispose();
    endCtrl.dispose();
    notesCtrl.dispose();

    if (confirmed == true) {
      try {
        final start = DateTime.parse(startText);
        final end = DateTime.parse(endText);
        await widget.api.modifyAndConfirmReservation(
          reservationId: r['id'] as num,
          startAt: start,
          endAt: end,
          notes: notesText,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }
}
