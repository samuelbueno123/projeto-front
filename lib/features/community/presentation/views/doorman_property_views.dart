part of 'doorman_community_views.dart';

class DoormanSmartLockersView extends StatefulWidget {
  const DoormanSmartLockersView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanSmartLockersView> createState() =>
      _DoormanSmartLockersViewState();
}

class _DoormanSmartLockersViewState extends State<DoormanSmartLockersView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _lockers = [];
  List<Map<String, dynamic>> _units = [];

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
      final results = await Future.wait<dynamic>([
        widget.api.listLockers(widget.condominiumId),
        widget.api.api
            .get('/condominiums/${widget.condominiumId}/directory/units')
            .catchError((_) => <dynamic>[]),
      ]);
      final lockers = results[0] is List<Map<String, dynamic>>
          ? results[0] as List<Map<String, dynamic>>
          : <Map<String, dynamic>>[];
      final units = results[1] is List
          ? (results[1] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _lockers = lockers;
          _units = units;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar os lockers: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _depositDialog() async {
    final comp = TextEditingController();
    final courier = TextEditingController();
    final tracking = TextEditingController();
    final manualUnitCtrl = TextEditingController();
    num? selectedUnitId = _units.isNotEmpty ? _units.first['id'] as num? : null;
    String? inlineError;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Depositar em Armário Inteligente'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (inlineError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        inlineError!,
                        style: const TextStyle(
                          color: SaaSColors.error,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  TextField(
                    controller: comp,
                    decoration: const InputDecoration(
                      labelText: 'Nº do Compartimento *',
                      hintText: 'Ex: A-01',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_units.isNotEmpty)
                    DropdownButtonFormField<num>(
                      initialValue: selectedUnitId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Unidade Destino *',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      items: _units.map((u) {
                        final id = u['id'] as num?;
                        final sector = u['sectorName']?.toString() ?? '';
                        final ident = u['identifier']?.toString() ?? '#$id';
                        return DropdownMenuItem<num>(
                          value: id,
                          child: Text(
                            sector.isEmpty
                                ? 'Unidade $ident'
                                : '$sector • Unidade $ident',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDlgState(() => selectedUnitId = v),
                    )
                  else
                    TextField(
                      controller: manualUnitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ID da Unidade Destino *',
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courier,
                    decoration: const InputDecoration(
                      labelText: 'Entregadora (ex: Amazon, Sedex)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tracking,
                    decoration: const InputDecoration(
                      labelText: 'Código de Rastreio',
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
                final resolvedUnit = _units.isNotEmpty
                    ? selectedUnitId
                    : num.tryParse(manualUnitCtrl.text.trim());
                if (comp.text.trim().isEmpty || resolvedUnit == null) {
                  setDlgState(
                    () => inlineError =
                        'Informe o compartimento e selecione a unidade destino.',
                  );
                  return;
                }
                selectedUnitId = resolvedUnit;
                Navigator.pop(ctx, true);
              },
              child: const Text('Depositar & Gerar PIN'),
            ),
          ],
        ),
      ),
    );

    final compVal = comp.text.trim();
    final courierVal = courier.text.trim();
    final trackingVal = tracking.text.trim();
    comp.dispose();
    courier.dispose();
    tracking.dispose();
    manualUnitCtrl.dispose();

    if (ok == true && selectedUnitId != null && compVal.isNotEmpty) {
      try {
        await widget.api.depositLocker(
          condoId: widget.condominiumId,
          compartmentNumber: compVal,
          unitId: selectedUnitId!,
          courierName: courierVal.isEmpty ? null : courierVal,
          trackingCode: trackingVal.isEmpty ? null : trackingVal,
        );
        if (mounted) {
          SaaSFeedback.showSuccess(
            context,
            'Encomenda depositada no locker $compVal com PIN gerado!',
          );
        }
        _load();
      } catch (e) {
        if (mounted) {
          SaaSFeedback.showError(context, 'Erro ao depositar no locker: $e');
        }
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
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo Depósito'),
                onPressed: _depositDialog,
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
                : _error != null
                ? SaaSErrorState(message: _error!, onRetry: _load)
                : _lockers.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.all_inbox_outlined,
                    title: 'Nenhum compartimento ocupado',
                    subtitle:
                        'Todos os armários inteligentes estão livres no momento.',
                  )
                : ListView.separated(
                    itemCount: _lockers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final l = _lockers[idx];
                      final isOccupied = l['status'] == 'OCCUPIED';
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOccupied
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFDCFCE7),
                            child: Icon(
                              isOccupied
                                  ? Icons.lock_clock_rounded
                                  : Icons.lock_open_rounded,
                              color: isOccupied
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF15803D),
                            ),
                          ),
                          title: Text(
                            'Compartimento ${l['compartmentNumber']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Rastreio: ${l['trackingCode'] ?? '—'} • PIN gerado: ${l['pinCode'] ?? '—'}',
                          ),
                          trailing: Chip(
                            label: Text(
                              l['status'] ?? '',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: isOccupied
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFDCFCE7),
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
// 5. ACHADOS & PERDIDOS NA PORTARIA
// ----------------------------------------------------
class DoormanLostFoundView extends StatefulWidget {
  const DoormanLostFoundView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanLostFoundView> createState() => _DoormanLostFoundViewState();
}

class _DoormanLostFoundViewState extends State<DoormanLostFoundView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
      final list = await widget.api.listLostFound(widget.condominiumId);
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar achados e perdidos: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openNewItemDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final loc = TextEditingController();
    String? inlineError;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Registrar Objeto Encontrado'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inlineError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      inlineError!,
                      style: const TextStyle(color: SaaSColors.error, fontSize: 12),
                    ),
                  ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Objeto *',
                    hintText: 'Ex: Chaveiro com tag azul',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: loc,
                  decoration: const InputDecoration(
                    labelText: 'Local onde foi achado',
                    hintText: 'Ex: Elevador Social Bloco A',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: desc,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição detalhada',
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
              onPressed: () {
                if (title.text.trim().isEmpty) {
                  setDlgState(() => inlineError = 'Informe o nome do objeto.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    final titleVal = title.text.trim();
    final descVal = desc.text.trim();
    final locVal = loc.text.trim();
    title.dispose();
    desc.dispose();
    loc.dispose();

    if (ok == true && titleVal.isNotEmpty) {
      try {
        await widget.api.createLostFound(
          condoId: widget.condominiumId,
          type: 'FOUND',
          title: titleVal,
          description: descVal.isEmpty ? 'Sem detalhes adicionais' : descVal,
          location: locVal.isEmpty ? null : locVal,
        );
        _load();
      } catch (e) {
        if (mounted) SaaSFeedback.showError(context, 'Erro ao registrar: $e');
      }
    }
  }

  Future<void> _returnItem(num id) async {
    try {
      await widget.api.returnLostFound(id);
      _load();
    } catch (e) {
      if (mounted) SaaSFeedback.showError(context, 'Erro ao devolver item: $e');
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
                'Achados e Perdidos (${_items.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Registrar Item'),
                onPressed: _openNewItemDialog,
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
                        message: 'Carregando achados e perdidos...',
                      ),
                    ),
                  )
                : _error != null
                ? SaaSErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.inventory_outlined,
                    title: 'Nenhum item guardado',
                    subtitle:
                        'Não há objetos perdidos sob custódia da portaria.',
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final it = _items[idx];
                      final isReturned = it['status'] == 'RETURNED';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0E7FF),
                            child: Icon(
                              Icons.search_rounded,
                              color: Color(0xFF2F3FB0),
                            ),
                          ),
                          title: Text(
                            it['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Local: ${it['location'] ?? 'Condomínio'}\n${it['description'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: isReturned
                              ? const Chip(
                                  label: Text(
                                    'Devolvido',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: Color(0xFFDCFCE7),
                                )
                              : FilledButton.tonal(
                                  onPressed: () => _returnItem(it['id']),
                                  child: const Text('Devolver ao Dono'),
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
// 6. GESTÃO DE RESERVAS NA PORTARIA (APROVAÇÃO & CONTRAPROPOSTAS)
// ----------------------------------------------------
