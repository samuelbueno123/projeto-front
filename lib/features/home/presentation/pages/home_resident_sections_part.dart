part of 'home_page.dart';

extension _HomeResidentSectionsExtension on _HomePageState {
  // ----------------------------------------------------
  // BOLETOS EM ABERTO
  // ----------------------------------------------------
  Widget _buildPendingBoletoSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingInvoices = _invoices
        .where((i) => i['status'] != 'PAID')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Taxas & Boletos',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: _openPaymentDialog,
              child: const Text('Histórico'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (pendingInvoices.isEmpty)
          InkWell(
            onTap: _openPaymentDialog,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                      : const Color(0xFFDCFCE7),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF15803D),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tudo em dia!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nenhum boleto em aberto para a sua unidade.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          )
        else
          ...pendingInvoices.take(1).map((invoice) {
            final isOverdue = invoice['status'] == 'OVERDUE';
            final amountVal = (invoice['amount'] as num?)?.toDouble() ?? 0.00;

            return InkWell(
              onTap: () => _paySingleBoleto(invoice),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isOverdue
                        ? const Color(0xFFFCA5A5)
                        : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? (isDark
                                  ? const Color(
                                      0xFF7F1D1D,
                                    ).withValues(alpha: 0.5)
                                  : const Color(0xFFFEE2E2))
                            : (isDark
                                  ? const Color(
                                      0xFF1E3A8A,
                                    ).withValues(alpha: 0.3)
                                  : const Color(0xFFEFF6FF)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: isOverdue
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice['title']?.toString() ??
                                'Taxa de Condomínio',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Vencimento: ${_formatDueDate(invoice['dueDate'])}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R\$ ${amountVal.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOverdue ? 'Vencido' : 'Em aberto',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isOverdue
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 32),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            backgroundColor: isDark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
                                : const Color(0xFFEFF6FF),
                            foregroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _paySingleBoleto(invoice),
                          child: const Text(
                            'Pagar agora',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatDueDate(dynamic raw) {
    if (raw == null) return '—';
    return formatDate(raw);
  }

  Future<void> _paySingleBoleto(Map<String, dynamic> invoice) async {
    final condoId = _condominium?['id'];
    final unitId = invoice['unitId'] ?? _activeMembership?['unitId'];
    if (condoId is! num || unitId is! num) {
      SaaSFeedback.showWarning(
        context,
        'Nenhuma unidade vinculada para realizar o pagamento.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => BoletoPaymentDialog(
        condominiumId: condoId,
        unitId: unitId,
        unitLabel: _unitDisplay,
        title: invoice['title']?.toString() ?? 'Taxa de Condomínio',
        amount: (invoice['amount'] as num?)?.toDouble() ?? 0.0,
        dueDate: _formatDueDate(invoice['dueDate']),
        digitableLine: invoice['digitableLine']?.toString() ?? '',
        status: invoice['status']?.toString() ?? 'PENDING',
        api: _communityApi,
        onPaid: () {
          _mutate(() {
            invoice['status'] = 'PAID';
          });
          _load();
        },
      ),
    );
  }

  // ----------------------------------------------------
  // COMUNICADOS RECENTES (THEMATIC PASTEL ICONS)
  // ----------------------------------------------------
  Widget _buildRecentAnnouncementsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comunicados recentes',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => _mutate(() => _tab = 7),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_announcements.isEmpty)
          InkWell(
            onTap: () => _mutate(() => _tab = 7),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Nenhum comunicado recente publicado para o condomínio.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._announcements.take(2).map((a) {
            final title = a['title']?.toString() ?? 'Comunicado';
            final content = a['content']?.toString() ?? '';
            final dateStr = _formatDate(a['createdAt']);
            final isSustainability =
                title.toLowerCase().contains('sustentab') ||
                title.toLowerCase().contains('recicl');
            final iconBg = isSustainability
                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F8F0))
                : (isDark ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF));
            final iconColor = isSustainability
                ? const Color(0xFF10B981)
                : const Color(0xFF8B5CF6);
            final iconData = isSustainability
                ? Icons.eco_rounded
                : Icons.campaign_rounded;

            return InkWell(
              onTap: () => _mutate(() => _tab = 7),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 84,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(iconData, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ----------------------------------------------------
  // PRÓXIMAS RESERVAS & CONTRAPROPOSTAS
  // ----------------------------------------------------
  Widget _buildUpcomingReservationsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final counterProposals = _reservations
        .where((r) => r['status'] == 'COUNTER_PROPOSED')
        .toList();
    final scheduledReservations = _reservations.where((r) {
      final s = (r['status']?.toString() ?? '').toUpperCase();
      if (s == 'CANCELLED' || s == 'REJECTED' || s == 'DENIED') return false;
      final end = parseUtcToLocal(r['endAt']);
      return end == null || end.isAfter(DateTime.now());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Minhas Reservas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _createReservation,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text(
                'Nova Reserva',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => _mutate(() => _tab = 2),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Ver todas', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (counterProposals.isNotEmpty) ...[
          ...counterProposals.map(
            (cp) => _buildCounterProposalCard(cp, isDark),
          ),
          const SizedBox(height: 10),
        ],

        if (scheduledReservations.isEmpty)
          InkWell(
            onTap: _createReservation,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.deck_rounded,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Nenhuma reserva agendada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Toque para agendar salão ou área comum.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          )
        else
          ...scheduledReservations.take(1).map((res) {
            final status = (res['status']?.toString() ?? 'PENDING')
                .toUpperCase();
            final isApproved = status == 'APPROVED' || status == 'CONFIRMED';
            final statusLabel = isApproved
                ? 'Confirmada'
                : (status == 'PENDING' ? 'Aguardando' : _text(status));
            final badgeBg = isApproved
                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                : (isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                      : const Color(0xFFDBEAFE));
            final badgeFg = isApproved
                ? const Color(0xFF15803D)
                : const Color(0xFF1D4ED8);
            final imgUrl = (res['imageUrl'] ?? res['commonAreaImageUrl'])
                ?.toString();

            return InkWell(
              onTap: () => _mutate(() => _tab = 2),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 84,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: SmartImage(
                          source: imgUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholderIcon: Icons.deck_rounded,
                          fallbackAsset: AppAssets.commonAreaDefault,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            res['commonAreaName']?.toString() ?? 'Área Comum',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatReservationDateTime(res),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCounterProposalCard(Map<String, dynamic> r, bool isDark) {
    final areaName = r['commonAreaName'] ?? 'Espaço Comum';
    final start = _formatDate(r['startAt']);
    final end = _formatDate(r['endAt']);
    final notes = r['notes'] ?? 'Portaria sugeriu alteração de horário.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.3)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFFD97706),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Contraproposta da Portaria: $areaName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Novo horário sugerido: De $start até $end',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (notes.toString().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Observação: $notes',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                  ),
                  onPressed: () => _acceptCounterProposal(r['id'] as num),
                  child: const Text('Aceitar Proposta'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFF87171)),
                  ),
                  onPressed: () => _declineCounterProposal(r['id'] as num),
                  child: const Text('Recusar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatReservationDateTime(Map<String, dynamic> r) {
    final start = r['startAt'];
    final end = r['endAt'];
    if (start == null) return 'Horário a definir';
    try {
      final s = parseUtcToLocal(start);
      if (s == null) return 'Horário a definir';
      final e = end != null
          ? parseUtcToLocal(end)
          : s.add(const Duration(hours: 4));
      final dateStr = DateFormat('dd/MM/yyyy').format(s);
      final sTime = DateFormat('HH:mm').format(s);
      final eTime = e != null ? DateFormat('HH:mm').format(e) : '';
      return '$dateStr\n$sTime - $eTime';
    } catch (_) {
      return 'Horário a definir';
    }
  }

  Future<void> _acceptCounterProposal(num id) async {
    try {
      await _communityApi.acceptCounterProposal(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contraproposta aceita! Sua reserva está confirmada.',
            ),
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

  Future<void> _declineCounterProposal(num id) async {
    try {
      await _communityApi.declineCounterProposal(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraproposta recusada.'),
            backgroundColor: Color(0xFFDC2626),
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

  Future<void> _cancelReservation(num id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação?'),
        content: const Text(
          'Deseja realmente cancelar esta solicitação de reserva? O horário voltará a ficar disponível para outros moradores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar Reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _communityApi.cancelReservation(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação de reserva cancelada com sucesso.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao cancelar: $e')));
      }
    }
  }

  bool _hasFeature(String code) => _subAccess.hasFeature(code);

  void _showPackageQrDialog(Map<String, dynamic> pkg) {
    final pin =
        pkg['pickupPin']?.toString() ?? pkg['id'].toString().padLeft(6, '0');
    final desc = pkg['description'] ?? 'Encomenda';
    final tracking = pkg['trackingCode']?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retirada Rápida',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  Text(
                    'Apresente este código na portaria',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                desc,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              if (tracking != null && tracking.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Rastreio: $tracking',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: 170,
                height: 170,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 3,
                            crossAxisSpacing: 3,
                          ),
                      itemCount: 49,
                      itemBuilder: (context, idx) {
                        final isCorner =
                            (idx < 3 && idx % 7 < 3) ||
                            (idx % 7 > 3 && idx < 3) ||
                            (idx >= 42 && idx % 7 < 3);
                        final isPattern =
                            idx % 2 == 0 || idx % 3 == 0 || isCorner;
                        return Container(
                          decoration: BoxDecoration(
                            color: isPattern
                                ? const Color(0xFF1E293B)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        size: 24,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'CÓDIGO PIN DE RETIRADA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pin,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 4,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copiar PIN',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: pin));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'PIN copiado para a área de transferência!',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          if (pkg['status'] == 'RECEIVED' || pkg['status'] == 'NOTIFIED')
            FilledButton.icon(
              icon: const Icon(Icons.hail_rounded, size: 16),
              label: const Text('Avisar Portaria'),
              onPressed: () {
                Navigator.pop(ctx);
                _requestPickup(pkg['id']);
              },
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SUB-PAGES (ENCOMENDAS, RESERVAS, COMUNICADOS)
  // SPACES ARE ROOMY AS REQUIRED BY USER RULE
  // ----------------------------------------------------
  Widget _packagesPage() {
    final filtered = _packages
        .where((e) => recordMatchesQuery(e, _packageQuery))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suas encomendas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Acompanhe o recebimento e retirada das entregas da sua unidade.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _openExpectedPackageDialog,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Avisar Encomenda'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        EnterSearchField(
          hintText: 'Pesquisar encomendas (Enter)',
          onSubmitted: (query) => _mutate(() => _packageQuery = query),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _empty('Nenhuma encomenda encontrada.', Icons.inventory_2_outlined)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, idx) {
              final e = filtered[idx];
              final isWaitingPickup =
                  e['status'] == 'RECEIVED' || e['status'] == 'NOTIFIED';
              final pin =
                  e['pickupPin']?.toString() ??
                  e['id'].toString().padLeft(6, '0');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: isWaitingPickup
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: isWaitingPickup
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _text(e['description'], 'Encomenda'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Recebida em: ${_formatDate(e['receivedAt'])}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (e['trackingCode'] != null &&
                                    e['trackingCode'].toString().isNotEmpty)
                                  Text(
                                    'Rastreio: ${e['trackingCode']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isWaitingPickup
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isWaitingPickup ? 'Disponível' : _text(e['status']),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isWaitingPickup
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFC7D2FE),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.pin_rounded,
                                    size: 14,
                                    color: Color(0xFF4338CA),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PIN: $pin',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: Color(0xFF4338CA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'QR / PIN',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _showPackageQrDialog(e),
                            ),
                            if (isWaitingPickup) ...[
                              const SizedBox(width: 8),
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
                                icon: const Icon(Icons.hail_rounded, size: 16),
                                label: const Text(
                                  'Solicitar Retirada',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () => _requestPickup(e['id']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _reservationsPage() {
    final hasReservationsFeature = _hasFeature('RESERVATIONS');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reservas de áreas comuns',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Agende salão de festas, churrasqueira e outros espaços.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: hasReservationsFeature
                  ? _createReservation
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Módulo de reservas disponível nos planos Profissional ou Premium.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova reserva'),
            ),
          ],
        ),
        if (!hasReservationsFeature) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seu condomínio está no plano Básico. O agendamento online de áreas comuns requer o plano Profissional.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Builder(
          builder: (context) {
            final now = DateTime.now();
            bool isCancelled(Map<String, dynamic> r) {
              final s = (r['status']?.toString() ?? '').toUpperCase();
              return s == 'CANCELLED' || s == 'REJECTED' || s == 'DENIED';
            }

            bool isPast(Map<String, dynamic> r) {
              if (isCancelled(r)) return false;
              final end = parseUtcToLocal(r['endAt']);
              return end != null && end.isBefore(now);
            }

            bool isScheduled(Map<String, dynamic> r) {
              return !isCancelled(r) && !isPast(r);
            }

            final scheduled = _reservations.where(isScheduled).toList();
            final past = _reservations.where(isPast).toList();
            final cancelled = _reservations.where(isCancelled).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'SCHEDULED',
                      label: Text('Agendadas (${scheduled.length})'),
                      icon: const Icon(Icons.event_available_rounded),
                    ),
                    ButtonSegment(
                      value: 'PAST',
                      label: Text('Já passaram (${past.length})'),
                      icon: const Icon(Icons.history_rounded),
                    ),
                    ButtonSegment(
                      value: 'CANCELLED',
                      label: Text('Canceladas (${cancelled.length})'),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ],
                  selected: {_reservationFilter},
                  onSelectionChanged: (val) =>
                      _mutate(() => _reservationFilter = val.first),
                ),
                const SizedBox(height: 14),
                EnterSearchField(
                  hintText: 'Pesquisar reservas por área ou data (Enter)',
                  onSubmitted: (query) =>
                      _mutate(() => _reservationQuery = query),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final currentList = switch (_reservationFilter) {
                      'PAST' => past,
                      'CANCELLED' => cancelled,
                      _ => scheduled,
                    };
                    final filtered = currentList
                        .where((e) => recordMatchesQuery(e, _reservationQuery))
                        .toList();

                    if (filtered.isEmpty) {
                      final emptyLabel = switch (_reservationFilter) {
                        'PAST' => 'Nenhuma reserva passada encontrada.',
                        'CANCELLED' => 'Nenhuma reserva cancelada.',
                        _ => 'Você não possui reservas agendadas no momento.',
                      };
                      return _empty(emptyLabel, Icons.event_available_outlined);
                    }

                    return Column(
                      children: filtered.map((e) {
                        final status =
                            e['status']?.toString().toUpperCase() ?? '';
                        final isCounter = status == 'COUNTER_PROPOSED';
                        final isPending = status == 'PENDING';
                        final isWaitlisted = status == 'WAITLISTED';
                        final isApproved =
                            status == 'APPROVED' || status == 'CONFIRMED';
                        final isItemCancelled = isCancelled(e);
                        final notes = e['notes']?.toString();
                        final reason = e['rejectionReason']?.toString();

                        Color badgeBg = const Color(0xFFF1F5F9);
                        Color badgeFg = const Color(0xFF475569);
                        String statusLabel = _text(e['status']);
                        if (isItemCancelled) {
                          badgeBg = const Color(0xFFDC2626);
                          badgeFg = Colors.white;
                          statusLabel = 'CANCELADA';
                        } else if (isCounter) {
                          badgeBg = const Color(0xFFFEF3C7);
                          badgeFg = const Color(0xFFB45309);
                          statusLabel = 'Contraproposta';
                        } else if (isWaitlisted) {
                          badgeBg = const Color(0xFFF3E8FF);
                          badgeFg = const Color(0xFF6D28D9);
                          statusLabel =
                              'Lista de Espera (#${e['waitlistPosition'] ?? 1})';
                        } else if (isPending) {
                          badgeBg = const Color(0xFFDBEAFE);
                          badgeFg = const Color(0xFF1D4ED8);
                          statusLabel = 'Aguardando Aprovação';
                        } else if (isApproved) {
                          badgeBg = const Color(0xFFDCFCE7);
                          badgeFg = const Color(0xFF15803D);
                          statusLabel = 'Confirmada';
                        } else {
                          badgeBg = const Color(0xFFF1F5F9);
                          badgeFg = const Color(0xFF475569);
                          statusLabel = 'Concluída';
                        }

                        final isDarkTheme =
                            Theme.of(context).brightness == Brightness.dark;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isItemCancelled
                              ? (isDarkTheme
                                    ? const Color(
                                        0xFF450A0A,
                                      ).withValues(alpha: 0.35)
                                    : const Color(0xFFFEF2F2))
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isItemCancelled
                                  ? const Color(0xFFFCA5A5)
                                  : (isDarkTheme
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0)),
                              width: isItemCancelled ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
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
                                        child:
                                            (e['imageUrl'] != null &&
                                                e['imageUrl']
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty)
                                            ? SmartImage(
                                                source: e['imageUrl'].toString(),
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                placeholderIcon: isItemCancelled
                                                    ? Icons.cancel_rounded
                                                    : (isCounter
                                                          ? Icons.swap_horiz_rounded
                                                          : (isApproved
                                                                ? Icons.check_circle_outline_rounded
                                                                : Icons.event_available_outlined)),
                                              )
                                            : CircleAvatar(
                                                backgroundColor: isItemCancelled
                                                    ? (Theme.of(context).brightness ==
                                                              Brightness.dark
                                                          ? const Color(0xFF7F1D1D)
                                                          : const Color(0xFFFEE2E2))
                                                    : badgeBg,
                                                child: Icon(
                                                  isItemCancelled
                                                      ? Icons.cancel_rounded
                                                      : (isCounter
                                                            ? Icons.swap_horiz_rounded
                                                            : (isApproved
                                                                  ? Icons.check_circle_outline_rounded
                                                                  : Icons.event_available_outlined)),
                                                  color: isItemCancelled
                                                      ? const Color(0xFFDC2626)
                                                      : badgeFg,
                                                ),
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
                                            _text(e['commonAreaName']),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isItemCancelled
                                                  ? const Color(0xFF991B1B)
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Período: ${_formatDate(e['startAt'])} até ${_formatDate(e['endAt'])}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isItemCancelled) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDarkTheme
                                          ? const Color(
                                              0xFF7F1D1D,
                                            ).withValues(alpha: 0.3)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFECACA),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.highlight_off_rounded,
                                          size: 16,
                                          color: Color(0xFFDC2626),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            reason != null && reason.isNotEmpty
                                                ? 'Motivo: $reason'
                                                : 'Esta reserva foi cancelada e o espaço foi liberado para novos agendamentos.',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF991B1B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (isCounter &&
                                    notes != null &&
                                    notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: Color(0xFFB45309),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Proposta da portaria: $notes',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (!isItemCancelled &&
                                    (isCounter ||
                                        isPending ||
                                        isWaitlisted)) ...[
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (isCounter) ...[
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF15803D,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            icon: const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Aceitar Proposta',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            onPressed: () =>
                                                _acceptCounterProposal(
                                                  e['id'] as num,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFFDC2626,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFFF87171),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Recusar',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            onPressed: () =>
                                                _declineCounterProposal(
                                                  e['id'] as num,
                                                ),
                                          ),
                                        ] else if (isPending ||
                                            isWaitlisted) ...[
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFF64748B,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                            ),
                                            label: Text(
                                              isWaitlisted
                                                  ? 'Sair da Fila de Espera'
                                                  : 'Cancelar Solicitação',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            onPressed: () => _cancelReservation(
                                              e['id'] as num,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _announcementsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Mural de comunicados',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      const Text(
        'Avisos oficiais publicados pela administração do seu condomínio.',
      ),
      const SizedBox(height: 14),
      EnterSearchField(
        hintText: 'Pesquisar comunicados (Enter)',
        onSubmitted: (query) => _mutate(() => _announcementQuery = query),
      ),
      const SizedBox(height: 12),
      if (_announcements
          .where((e) => recordMatchesQuery(e, _announcementQuery))
          .isEmpty)
        _empty('Nenhum comunicado ativo no momento.', Icons.campaign_outlined)
      else
        ..._announcements
            .where((e) => recordMatchesQuery(e, _announcementQuery))
            .map((e) {
              final isRead = e['readByCurrentUser'] == true;
              final readCount = e['readCount'] ?? 0;
              final targetDesc =
                  e['targetDescription']?.toString() ?? 'Todo o condomínio';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFEF3C7),
                            child: Icon(
                              Icons.campaign_outlined,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _text(e['title']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${_formatDate(e['createdAt'])} • Público: $targetDesc',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRead ? 'Lido' : 'Novo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isRead
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_text(e['content'])),
                      if (e['imageUrl'] != null &&
                          e['imageUrl'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClickableImagePreview(
                          imageSource: e['imageUrl'].toString(),
                          title: _text(e['title']),
                          height: 180,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$readCount confirmação(ões) de leitura',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isRead && e['id'] != null)
                            FilledButton.tonalIcon(
                              icon: const Icon(
                                Icons.done_all_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Confirmar leitura',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                try {
                                  await _communityApi.markAnnouncementAsRead(
                                    e['id'] as num,
                                  );
                                  await _refreshAnnouncements();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Leitura confirmada com sucesso!',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (err) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro: $err')),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
    ],
  );

}
