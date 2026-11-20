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
  List<Map<String, dynamic>> _lockers = [];

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _depositDialog() async {
    final comp = TextEditingController();
    final unitId = TextEditingController();
    final courier = TextEditingController();
    final tracking = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Depositar em Armário Inteligente'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: comp,
                decoration: const InputDecoration(
                  labelText: 'Nº do Compartimento *',
                  hintText: 'Ex: A-01',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unitId,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Depositar & Gerar PIN'),
          ),
        ],
      ),
    );

    if (ok == true && comp.text.isNotEmpty && unitId.text.isNotEmpty) {
      final uId = num.tryParse(unitId.text.trim());
      if (uId != null) {
        await widget.api.depositLocker(
          condoId: widget.condominiumId,
          compartmentNumber: comp.text.trim(),
          unitId: uId,
          courierName: courier.text.trim().isEmpty ? null : courier.text.trim(),
          trackingCode: tracking.text.trim().isEmpty
              ? null
              : tracking.text.trim(),
        );
        _load();
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
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listLostFound(widget.condominiumId);
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewItemDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final loc = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Objeto Encontrado'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (ok == true && title.text.isNotEmpty) {
      await widget.api.createLostFound(
        condoId: widget.condominiumId,
        type: 'FOUND',
        title: title.text.trim(),
        description: desc.text.trim().isEmpty
            ? 'Sem detalhes adicionais'
            : desc.text.trim(),
        location: loc.text.trim().isEmpty ? null : loc.text.trim(),
      );
      _load();
    }
  }

  Future<void> _returnItem(num id) async {
    await widget.api.returnLostFound(id);
    _load();
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
