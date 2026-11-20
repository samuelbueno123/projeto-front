part of 'community_hub_view.dart';

// 9. INFRAÇÕES, NOTIFICAÇÕES & DEFESAS
// ----------------------------------------------------
class _InfractionsSubView extends StatefulWidget {
  const _InfractionsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_InfractionsSubView> createState() => _InfractionsSubViewState();
}

class _InfractionsSubViewState extends State<_InfractionsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _infractions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listInfractions(widget.condominiumId);
      if (mounted) {
        setState(() {
          _infractions = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewInfractionDialog() async {
    if (!widget.canManage) return;
    List<Map<String, dynamic>> units;
    try {
      units = await widget.api.getCondominiumUnits(widget.condominiumId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar as unidades: $error'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre uma unidade antes de emitir uma notificação.',
          ),
        ),
      );
      return;
    }

    final title = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();
    num? selectedUnitId = units.first['id'] as num?;
    String type = 'WARNING';
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Registrar Notificação ou Multa'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Notificação',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'WARNING',
                          child: Text('Advertência Formal'),
                        ),
                        DropdownMenuItem(
                          value: 'FINE',
                          child: Text('Multa por Infração ao Regimento'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => type = value ?? type),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<num>(
                      value: selectedUnitId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unidade *'),
                      items: units.map((unit) {
                        final identifier =
                            unit['identifier']?.toString() ?? 'Unidade';
                        final sector = unit['sectorName']?.toString();
                        return DropdownMenuItem<num>(
                          value: unit['id'] as num,
                          child: Text(
                            sector == null || sector.isEmpty
                                ? identifier
                                : '$identifier • $sector',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedUnitId = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Título da Ocorrência *',
                        hintText: 'Ex: Barulho após horário permitido',
                      ),
                    ),
                    if (type == 'FINE') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor da Multa (R\$) *',
                          hintText: '150.00',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: desc,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrição e artigo do regimento *',
                        hintText: 'Descreva a ocorrência constatada...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: selectedUnitId == null || title.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Emitir Notificação'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || selectedUnitId == null) return;
      await widget.api.createInfraction(
        condoId: widget.condominiumId,
        unitId: selectedUnitId!,
        type: type,
        title: title.text.trim(),
        description: desc.text.trim(),
        fineAmount: amount.text.trim().isEmpty ? null : amount.text.trim(),
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação registrada com sucesso!')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível registrar a notificação: $error'),
          ),
        );
      }
    } finally {
      title.dispose();
      desc.dispose();
      amount.dispose();
    }
  }

  Future<void> _submitDefense(num id) async {
    final def = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar Defesa / Recurso'),
        content: TextField(
          controller: def,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Justificativa para o síndico *',
            hintText: 'Apresente suas razões e evidências...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar Defesa'),
          ),
        ],
      ),
    );

    if (ok == true && def.text.isNotEmpty) {
      await widget.api.submitDefense(id, def.text.trim());
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defesa enviada à administração!')),
        );
      }
    }
  }

  Future<void> _judgeDefense(
    num id,
    String status,
    String defaultJudgment,
  ) async {
    final notes = TextEditingController(text: defaultJudgment);
    final isCancel = status == 'CANCELLED';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isCancel
              ? 'Acatar Defesa (Cancelar Multa)'
              : 'Indeferir Defesa (Manter Infração)',
        ),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Parecer do síndico / administração',
            hintText: 'Justifique a decisão para o morador...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isCancel
                  ? const Color(0xFF15803D)
                  : const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isCancel ? 'Acatar Defesa' : 'Manter Infração'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.judgeInfraction(id, status, notes.text.trim());
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decisão registrada com sucesso!')),
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
          if (widget.canManage) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${_infractions.length} ocorrências',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova Notificação'),
                  onPressed: _openNewInfractionDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SaaSLoadingState(
                        message: 'Carregando notificações e advertências...',
                      ),
                    ),
                  )
                : _infractions.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'Nenhuma advertência ou multa',
                    subtitle:
                        'Sua unidade está em total conformidade com o regulamento interno. Parabéns!',
                  )
                : ListView.separated(
                    itemCount: _infractions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final inf = _infractions[idx];
                      final status = (inf['status']?.toString() ?? 'ISSUED')
                          .toUpperCase();
                      final canDefend = status == 'ISSUED';
                      final hasDefense =
                          inf['defense'] != null &&
                          inf['defense'].toString().isNotEmpty;

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
                                  Text(
                                    '${inf['type'] == 'FINE' ? 'Multa' : 'Advertência'}: ${inf['title']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      status,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: const Color(0xFFFEF3C7),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (inf['unitLabel'] != null &&
                                      inf['unitLabel'].toString().isNotEmpty)
                                    Text(
                                      'Unidade: ${inf['unitLabel']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  if (inf['issuedByName'] != null &&
                                      inf['issuedByName'].toString().isNotEmpty)
                                    Text(
                                      '• Emitida por: ${inf['issuedByName']}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  if (inf['createdAt'] != null)
                                    Text(
                                      '• ${formatDate(inf['createdAt'])}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                inf['description'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              if (hasDefense) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Defesa do morador: ${inf['defense']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              if (inf['judgment'] != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Parecer da administração: ${inf['judgment']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                              if (widget.canManage &&
                                  hasDefense &&
                                  status != 'CANCELLED' &&
                                  status != 'CONFIRMED') ...[
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF15803D,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 15,
                                        ),
                                        label: const Text(
                                          'Acatar Defesa (Cancelar)',
                                          style: TextStyle(fontSize: 11.5),
                                        ),
                                        onPressed: () => _judgeDefense(
                                          inf['id'],
                                          'CANCELLED',
                                          'Defesa acolhida pela administração.',
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 15,
                                        ),
                                        label: const Text(
                                          'Manter Multa',
                                          style: TextStyle(fontSize: 11.5),
                                        ),
                                        onPressed: () => _judgeDefense(
                                          inf['id'],
                                          'CONFIRMED',
                                          'Defesa indeferida. Infração mantida.',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (canDefend && !widget.canManage) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonalIcon(
                                    icon: const Icon(
                                      Icons.shield_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Apresentar Defesa Prévia',
                                    ),
                                    onPressed: () => _submitDefense(inf['id']),
                                  ),
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
}

// ----------------------------------------------------
// 10. SMART LOCKERS & ARMÁRIOS INTELIGENTES
// ----------------------------------------------------
class _LockersSubView extends StatefulWidget {
  const _LockersSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_LockersSubView> createState() => _LockersSubViewState();
}

class _LockersSubViewState extends State<_LockersSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _lockers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openDepositDialog() async {
    if (!widget.canManage) return;
    List<Map<String, dynamic>> units;
    try {
      units = await widget.api.getCondominiumUnits(widget.condominiumId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar as unidades: $error'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre uma unidade antes de depositar no armário.'),
        ),
      );
      return;
    }

    final comp = TextEditingController();
    final courier = TextEditingController();
    final tracking = TextEditingController();
    num? selectedUnitId;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(Icons.add_box_outlined, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text('Depositar no Armário Inteligente'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: comp,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Compartimento / Vão *',
                        hintText: 'Ex: A01, B04',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<num>(
                      value: selectedUnitId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Unidade de destino *',
                      ),
                      items: units.map((unit) {
                        final identifier =
                            unit['identifier']?.toString() ?? 'Unidade';
                        final sector = unit['sectorName']?.toString();
                        return DropdownMenuItem<num>(
                          value: unit['id'] as num,
                          child: Text(
                            sector == null || sector.isEmpty
                                ? identifier
                                : '$identifier • $sector',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedUnitId = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: courier,
                      decoration: const InputDecoration(
                        labelText: 'Entregador / Transportadora',
                        hintText: 'Ex: Mercado Livre, Correios',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tracking,
                      decoration: const InputDecoration(
                        labelText: 'Código de Rastreio / Nota',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: comp.text.trim().isEmpty || selectedUnitId == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Depositar'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || selectedUnitId == null || comp.text.trim().isEmpty) {
        return;
      }
      await widget.api.depositLocker(
        condoId: widget.condominiumId,
        compartmentNumber: comp.text.trim(),
        unitId: selectedUnitId!,
        courierName: courier.text.trim().isEmpty ? null : courier.text.trim(),
        trackingCode: tracking.text.trim().isEmpty
            ? null
            : tracking.text.trim(),
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Armário abastecido e PIN enviado ao morador!'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao depositar no armário: $error')),
        );
      }
    } finally {
      comp.dispose();
      courier.dispose();
      tracking.dispose();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listLockers(widget.condominiumId);
      if (mounted) {
        setState(() {
          _lockers = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retrieve(num lockerId) async {
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar do Armário Inteligente'),
        content: TextField(
          controller: pin,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Digite o PIN de 6 dígitos',
            hintText: '123456',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Retirada'),
          ),
        ],
      ),
    );

    if (ok == true && pin.text.isNotEmpty) {
      await widget.api.retrieveLocker(lockerId, pin.text.trim());
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Armário destravado com sucesso!')),
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
                'Armários Inteligentes (${_lockers.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.canManage)
                FilledButton.icon(
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Depositar no Locker'),
                  onPressed: _openDepositDialog,
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
                        message: 'Carregando status dos lockers...',
                      ),
                    ),
                  )
                : _lockers.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.all_inbox_outlined,
                    title: 'Nenhum armário ocupado',
                    subtitle:
                        'Não há encomendas aguardando retirada em armários inteligentes no momento.',
                  )
                : ListView.separated(
                    itemCount: _lockers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final l = _lockers[idx];
                      final isOccupied = l['status'] == 'OCCUPIED';
                      final pin = l['pinCode'];

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFDCFCE7),
                                child: Icon(
                                  Icons.lock_open_rounded,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Compartimento ${l['compartmentNumber']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Código: ${l['trackingCode'] ?? 'Sem rastreio'} • Entregador: ${l['courierName'] ?? 'Portaria'}',
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        if (l['unitLabel'] != null &&
                                            l['unitLabel']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            'Unidade: ${l['unitLabel']}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        if (l['recipientName'] != null &&
                                            l['recipientName']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            'Destinatário: ${l['recipientName']}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        if (l['depositedByName'] != null &&
                                            l['depositedByName']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            '• Depositado por: ${l['depositedByName']}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        if (l['depositedAt'] != null)
                                          Text(
                                            '• ${formatDateTime(l['depositedAt'])}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (pin != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Seu PIN: $pin',
                                          style: const TextStyle(
                                            color: Color(0xFF15803D),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isOccupied)
                                FilledButton.icon(
                                  icon: const Icon(
                                    Icons.vpn_key_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Retirar'),
                                  onPressed: () => _retrieve(l['id']),
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
// 11. LISTAS DE CONVIDADOS DE EVENTOS
// ----------------------------------------------------
class _GuestListsSubView extends StatefulWidget {
  const _GuestListsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_GuestListsSubView> createState() => _GuestListsSubViewState();
}

class _GuestListsSubViewState extends State<_GuestListsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openCreateGuestListDialog() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    DateTime eventDate = DateTime.now().add(const Duration(days: 3));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.celebration_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Nova Lista de Convidados'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Título do Evento *',
                      hintText: 'Ex: Aniversário no Salão de Festas',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      'Data do Evento: ${DateFormat('dd/MM/yyyy HH:mm').format(eventDate)}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: c,
                          initialDate: eventDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null && c.mounted) {
                          final t = await showTimePicker(
                            context: c,
                            initialTime: TimeOfDay.fromDateTime(eventDate),
                          );
                          if (t != null) {
                            setD(
                              () => eventDate = DateTime(
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
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observações para a portaria',
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
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(c, true);
              },
              child: const Text('Criar Lista'),
            ),
          ],
        ),
      ),
    );
    final eventTitle = title.text.trim();
    final eventNotes = notes.text.trim();
    title.dispose();
    notes.dispose();

    if (ok == true && eventTitle.isNotEmpty) {
      try {
        await widget.api.createGuestList(
          condoId: widget.condominiumId,
          eventTitle: eventTitle,
          eventDate: eventDate.toIso8601String(),
          notes: eventNotes,
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lista de convidados criada com sucesso!'),
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
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await widget.api.listGuestLists(widget.condominiumId);
      if (mounted) {
        setState(() {
          _lists = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addGuestDialog(num listId) async {
    final name = TextEditingController();
    final doc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Convidado à Lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nome Completo *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: doc,
              decoration: const InputDecoration(
                labelText: 'Documento (RG/CPF)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    final guestName = name.text.trim();
    final documentNumber = doc.text.trim();
    name.dispose();
    doc.dispose();

    if (ok == true && guestName.isNotEmpty) {
      await widget.api.addGuest(
        guestListId: listId,
        guestName: guestName,
        documentNumber: documentNumber.isEmpty ? null : documentNumber,
      );
      await _load();
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
                'Listas de Convidados (${_lists.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova Lista'),
                onPressed: _openCreateGuestListDialog,
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
                        message: 'Carregando listas de convidados...',
                      ),
                    ),
                  )
                : _lists.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.checklist_rtl_rounded,
                    title: 'Nenhuma lista de convidados',
                    subtitle:
                        'Crie listas para eventos, festas e churrascos para sincronização com a portaria.',
                  )
                : ListView.separated(
                    itemCount: _lists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final gl = _lists[idx];
                      final guests = (gl['guests'] as List? ?? [])
                          .whereType<Map<String, dynamic>>()
                          .toList();

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0E7FF),
                            child: Icon(
                              Icons.celebration_rounded,
                              color: Color(0xFF2F3FB0),
                            ),
                          ),
                          title: Text(
                            gl['eventTitle'] ?? 'Festa',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            [
                              'Anfitrião: ${gl['hostName'] ?? 'Morador'}',
                              if (gl['eventDate'] != null)
                                formatDateTime(gl['eventDate']),
                              '${guests.length} convidados',
                              if (gl['notes']?.toString().trim().isNotEmpty ==
                                  true)
                                'Portaria: ${gl['notes']}',
                            ].join(' • '),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add_alt),
                            tooltip: 'Adicionar Convidado',
                            onPressed: () => _addGuestDialog(gl['id']),
                          ),
                          children: [
                            ...guests.map(
                              (g) => ListTile(
                                dense: true,
                                leading: Icon(
                                  g['checkedIn'] == true
                                      ? Icons.check_circle
                                      : Icons.person_outline,
                                  color: g['checkedIn'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                title: Text(g['guestName'] ?? ''),
                                subtitle: Text(
                                  g['documentNumber'] ?? 'Sem documento',
                                ),
                              ),
                            ),
                          ],
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
// 12. MANUTENÇÃO PREDIAL & ORDENS DE SERVIÇO
// ----------------------------------------------------
class _MaintenanceSubView extends StatefulWidget {
  const _MaintenanceSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_MaintenanceSubView> createState() => _MaintenanceSubViewState();
}

class _MaintenanceSubViewState extends State<_MaintenanceSubView> {
  bool _loading = true;
  int _subTab =
      0; // 0 = Ordens de Serviço, 1 = Manutenção Preventiva, 2 = Fornecedores
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _suppliers = [];
  String? _statusFilter;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.events.listen((event) {
      if (event.type == 'MAINTENANCE_UPDATED' && mounted) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.listMaintenanceOrders(widget.condominiumId, _statusFilter),
        widget.api
            .listMaintenanceEquipment(widget.condominiumId)
            .catchError((_) => <Map<String, dynamic>>[]),
        widget.api
            .listSuppliers(widget.condominiumId)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (mounted) {
        setState(() {
          _orders = results[0];
          _equipment = results[1];
          _suppliers = results[2];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openNewEquipmentDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final recurrenceCtrl = TextEditingController(text: '30');
    final respCtrl = TextEditingController();
    String category = 'ELEVADORES';
    DateTime nextDate = DateTime.now().add(const Duration(days: 30));
    num? preferredSupplierId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.precision_manufacturing_outlined,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 10),
              Expanded(child: Text('Cadastrar Equipamento / Estrutura')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Equipamento / Estrutura *',
                      hintText: 'Ex: Elevador Social 01, Bomba de Recalque',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(
                        value: 'ELEVADORES',
                        child: Text('Elevadores'),
                      ),
                      DropdownMenuItem(
                        value: 'HIDRAULICA',
                        child: Text('Hidráulica / Bombas'),
                      ),
                      DropdownMenuItem(
                        value: 'ELETRICA',
                        child: Text('Elétrica / Gerador'),
                      ),
                      DropdownMenuItem(
                        value: 'AVCB_INCENDIO',
                        child: Text('Combate a Incêndio / Extintores'),
                      ),
                      DropdownMenuItem(
                        value: 'ESTRUTURAL',
                        child: Text('Estrutura / Fachada'),
                      ),
                      DropdownMenuItem(
                        value: 'SEGURANCA',
                        child: Text('CFTV / Portões'),
                      ),
                    ],
                    onChanged: (v) => setD(() => category = v ?? 'ELEVADORES'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Localização',
                      hintText: 'Casa de Máquinas / Bloco A',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: recurrenceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Periodicidade Preventiva (dias) *',
                      hintText: '30',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: respCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Responsável Interno',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_suppliers.isNotEmpty) ...[
                    DropdownButtonFormField<num?>(
                      value: preferredSupplierId,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor Preferencial',
                      ),
                      items: [
                        const DropdownMenuItem<num?>(
                          value: null,
                          child: Text('Nenhum vinculado'),
                        ),
                        ..._suppliers.map(
                          (s) => DropdownMenuItem<num?>(
                            value: s['id'] as num?,
                            child: Text(
                              s['companyName']?.toString() ?? 'Fornecedor',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setD(() => preferredSupplierId = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat_rounded),
                    title: Text(
                      'Próxima Manutenção: ${DateFormat('dd/MM/yyyy').format(nextDate)}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: c,
                          initialDate: nextDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 60),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null) setD(() => nextDate = picked);
                      },
                      child: const Text('Alterar'),
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
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(c, true);
              },
              child: const Text('Salvar Equipamento'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final dateStr =
          '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
      await widget.api.createMaintenanceEquipment(
        widget.condominiumId,
        name: nameCtrl.text.trim(),
        category: category,
        location: locationCtrl.text.trim(),
        recurrenceDays: int.tryParse(recurrenceCtrl.text.trim()) ?? 30,
        nextMaintenanceDate: dateStr,
        responsibleName: respCtrl.text.trim(),
        preferredSupplierId: preferredSupplierId,
      );
      _load();
    }
  }

  Future<void> _openNewSupplierDialog() async {
    final companyCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    String category = 'ELEVADORES';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.engineering_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Expanded(child: Text('Cadastrar Fornecedor / Prestador')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Empresa / Profissional *',
                      hintText: 'Ex: Atlas Elevadores Ltda',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Especialidade / Serviço',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ELEVADORES',
                        child: Text('Elevadores'),
                      ),
                      DropdownMenuItem(
                        value: 'HIDRAULICA',
                        child: Text('Hidráulica'),
                      ),
                      DropdownMenuItem(
                        value: 'ELETRICA',
                        child: Text('Elétrica'),
                      ),
                      DropdownMenuItem(
                        value: 'AVCB_INCENDIO',
                        child: Text('Incêndio / AVCB'),
                      ),
                      DropdownMenuItem(
                        value: 'SEGURANCA',
                        child: Text('Segurança Eletrônica'),
                      ),
                      DropdownMenuItem(
                        value: 'LIMPEZA',
                        child: Text('Limpeza e Jardinagem'),
                      ),
                      DropdownMenuItem(
                        value: 'GERAL',
                        child: Text('Manutenção Geral'),
                      ),
                    ],
                    onChanged: (v) => setD(() => category = v ?? 'GERAL'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Responsável',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telefone / WhatsApp',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: docCtrl,
                    decoration: const InputDecoration(labelText: 'CNPJ / CPF'),
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
              onPressed: () {
                if (companyCtrl.text.trim().isEmpty) return;
                Navigator.pop(c, true);
              },
              child: const Text('Salvar Fornecedor'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await widget.api.createSupplier(
        widget.condominiumId,
        companyName: companyCtrl.text.trim(),
        serviceCategory: category,
        contactName: contactCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        documentNumber: docCtrl.text.trim(),
      );
      _load();
    }
  }

  Future<void> _openNewOrderDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final contractor = TextEditingController();
    final contact = TextEditingController();
    final cost = TextEditingController();
    final notes = TextEditingController();
    String category = 'HIDRAULICA';
    String type = 'CORRECTIVE';
    String priority = 'MEDIUM';
    DateTime? scheduledDate;
    num? selectedEquipmentId;
    num? selectedSupplierId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.build_circle_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Nova Ordem de Serviço'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Título da Manutenção *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do Problema / Serviço *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(
                        value: 'HIDRAULICA',
                        child: Text('Hidráulica'),
                      ),
                      DropdownMenuItem(
                        value: 'ELETRICA',
                        child: Text('Elétrica'),
                      ),
                      DropdownMenuItem(
                        value: 'ELEVADORES',
                        child: Text('Elevadores'),
                      ),
                      DropdownMenuItem(
                        value: 'ESTRUTURAL',
                        child: Text('Estrutural / Alvenaria'),
                      ),
                      DropdownMenuItem(
                        value: 'SEGURANCA',
                        child: Text('Segurança / CFTV'),
                      ),
                      DropdownMenuItem(
                        value: 'AVCB_INCENDIO',
                        child: Text('Incêndio / AVCB'),
                      ),
                      DropdownMenuItem(
                        value: 'LIMPEZA',
                        child: Text('Limpeza / Conservação'),
                      ),
                      DropdownMenuItem(value: 'OUTROS', child: Text('Outros')),
                    ],
                    onChanged: (v) => setDState(() => category = v ?? 'OUTROS'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: type,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(
                              value: 'CORRECTIVE',
                              child: Text('Corretiva'),
                            ),
                            DropdownMenuItem(
                              value: 'PREVENTIVE',
                              child: Text('Preventiva'),
                            ),
                          ],
                          onChanged: (v) =>
                              setDState(() => type = v ?? 'CORRECTIVE'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          decoration: const InputDecoration(
                            labelText: 'Prioridade',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'LOW',
                              child: Text('Baixa'),
                            ),
                            DropdownMenuItem(
                              value: 'MEDIUM',
                              child: Text('Média'),
                            ),
                            DropdownMenuItem(
                              value: 'HIGH',
                              child: Text('Alta'),
                            ),
                            DropdownMenuItem(
                              value: 'URGENT',
                              child: Text('Urgente'),
                            ),
                          ],
                          onChanged: (v) =>
                              setDState(() => priority = v ?? 'MEDIUM'),
                        ),
                      ),
                    ],
                  ),
                  if (_equipment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<num?>(
                      value: selectedEquipmentId,
                      decoration: const InputDecoration(
                        labelText: 'Equipamento / Estrutura Vinculado',
                      ),
                      items: [
                        const DropdownMenuItem<num?>(
                          value: null,
                          child: Text('Nenhum equipamento específico'),
                        ),
                        ..._equipment.map(
                          (eq) => DropdownMenuItem<num?>(
                            value: eq['id'] as num?,
                            child: Text(
                              '${eq['name']} (${eq['location'] ?? eq['category']})',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setDState(() => selectedEquipmentId = v),
                    ),
                  ],
                  if (_suppliers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<num?>(
                      value: selectedSupplierId,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor Cadastrado',
                      ),
                      items: [
                        const DropdownMenuItem<num?>(
                          value: null,
                          child: Text('Informar manualmente abaixo'),
                        ),
                        ..._suppliers.map(
                          (s) => DropdownMenuItem<num?>(
                            value: s['id'] as num?,
                            child: Text(
                              '${s['companyName']} (★ ${s['ratingAverage'] ?? '—'})',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDState(() => selectedSupplierId = v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: contractor,
                    decoration: const InputDecoration(
                      labelText: 'Empresa / Prestador Contratado',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contact,
                    decoration: const InputDecoration(
                      labelText: 'Contato do Prestador (Telefone/Email)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cost,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Custo Estimado (R\$)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      scheduledDate == null
                          ? 'Data Agendada: Não definida'
                          : 'Data: ${DateFormat('dd/MM/yyyy').format(scheduledDate!)}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setDState(() => scheduledDate = picked);
                        }
                      },
                      child: const Text('Selecionar'),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observações / Recomendações',
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
              onPressed: () {
                if (title.text.trim().isEmpty || desc.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Salvar Ordem'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await widget.api.createMaintenanceOrder(
          widget.condominiumId,
          title: title.text.trim(),
          description: desc.text.trim(),
          category: category,
          type: type,
          priority: priority,
          equipmentId: selectedEquipmentId,
          supplierId: selectedSupplierId,
          contractorName: contractor.text.trim().isNotEmpty
              ? contractor.text.trim()
              : null,
          contractorContact: contact.text.trim().isNotEmpty
              ? contact.text.trim()
              : null,
          scheduledDate: scheduledDate,
          estimatedCost: double.tryParse(cost.text.replaceAll(',', '.')),
          notes: notes.text.trim().isNotEmpty ? notes.text.trim() : null,
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

  Future<void> _updateStatusDialog(Map<String, dynamic> order) async {
    final statusCtrl = TextEditingController(text: order['status'] ?? 'OPEN');
    final actualCost = TextEditingController(
      text: order['actualCost']?.toString() ?? '',
    );
    final notes = TextEditingController();
    final feedbackCtrl = TextEditingController();
    int rating = 5;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text('Atualizar O.S. #${order['id']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: statusCtrl.text,
                  decoration: const InputDecoration(labelText: 'Novo Status'),
                  items: const [
                    DropdownMenuItem(value: 'OPEN', child: Text('Aberta')),
                    DropdownMenuItem(
                      value: 'IN_PROGRESS',
                      child: Text('Em Andamento'),
                    ),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('Concluída'),
                    ),
                    DropdownMenuItem(
                      value: 'CANCELLED',
                      child: Text('Cancelada'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDState(() => statusCtrl.text = v ?? 'OPEN'),
                ),
                const SizedBox(height: 10),
                if (statusCtrl.text == 'COMPLETED') ...[
                  TextField(
                    controller: actualCost,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Custo Real Finalizado (R\$)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (order['supplierId'] != null) ...[
                    DropdownButtonFormField<int>(
                      value: rating,
                      decoration: const InputDecoration(
                        labelText: 'Avaliação do Fornecedor (1 a 5 estrelas)',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 5,
                          child: Text('★★★★★ (5 - Excelente)'),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text('★★★★☆ (4 - Bom)'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('★★★☆☆ (3 - Regular)'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('★★☆☆☆ (2 - Ruim)'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('★☆☆☆☆ (1 - Péssimo)'),
                        ),
                      ],
                      onChanged: (v) => setDState(() => rating = v ?? 5),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: feedbackCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Parecer sobre o Fornecedor',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas da Conclusão / Andamento',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await widget.api.updateMaintenanceOrderStatus(
          order['id'] as num,
          status: statusCtrl.text,
          actualCost: double.tryParse(actualCost.text.replaceAll(',', '.')),
          notes: notes.text.trim().isNotEmpty ? notes.text.trim() : null,
          supplierRating:
              (statusCtrl.text == 'COMPLETED' && order['supplierId'] != null)
              ? rating
              : null,
          supplierFeedback: feedbackCtrl.text.trim().isNotEmpty
              ? feedbackCtrl.text.trim()
              : null,
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'OPEN':
        return const Color(0xFFF59E0B);
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'OPEN':
        return 'Aberta';
      case 'IN_PROGRESS':
        return 'Em Andamento';
      case 'COMPLETED':
        return 'Concluída';
      case 'CANCELLED':
        return 'Cancelada';
      default:
        return status ?? 'Aberta';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          _subTab == 0
              ? 'Nova Ordem de Serviço'
              : (_subTab == 1 ? 'Novo Equipamento' : 'Novo Fornecedor'),
        ),
        onPressed: _subTab == 0
            ? _openNewOrderDialog
            : (_subTab == 1 ? _openNewEquipmentDialog : _openNewSupplierDialog),
      ),
      body: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SaaSLoadingState(
                  message: 'Carregando gestão de manutenção...',
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.assignment_outlined, size: 18),
                        label: Text('Ordens (${_orders.length})'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.event_repeat_rounded, size: 18),
                        label: Text('Preventiva (${_equipment.length})'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: const Icon(Icons.engineering_outlined, size: 18),
                        label: Text('Fornecedores (${_suppliers.length})'),
                      ),
                    ],
                    selected: {_subTab},
                    onSelectionChanged: (s) =>
                        setState(() => _subTab = s.first),
                  ),
                ),
                if (_subTab == 0) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Todas'),
                          selected: _statusFilter == null,
                          onSelected: (_) {
                            setState(() => _statusFilter = null);
                            _load();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Abertas'),
                          selected: _statusFilter == 'OPEN',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'OPEN');
                            _load();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Em Andamento'),
                          selected: _statusFilter == 'IN_PROGRESS',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'IN_PROGRESS');
                            _load();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Concluídas'),
                          selected: _statusFilter == 'COMPLETED',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'COMPLETED');
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _orders.isEmpty
                        ? const SaaSEmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'Nenhuma ordem de serviço',
                            subtitle:
                                'Não há ordens de serviço cadastradas para este filtro.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final o = _orders[index];
                              final status = o['status']?.toString() ?? 'OPEN';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(
                                                status,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _statusLabel(status),
                                              style: TextStyle(
                                                color: _statusColor(status),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              o['category'] ?? 'Geral',
                                              style: const TextStyle(
                                                color: Color(0xFF475569),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          if (o['equipmentName'] != null) ...[
                                            const SizedBox(width: 8),
                                            Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              label: Text(
                                                'Equip.: ${o['equipmentName']}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (widget.canManage)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_note_rounded,
                                                color: Color(0xFF2563EB),
                                              ),
                                              tooltip: 'Atualizar Status',
                                              onPressed: () =>
                                                  _updateStatusDialog(o),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        o['title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        o['description'] ?? '',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Criado por: ${o['createdByName'] ?? 'Administração'} • ${formatDate(o['createdAt'])}',
                                        style: const TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Divider(height: 20),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 8,
                                        children: [
                                          if (o['supplierName'] != null ||
                                              o['contractorName'] != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.engineering_outlined,
                                                  size: 16,
                                                  color: Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Fornecedor: ${o['supplierName'] ?? o['contractorName']}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (o['supplierRating'] != null)
                                            Text(
                                              'Avaliação: ★ ${o['supplierRating']}/5',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          if (o['scheduledDate'] != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today_outlined,
                                                  size: 15,
                                                  color: Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Data: ${o['scheduledDate']}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (o['estimatedCost'] != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.attach_money_rounded,
                                                  size: 16,
                                                  color: Color(0xFF64748B),
                                                ),
                                                Text(
                                                  'Est.: R\$ ${(o['estimatedCost'] as num).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (o['actualCost'] != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.check_circle_outline,
                                                  size: 16,
                                                  color: Color(0xFF10B981),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Final: R\$ ${(o['actualCost'] as num).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              ],
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
                ] else if (_subTab == 1) ...[
                  Expanded(
                    child: _equipment.isEmpty
                        ? const SaaSEmptyState(
                            icon: Icons.precision_manufacturing_outlined,
                            title: 'Nenhum equipamento cadastrado',
                            subtitle:
                                'Cadastre elevadores, bombas, portões e geradores para o plano preventivo.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: _equipment.length,
                            itemBuilder: (context, idx) {
                              final eq = _equipment[idx];
                              final overdue =
                                  eq['overdue'] == true ||
                                  eq['alertStatus'] == 'OVERDUE';
                              final dueSoon =
                                  eq['dueSoon'] == true ||
                                  eq['alertStatus'] == 'DUE_SOON';
                              final badgeColor = overdue
                                  ? const Color(0xFFDC2626)
                                  : (dueSoon
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF15803D));
                              final badgeBg = overdue
                                  ? const Color(0xFFFEE2E2)
                                  : (dueSoon
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFDCFCE7));
                              final badgeLabel = overdue
                                  ? 'ATRASADA'
                                  : (dueSoon ? 'PRÓXIMA' : 'EM DIA');

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: badgeBg,
                                    child: Icon(
                                      Icons.precision_manufacturing_outlined,
                                      color: badgeColor,
                                    ),
                                  ),
                                  title: Text(
                                    eq['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Cat.: ${eq['category'] ?? ''} • Local: ${eq['location'] ?? 'Geral'}\n'
                                    'Ciclo: a cada ${eq['recurrenceDays'] ?? 30} dias • Próx.: ${eq['nextMaintenanceDate'] ?? '—'}'
                                    '${eq['preferredSupplierName'] != null ? ' • Fornecedor: ${eq['preferredSupplierName']}' : ''}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Chip(
                                    label: Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                      ),
                                    ),
                                    backgroundColor: badgeBg,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ] else ...[
                  Expanded(
                    child: _suppliers.isEmpty
                        ? const SaaSEmptyState(
                            icon: Icons.engineering_outlined,
                            title: 'Nenhum fornecedor cadastrado',
                            subtitle:
                                'Cadastre empresas e prestadores de serviço homologados pelo condomínio.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: _suppliers.length,
                            itemBuilder: (context, idx) {
                              final s = _suppliers[idx];
                              final avg = s['ratingAverage'] ?? 0;
                              final count = s['ratingCount'] ?? 0;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE0E7FF),
                                    child: Icon(
                                      Icons.engineering_rounded,
                                      color: Color(0xFF2F3FB0),
                                    ),
                                  ),
                                  title: Text(
                                    s['companyName'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Especialidade: ${s['serviceCategory'] ?? ''} • Contato: ${s['contactName'] ?? '—'}\n'
                                    'Tel.: ${s['phone'] ?? '—'} • Email: ${s['email'] ?? '—'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '★ $avg',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                      Text(
                                        '($count aval.)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
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
              ],
            ),
    );
  }
}

// ----------------------------------------------------
