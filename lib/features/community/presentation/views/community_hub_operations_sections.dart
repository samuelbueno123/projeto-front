part of 'community_hub_view.dart';

// 1. OCORRÊNCIAS & CHAMADOS
// ----------------------------------------------------
class _TicketsSubView extends StatefulWidget {
  const _TicketsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_TicketsSubView> createState() => _TicketsSubViewState();
}

class _TicketsSubViewState extends State<_TicketsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listTickets(widget.condominiumId);
      if (mounted) {
        setState(() {
          _tickets = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewTicketDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final location = TextEditingController();
    String category = 'MAINTENANCE';
    String priority = 'MEDIUM';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Abrir Chamado / Ocorrência'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(
                        value: 'MAINTENANCE',
                        child: Text('Manutenção'),
                      ),
                      DropdownMenuItem(
                        value: 'NOISE',
                        child: Text('Barulho / Silêncio'),
                      ),
                      DropdownMenuItem(
                        value: 'SECURITY',
                        child: Text('Segurança'),
                      ),
                      DropdownMenuItem(
                        value: 'CLEANING',
                        child: Text('Limpeza'),
                      ),
                      DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
                    ],
                    onChanged: (v) => setDState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Título da Ocorrência *',
                      hintText: 'Ex: Lâmpada do 2º andar queimada',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Local exato',
                      hintText: 'Ex: Bloco B, corredor em frente ao 203',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'Prioridade'),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('Baixa')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Média')),
                      DropdownMenuItem(
                        value: 'HIGH',
                        child: Text('Alta (Urgente)'),
                      ),
                    ],
                    onChanged: (v) => setDState(() => priority = v ?? priority),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição detalhada *',
                      hintText: 'Explique o que ocorreu...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar Chamado'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && title.text.isNotEmpty && desc.text.isNotEmpty) {
      await widget.api.createTicket(
        condoId: widget.condominiumId,
        category: category,
        title: title.text.trim(),
        description: desc.text.trim(),
        location: location.text.trim().isEmpty ? null : location.text.trim(),
        priority: priority,
      );
      _load();
    }
  }

  Future<void> _openUpdateStatusDialog(Map<String, dynamic> ticket) async {
    String currentStatus = (ticket['status']?.toString() ?? 'OPEN')
        .toUpperCase();
    if (currentStatus != 'OPEN' &&
        currentStatus != 'IN_PROGRESS' &&
        currentStatus != 'RESOLVED' &&
        currentStatus != 'REJECTED') {
      currentStatus = 'OPEN';
    }
    String selectedStatus = currentStatus;
    final responseCtrl = TextEditingController(
      text: ticket['adminResponse']?.toString() ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Atualizar Status do Chamado'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket['title'] ?? 'Ocorrência',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Novo Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'OPEN',
                        child: Text('Aberto (Pendente)'),
                      ),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text('Em Análise / Atendimento'),
                      ),
                      DropdownMenuItem(
                        value: 'RESOLVED',
                        child: Text('Resolvido / Concluído'),
                      ),
                      DropdownMenuItem(
                        value: 'REJECTED',
                        child: Text('Recusado / Arquivado'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDState(() => selectedStatus = v ?? selectedStatus),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: responseCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Resposta / Parecer Administrativo',
                      hintText:
                          'Explique as providências tomadas ou resolução...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar Alteração'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await widget.api.updateTicketStatus(
        ticketId: ticket['id'],
        status: selectedStatus,
        adminResponse: responseCtrl.text.trim().isEmpty
            ? null
            : responseCtrl.text.trim(),
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chamado atualizado com sucesso!')),
        );
      }
    }
  }

  Widget _buildStatusTimeline(String rawStatus) {
    final status = rawStatus.toUpperCase();
    final isResolved = status == 'RESOLVED';
    final isInProgress = status == 'IN_PROGRESS' || isResolved;
    final isOpen = true;
    final isRejected = status == 'REJECTED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isRejected
          ? const Row(
              children: [
                Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 16),
                SizedBox(width: 6),
                Text(
                  'Chamado Recusado / Arquivado',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _buildTimelineStep(
                  title: 'Aberto',
                  isActive: isOpen,
                  isDone: isInProgress,
                  activeColor: const Color(0xFFD97706),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: isInProgress
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                _buildTimelineStep(
                  title: 'Em Análise',
                  isActive: isInProgress,
                  isDone: isResolved,
                  activeColor: const Color(0xFF1D4ED8),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: isResolved
                        ? const Color(0xFF15803D)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                _buildTimelineStep(
                  title: 'Resolvido',
                  isActive: isResolved,
                  isDone: isResolved,
                  activeColor: const Color(0xFF15803D),
                ),
              ],
            ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required bool isActive,
    required bool isDone,
    required Color activeColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone
              ? Icons.check_circle_rounded
              : (isActive
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded),
          size: 15,
          color: isActive ? activeColor : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total de chamados: ${_tickets.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo Chamado'),
                onPressed: _openNewTicketDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SaaSLoadingState(
                        message: 'Carregando chamados e ocorrências...',
                      ),
                    ),
                  )
                : _tickets.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.report_problem_outlined,
                    title: 'Nenhuma ocorrência registrada',
                    subtitle:
                        'Tudo tranquilo! Não há chamados ou ocorrências abertas no momento.',
                  )
                : ListView.separated(
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final t = _tickets[idx];
                      final status = t['status']?.toString();
                      final isResolved = status == 'RESOLVED';
                      final inProgress = status == 'IN_PROGRESS';
                      final color = isResolved
                          ? const Color(0xFF15803D)
                          : (inProgress
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFFB45309));
                      final bg = isResolved
                          ? const Color(0xFFDCFCE7)
                          : (inProgress
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFFEF3C7));

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      t['title'] ?? 'Sem título',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status ?? 'OPEN',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  if (t['unitLabel'] != null &&
                                      t['unitLabel'].toString().isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.home_outlined,
                                          size: 13,
                                          color: Color(0xFF2563EB),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Unidade: ${t['unitLabel']}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (t['authorName'] != null &&
                                      t['authorName'].toString().isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.person_outline,
                                          size: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Autor: ${t['authorName']}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (t['createdAt'] != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 13,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          formatDateTime(t['createdAt']),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t['description'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              if (t['location'] != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.place_outlined,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      t['location'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              _buildStatusTimeline(status ?? 'OPEN'),
                              if (t['adminResponse'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Resposta da administração: ${t['adminResponse']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(
                                        Icons.rate_review_outlined,
                                        size: 15,
                                      ),
                                      label: const Text(
                                        'Responder / Atualizar Status',
                                        style: TextStyle(fontSize: 11.5),
                                      ),
                                      onPressed: () =>
                                          _openUpdateStatusDialog(t),
                                    ),
                                  ],
                                ),
                              ),
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
}

// ----------------------------------------------------
// 2. VISITANTES & PRE-AUTORIZAÇÃO
// ----------------------------------------------------
class _VisitorsSubView extends StatefulWidget {
  const _VisitorsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_VisitorsSubView> createState() => _VisitorsSubViewState();
}

class _VisitorsSubViewState extends State<_VisitorsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _visitors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listVisitors(widget.condominiumId);
      if (mounted) {
        setState(() {
          _visitors = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewVisitorDialog() async {
    final name = TextEditingController();
    final doc = TextEditingController();
    final plate = TextEditingController();
    final notes = TextEditingController();
    String type = 'GUEST';
    DateTime validFrom = DateTime.now();
    DateTime validUntil = DateTime.now().add(const Duration(hours: 24));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: const Text('Pré-Autorizar Visitante / Prestador'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Visitante',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'GUEST',
                        child: Text('Convidado / Amigo / Familiar'),
                      ),
                      DropdownMenuItem(
                        value: 'SERVICE_PROVIDER',
                        child: Text('Prestador de Serviços / Obra'),
                      ),
                      DropdownMenuItem(
                        value: 'DELIVERY',
                        child: Text('Entregador'),
                      ),
                    ],
                    onChanged: (v) => setDState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: doc,
                    decoration: const InputDecoration(
                      labelText: 'RG ou CPF (opcional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: plate,
                    decoration: const InputDecoration(
                      labelText: 'Placa do Veículo (se houver)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(
                      'Validade Inicial: ${DateFormat('dd/MM/yyyy HH:mm').format(validFrom)}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: c,
                          initialDate: validFrom,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (d != null && c.mounted) {
                          final t = await showTimePicker(
                            context: c,
                            initialTime: TimeOfDay.fromDateTime(validFrom),
                          );
                          if (t != null) {
                            setDState(
                              () => validFrom = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                t.hour,
                                t.minute,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Alterar'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy_rounded),
                    title: Text(
                      'Validade Final: ${DateFormat('dd/MM/yyyy HH:mm').format(validUntil)}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: c,
                          initialDate: validUntil,
                          firstDate: validFrom,
                          lastDate: DateTime.now().add(
                            const Duration(days: 180),
                          ),
                        );
                        if (d != null && c.mounted) {
                          final t = await showTimePicker(
                            context: c,
                            initialTime: TimeOfDay.fromDateTime(validUntil),
                          );
                          if (t != null) {
                            setDState(
                              () => validUntil = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                t.hour,
                                t.minute,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Alterar'),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Gerar Convite & QR Code'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && name.text.isNotEmpty) {
      final created = await widget.api.createVisitor(
        condoId: widget.condominiumId,
        visitorName: name.text.trim(),
        documentNumber: doc.text.trim().isEmpty ? null : doc.text.trim(),
        vehiclePlate: plate.text.trim().isEmpty ? null : plate.text.trim(),
        visitorType: type,
        validFrom: validFrom.toIso8601String(),
        validUntil: validUntil.toIso8601String(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
      await _load();
      if (mounted && created.isNotEmpty) {
        _showQrInviteDialog(created);
      }
    }
  }

  void _showQrInviteDialog(Map<String, dynamic> v) {
    final code = v['accessCode']?.toString() ?? '';
    final qrPayload =
        v['qrCodePayload']?.toString() ?? 'ANCORA-VISITOR|CODE:$code';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFF2F3FB0), size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Convite Digital com QR Code')),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 120,
                      color: Color(0xFF1E293B),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF2F3FB0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      qrPayload,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Visitante: ${v['visitorName'] ?? ''}\n'
                'Validade: ${v['validFrom'] != null ? formatDateTime(v['validFrom']) : 'Imediata'} até ${v['validUntil'] != null ? formatDateTime(v['validUntil']) : '—'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qrPayload));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payload do QR Code copiado!')),
              );
            },
            child: const Text('Copiar QR Code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Autorizações de Acesso (${_visitors.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Pré-Autorizar'),
                onPressed: _openNewVisitorDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SaaSLoadingState(
                        message: 'Carregando visitantes pré-autorizados...',
                      ),
                    ),
                  )
                : _visitors.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.person_add_disabled_outlined,
                    title: 'Nenhum visitante pré-autorizado',
                    subtitle:
                        'Gere convites com QR Code ou PIN para liberar a entrada na portaria.',
                  )
                : ListView.separated(
                    itemCount: _visitors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final v = _visitors[idx];
                      final code = v['accessCode']?.toString() ?? '';
                      final status = v['status']?.toString() ?? 'AUTHORIZED';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE0E7FF),
                            child: Text(
                              code.isNotEmpty
                                  ? code.substring(0, code.length.clamp(0, 3))
                                  : 'OK',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2F3FB0),
                              ),
                            ),
                          ),
                          title: Text(
                            v['visitorName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Código: $code • Placa: ${v['vehiclePlate'] ?? 'Pedestre'} • ${v['visitorType'] ?? ''}',
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (v['unitLabel'] != null &&
                                      v['unitLabel'].toString().isNotEmpty)
                                    Text(
                                      'Unidade: ${v['unitLabel']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  if (v['residentName'] != null &&
                                      v['residentName'].toString().isNotEmpty)
                                    Text(
                                      'Morador: ${v['residentName']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  if (v['createdAt'] != null)
                                    Text(
                                      formatDateTime(v['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Exibir QR Code do Convite',
                                  icon: const Icon(
                                    Icons.qr_code_2_rounded,
                                    color: Color(0xFF2F3FB0),
                                    size: 22,
                                  ),
                                  onPressed: () => _showQrInviteDialog(v),
                                ),
                                IconButton(
                                  tooltip: 'Compartilhar Convite no WhatsApp',
                                  icon: const Icon(
                                    Icons.share_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    final qrPayload =
                                        v['qrCodePayload']?.toString() ?? code;
                                    final invite =
                                        '''
🏢 *CONVITE DE ACESSO — CONDOMÍNIO ÂNCORA*
Olá, *${v['visitorName']}*!
Você possui acesso pré-autorizado ao condomínio.
🔑 *Código de Acesso:* $code
📲 *QR Code:* $qrPayload
🚗 *Veículo:* ${v['vehiclePlate'] ?? 'A pé / Pedestre'}
Por favor, apresente este código ou QR Code na portaria ao chegar.
''';
                                    Clipboard.setData(
                                      ClipboardData(text: invite),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Convite formatado copiado! Cole no WhatsApp do visitante.',
                                        ),
                                        backgroundColor: Color(0xFF15803D),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                                Chip(
                                  label: Text(
                                    status,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: status == 'CHECKED_IN'
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF1F5F9),
                                ),
                              ],
                            ),
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
}

// ----------------------------------------------------
// 3. VOTAÇÕES & ENQUETES
// ----------------------------------------------------
class _PollsSubView extends StatefulWidget {
  const _PollsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_PollsSubView> createState() => _PollsSubViewState();
}

class _PollsSubViewState extends State<_PollsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _polls = [];

  Future<void> _openNewPollDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController(text: 'Sim, a favor');
    final opt2Ctrl = TextEditingController(text: 'Não, contra');
    final extraOptions = <TextEditingController>[];
    int durationDays = 7;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.how_to_vote_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Criar Nova Votação / Enquete'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título da Votação / Assembleia *',
                      hintText: 'Ex: Aprovação de reforma da fachada',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição detalhada e contexto',
                      hintText:
                          'Explique a proposta para os condôminos votarem...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Opções de Voto:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: opt1Ctrl,
                    decoration: const InputDecoration(labelText: 'Opção 1 *'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: opt2Ctrl,
                    decoration: const InputDecoration(labelText: 'Opção 2 *'),
                  ),
                  ...extraOptions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: 'Opção ${entry.key + 3}',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => setDState(
                              () => extraOptions.removeAt(entry.key),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setDState(
                      () => extraOptions.add(TextEditingController()),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar outra opção'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: durationDays,
                    decoration: const InputDecoration(
                      labelText: 'Duração da Votação',
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 dias')),
                      DropdownMenuItem(
                        value: 7,
                        child: Text('7 dias (1 semana)'),
                      ),
                      DropdownMenuItem(value: 15, child: Text('15 dias')),
                      DropdownMenuItem(
                        value: 30,
                        child: Text('30 dias (1 mês)'),
                      ),
                    ],
                    onChanged: (v) => setDState(() => durationDays = v ?? 7),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Publicar Votação'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final options = [
        opt1Ctrl.text.trim(),
        opt2Ctrl.text.trim(),
        ...extraOptions.map((e) => e.text.trim()).where((e) => e.isNotEmpty),
      ].where((e) => e.isNotEmpty).toList();

      if (options.length < 2) {
        options.addAll(['Sim', 'Não']);
      }

      final endsAt = DateTime.now().add(Duration(days: durationDays));
      try {
        await widget.api.createPoll(
          condoId: widget.condominiumId,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim(),
          options: options,
          endsAt: endsAt,
        );
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votação criada com sucesso!'),
              backgroundColor: Color(0xFF15803D),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao criar votação: $e')));
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listPolls(widget.condominiumId);
      if (mounted) {
        setState(() {
          _polls = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vote(num pollId, num optionId) async {
    try {
      await widget.api.votePoll(pollId: pollId, optionId: optionId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Votações & Assembleias (${_polls.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.canManage)
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova Votação'),
                  onPressed: _openNewPollDialog,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SaaSLoadingState(
                        message:
                            'Carregando votações e assembleias virtuais...',
                      ),
                    ),
                  )
                : _polls.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.how_to_vote_outlined,
                    title: 'Nenhuma votação em andamento',
                    subtitle:
                        'Não há enquetes ou votações virtuais ativas no momento.',
                  )
                : ListView.separated(
                    itemCount: _polls.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final p = _polls[idx];
                      final options = (p['options'] as List? ?? [])
                          .whereType<Map<String, dynamic>>()
                          .toList();
                      final totalVotes =
                          (p['totalVotes'] as num?)?.toInt() ?? 0;
                      final myOptionId = p['myOptionId'];
                      final isClosed = p['closed'] == true;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isClosed
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isClosed ? 'Encerrada' : 'Em Votação',
                                      style: TextStyle(
                                        color: isClosed
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF15803D),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (p['createdByName'] != null &&
                                      p['createdByName'].toString().isNotEmpty)
                                    Text(
                                      'Criada por: ${p['createdByName']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  if (p['createdAt'] != null)
                                    Text(
                                      '• ${formatDate(p['createdAt'])}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p['description'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ...options.map((opt) {
                                final optId = opt['id'];
                                final votes =
                                    (opt['voteCount'] as num?)?.toInt() ?? 0;
                                final pct = totalVotes > 0
                                    ? (votes / totalVotes)
                                    : 0.0;
                                final isSelected = myOptionId == optId;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: (!isClosed)
                                        ? () => _vote(p['id'], optId)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFEEF2FF)
                                            : const Color(0xFFF8FAFC),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF4F46E5)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    isSelected
                                                        ? Icons
                                                              .check_circle_rounded
                                                        : Icons
                                                              .radio_button_unchecked,
                                                    size: 18,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF4F46E5,
                                                          )
                                                        : const Color(
                                                            0xFF94A3B8,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    opt['optionText'] ?? '',
                                                    style: TextStyle(
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '$votes votos (${(pct * 100).toStringAsFixed(1)}%)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: pct,
                                              backgroundColor: const Color(
                                                0xFFE2E8F0,
                                              ),
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    isSelected
                                                        ? const Color(
                                                            0xFF4F46E5,
                                                          )
                                                        : const Color(
                                                            0xFF94A3B8,
                                                          ),
                                                  ),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
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
}

// ----------------------------------------------------
// 4. CLASSIFICADOS INTERNOS
// ----------------------------------------------------
class _ClassifiedsSubView extends StatefulWidget {
  const _ClassifiedsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_ClassifiedsSubView> createState() => _ClassifiedsSubViewState();
}

class _ClassifiedsSubViewState extends State<_ClassifiedsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listClassifieds(widget.condominiumId);
      if (mounted) {
        setState(() {
          _ads = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewAdDialog() async {
    final title = TextEditingController();
    final price = TextEditingController();
    final desc = TextEditingController();
    final phone = TextEditingController();
    String cat = 'PARKING_RENTAL';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Novo Anúncio nos Classificados'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: cat,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(
                        value: 'PARKING_RENTAL',
                        child: Text('Aluguel de Vaga de Garagem'),
                      ),
                      DropdownMenuItem(
                        value: 'SALE',
                        child: Text('Venda de Objeto / Móvel'),
                      ),
                      DropdownMenuItem(
                        value: 'DONATION',
                        child: Text('Doação'),
                      ),
                      DropdownMenuItem(
                        value: 'SERVICE',
                        child: Text('Serviço Profissional'),
                      ),
                    ],
                    onChanged: (v) => setD(() => cat = v ?? cat),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone para Contato *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrição detalhada *',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && title.text.isNotEmpty && desc.text.isNotEmpty) {
      await widget.api.createClassified(
        condoId: widget.condominiumId,
        category: cat,
        title: title.text.trim(),
        description: desc.text.trim(),
        price: price.text.trim().isEmpty ? null : price.text.trim(),
        contactPhone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      );
      _load();
    }
  }

  Future<void> _sendInterest(num adId) async {
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demonstrar Interesse'),
        content: TextField(
          controller: msg,
          decoration: const InputDecoration(
            labelText: 'Mensagem para o anunciante',
            hintText: 'Tenho interesse! Ainda está disponível?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar Mensagem'),
          ),
        ],
      ),
    );
    if (ok == true && msg.text.isNotEmpty) {
      await widget.api.sendClassifiedInterest(adId, msg.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem de interesse enviada ao anunciante!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mural de Classificados (${_ads.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Anunciar'),
                onPressed: _openNewAdDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SaaSLoadingState(
                        message: 'Carregando anúncios e classificados...',
                      ),
                    ),
                  )
                : _ads.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Nenhum anúncio disponível',
                    subtitle:
                        'Compartilhe itens para venda, doação ou serviços com os vizinhos.',
                  )
                : ListView.separated(
                    itemCount: _ads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final a = _ads[idx];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      a['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (a['price'] != null)
                                    Text(
                                      'R\$ ${a['price']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF15803D),
                                        fontSize: 15,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a['description'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (a['unitLabel'] != null &&
                                      a['unitLabel'].toString().isNotEmpty)
                                    Text(
                                      'Unidade: ${a['unitLabel']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  if (a['authorName'] != null &&
                                      a['authorName'].toString().isNotEmpty)
                                    Text(
                                      '• Anunciante: ${a['authorName']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  if (a['createdAt'] != null)
                                    Text(
                                      '• ${formatDate(a['createdAt'])}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Contato: ${a['contactPhone'] ?? 'Direto no app'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (a['contactPhone'] != null &&
                                            a['contactPhone']
                                                .toString()
                                                .trim()
                                                .isNotEmpty) ...[
                                          IconButton(
                                            tooltip:
                                                'Copiar mensagem para WhatsApp',
                                            icon: const Icon(
                                              Icons.chat_bubble_outline_rounded,
                                              color: Color(0xFF16A34A),
                                              size: 19,
                                            ),
                                            onPressed: () {
                                              final digits = a['contactPhone']
                                                  .toString()
                                                  .replaceAll(
                                                    RegExp(r'\D'),
                                                    '',
                                                  );
                                              final title =
                                                  a['title'] ?? 'anúncio';
                                              final msg =
                                                  'Olá! Vi seu anúncio "$title" nos Classificados do Condomínio e gostaria de informações.';
                                              Clipboard.setData(
                                                ClipboardData(text: msg),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Mensagem de contato copiada! Envie para o WhatsApp ($digits).',
                                                  ),
                                                  backgroundColor: const Color(
                                                    0xFF15803D,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        FilledButton.tonalIcon(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          icon: const Icon(
                                            Icons.send_rounded,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Tenho Interesse',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () =>
                                              _sendInterest(a['id']),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
}

// ----------------------------------------------------
