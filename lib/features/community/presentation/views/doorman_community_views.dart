import '../dialogs/counter_proposal_dialog.dart';
import 'package:flutter/material.dart';
import '../../data/community_api.dart';

// ----------------------------------------------------
// 1. CONSULTA RÁPIDA DE PLACAS NA PORTARIA
// ----------------------------------------------------
class DoormanPlateCheckView extends StatefulWidget {
  const DoormanPlateCheckView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanPlateCheckView> createState() => _DoormanPlateCheckViewState();
}

class _DoormanPlateCheckViewState extends State<DoormanPlateCheckView> {
  final _plateController = TextEditingController();
  bool _searching = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) return;

    setState(() {
      _searching = true;
      _result = null;
      _error = null;
    });

    try {
      final res = await widget.api.checkPlate(widget.condominiumId, plate);
      if (mounted) {
        setState(() {
          _result = res;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao consultar placa: $e';
          _searching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final residentVehicles = (_result?['residentVehicles'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    final visitorAccesses = (_result?['visitorAccesses'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    final found = _result?['found'] == true;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Consultar Placa do Veículo',
                    hintText: 'Ex: ABC1D23 ou RJA9E88',
                    prefixIcon: Icon(Icons.directions_car_rounded),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded),
                label: const Text('Consultar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Exemplos de placa: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ...['RIO2A18', 'BRA3E24', 'ABC1234', 'XYZ9876'].map(
                  (sample) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(sample, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _plateController.text = sample;
                        _search();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_result != null && !found)
            Card(
              color: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFCA5A5))),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 32),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Placa não identificada no condomínio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF991B1B))),
                          SizedBox(height: 4),
                          Text('Este veículo não consta cadastrado como morador nem possui pré-autorização de visitante ativa.', style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (found)
            Expanded(
              child: ListView(
                children: [
                  if (residentVehicles.isNotEmpty) ...[
                    const Text('Veículo de Morador Cadastrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D))),
                    const SizedBox(height: 8),
                    ...residentVehicles.map((v) => Card(
                          color: const Color(0xFFF0FDF4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF86EFAC))),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.check_circle_rounded, color: Color(0xFF15803D))),
                            title: Text('${v['brandModel']} • ${v['color']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Placa: ${v['licensePlate']} • Unidade: ${v['unitIdentifier'] ?? '—'} (${v['sectorName'] ?? ''})\nMorador: ${v['ownerName'] ?? '—'} • Vaga: ${v['parkingSpot'] ?? '—'}'),
                            isThreeLine: true,
                          ),
                        )),
                    const SizedBox(height: 14),
                  ],
                  if (visitorAccesses.isNotEmpty) ...[
                    const Text('Veículo Autorizado para Visitante / Prestador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1D4ED8))),
                    const SizedBox(height: 8),
                    ...visitorAccesses.map((acc) => Card(
                          color: const Color(0xFFEFF6FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF93C5FD))),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.badge_rounded, color: Color(0xFF1D4ED8))),
                            title: Text('Visitante: ${acc['visitorName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Código de Acesso: ${acc['accessCode']} • Status: ${acc['status']}\nUnidade Destino: ${acc['unitIdentifier'] ?? '—'} • Morador Responsável: ${acc['residentName'] ?? '—'}'),
                            isThreeLine: true,
                            trailing: acc['status'] == 'AUTHORIZED'
                                ? FilledButton.tonal(
                                    onPressed: () async {
                                      await widget.api.checkInVisitor(acc['id']);
                                      _search();
                                    },
                                    child: const Text('Check-in'),
                                  )
                                : null,
                          ),
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 2. CONTROLE DE ACESSO & VISITANTES NA PORTARIA
// ----------------------------------------------------
class DoormanVisitorsView extends StatefulWidget {
  const DoormanVisitorsView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanVisitorsView> createState() => _DoormanVisitorsViewState();
}

class _DoormanVisitorsViewState extends State<DoormanVisitorsView> {
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
      if (mounted) setState(() { _visitors = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkIn(num id) async {
    await widget.api.checkInVisitor(id);
    _load();
  }

  Future<void> _checkOut(num id) async {
    await widget.api.checkOutVisitor(id);
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
              Text('Controle de Acessos (${_visitors.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visitors.isEmpty
                    ? const Center(child: Text('Nenhum visitante aguardando entrada.'))
                    : ListView.separated(
                        itemCount: _visitors.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final v = _visitors[idx];
                          final status = v['status']?.toString();
                          final isAuth = status == 'AUTHORIZED';
                          final isCheckedIn = status == 'CHECKED_IN';

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCheckedIn ? const Color(0xFFDCFCE7) : const Color(0xFFE0E7FF),
                                child: Icon(isCheckedIn ? Icons.login_rounded : Icons.access_time_rounded, color: isCheckedIn ? const Color(0xFF15803D) : const Color(0xFF2F3FB0)),
                              ),
                              title: Text(v['visitorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Código: ${v['accessCode'] ?? '—'} • Placa: ${v['vehiclePlate'] ?? 'Sem veículo'}\nUnidade: ${v['unitIdentifier'] ?? '—'} • Tipo: ${v['visitorType'] ?? ''}'),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAuth)
                                    FilledButton.icon(
                                      icon: const Icon(Icons.login_rounded, size: 16),
                                      label: const Text('Entrada'),
                                      onPressed: () => _checkIn(v['id']),
                                    ),
                                  if (isCheckedIn)
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.logout_rounded, size: 16),
                                      label: const Text('Saída'),
                                      onPressed: () => _checkOut(v['id']),
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
// 3. EVENTOS & LISTA DE CONVIDADOS NA PORTARIA
// ----------------------------------------------------
class DoormanGuestListsView extends StatefulWidget {
  const DoormanGuestListsView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanGuestListsView> createState() => _DoormanGuestListsViewState();
}

class _DoormanGuestListsViewState extends State<DoormanGuestListsView> {
  bool _loading = true;
  List<Map<String, dynamic>> _lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listGuestLists(widget.condominiumId);
      if (mounted) setState(() { _lists = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleCheckIn(num guestId) async {
    await widget.api.checkInGuest(guestId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? const Center(child: Text('Nenhuma lista de convidados para eventos agendados.'))
              : ListView.separated(
                  itemCount: _lists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final gl = _lists[idx];
                    final guests = (gl['guests'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
                    final presentCount = guests.where((g) => g['checkedIn'] == true).length;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: ExpansionTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.celebration_rounded, color: Color(0xFF2F3FB0))),
                        title: Text(gl['eventTitle'] ?? 'Evento', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Data: ${gl['eventDate'] ?? ''} • Presentes: $presentCount / ${guests.length}'),
                        children: [
                          ...guests.map((g) {
                            final checked = g['checkedIn'] == true;
                            return ListTile(
                              dense: true,
                              leading: Icon(checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: checked ? Colors.green : Colors.grey),
                              title: Text(g['guestName'] ?? '', style: TextStyle(fontWeight: checked ? FontWeight.bold : FontWeight.normal)),
                              subtitle: Text('Doc: ${g['documentNumber'] ?? 'Não informado'}'),
                              trailing: FilledButton.tonal(
                                onPressed: checked ? null : () => _toggleCheckIn(g['id']),
                                child: Text(checked ? 'Presente' : 'Check-in'),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ----------------------------------------------------
// 4. SMART LOCKERS NA PORTARIA
// ----------------------------------------------------
class DoormanSmartLockersView extends StatefulWidget {
  const DoormanSmartLockersView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanSmartLockersView> createState() => _DoormanSmartLockersViewState();
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
      if (mounted) setState(() { _lockers = list; _loading = false; });
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
              TextField(controller: comp, decoration: const InputDecoration(labelText: 'Nº do Compartimento *', hintText: 'Ex: A-01')),
              const SizedBox(height: 10),
              TextField(controller: unitId, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ID da Unidade Destino *')),
              const SizedBox(height: 10),
              TextField(controller: courier, decoration: const InputDecoration(labelText: 'Entregadora (ex: Amazon, Sedex)')),
              const SizedBox(height: 10),
              TextField(controller: tracking, decoration: const InputDecoration(labelText: 'Código de Rastreio')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Depositar & Gerar PIN')),
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
          trackingCode: tracking.text.trim().isEmpty ? null : tracking.text.trim(),
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
              Text('Armários Inteligentes (${_lockers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                ? const Center(child: CircularProgressIndicator())
                : _lockers.isEmpty
                    ? const Center(child: Text('Nenhum compartimento ocupado.'))
                    : ListView.separated(
                        itemCount: _lockers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final l = _lockers[idx];
                          final isOccupied = l['status'] == 'OCCUPIED';
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isOccupied ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                child: Icon(isOccupied ? Icons.lock_clock_rounded : Icons.lock_open_rounded, color: isOccupied ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                              ),
                              title: Text('Compartimento ${l['compartmentNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Rastreio: ${l['trackingCode'] ?? '—'} • PIN gerado: ${l['pinCode'] ?? '—'}'),
                              trailing: Chip(
                                label: Text(l['status'] ?? '', style: const TextStyle(fontSize: 11)),
                                backgroundColor: isOccupied ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
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
      if (mounted) setState(() { _items = list; _loading = false; });
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
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Objeto *', hintText: 'Ex: Chaveiro com tag azul')),
              const SizedBox(height: 10),
              TextField(controller: loc, decoration: const InputDecoration(labelText: 'Local onde foi achado', hintText: 'Ex: Elevador Social Bloco A')),
              const SizedBox(height: 10),
              TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição detalhada')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );

    if (ok == true && title.text.isNotEmpty) {
      await widget.api.createLostFound(
        condoId: widget.condominiumId,
        type: 'FOUND',
        title: title.text.trim(),
        description: desc.text.trim().isEmpty ? 'Sem detalhes adicionais' : desc.text.trim(),
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
              Text('Achados e Perdidos (${_items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('Nenhum item guardado na portaria.'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final it = _items[idx];
                          final isReturned = it['status'] == 'RETURNED';

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.search_rounded, color: Color(0xFF2F3FB0))),
                              title: Text(it['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Local: ${it['location'] ?? 'Condomínio'}\n${it['description'] ?? ''}'),
                              isThreeLine: true,
                              trailing: isReturned
                                  ? const Chip(label: Text('Devolvido', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFFDCFCE7))
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
class DoormanReservationsView extends StatefulWidget {
  const DoormanReservationsView({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<DoormanReservationsView> createState() => _DoormanReservationsViewState();
}

class _DoormanReservationsViewState extends State<DoormanReservationsView> {
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String _filter = 'ALL'; // ALL, PENDING, CONFIRMED, COUNTER_PROPOSED

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getCondominiumReservations(widget.condominiumId);
      if (mounted) setState(() { _reservations = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'ALL') return _reservations;
    return _reservations.where((r) => r['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              IconButton(
                tooltip: 'Atualizar',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Todas', 'ALL'),
                const SizedBox(width: 8),
                _filterChip('Pendentes de Aprovação', 'PENDING'),
                const SizedBox(width: 8),
                _filterChip('Contraproposta Enviada', 'COUNTER_PROPOSED'),
                const SizedBox(width: 8),
                _filterChip('Confirmadas', 'CONFIRMED'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      _filter == 'PENDING'
                          ? 'Nenhuma reserva aguardando aprovação.'
                          : 'Nenhuma reserva encontrada.',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final r = _filtered[idx];
                      final id = r['id'] as num;
                      final area = r['commonAreaName'] ?? r['commonArea'] ?? 'Área';
                      final resident = r['reservedByName'] ?? r['residentName'] ?? 'Morador';
                      final phone = r['contactPhone'] ?? '';
                      final status = r['status']?.toString() ?? 'PENDING';
                      final startAt = r['startAt']?.toString() ?? '';
                      final endAt = r['endAt']?.toString() ?? '';
                      final notes = r['notes']?.toString();
                      final counterNotes = r['counterProposalNotes']?.toString();
                      final propStart = r['proposedStartAt']?.toString();

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                                  CircleAvatar(
                                    backgroundColor: status == 'CONFIRMED'
                                        ? const Color(0xFFDCFCE7)
                                        : status == 'COUNTER_PROPOSED'
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFDBEAFE),
                                    child: Icon(
                                      status == 'CONFIRMED'
                                          ? Icons.check_circle_rounded
                                          : status == 'COUNTER_PROPOSED'
                                          ? Icons.schedule_send_rounded
                                          : Icons.hourglass_top_rounded,
                                      color: status == 'CONFIRMED'
                                          ? const Color(0xFF15803D)
                                          : status == 'COUNTER_PROPOSED'
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF2563EB),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          area.toString(),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                        ),
                                        Text(
                                          'Morador: $resident ${phone.isNotEmpty ? "• $phone" : ""}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Horário: ${_formatDt(startAt)} até ${_formatDt(endAt)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        if (notes != null && notes.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('Observação: $notes', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                        ],
                                        if (status == 'COUNTER_PROPOSED' && counterNotes != null) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'Contraproposta enviada: $counterNotes ${propStart != null ? "(${_formatDt(propStart)})" : ""}',
                                              style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.w600),
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
                                        backgroundColor: const Color(0xFF15803D),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Aceitar Reserva'),
                                      onPressed: () => _approve(id),
                                    ),
                                    FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFFEF3C7),
                                        foregroundColor: const Color(0xFFB45309),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.schedule_send_rounded, size: 16),
                                      label: const Text('Contraproposta'),
                                      onPressed: () => _openCounterProposal(r),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.edit_rounded, size: 16),
                                      label: const Text('Ajustar & Salvar'),
                                      onPressed: () => _openModifyAndConfirm(r),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFDC2626),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.close_rounded, size: 16),
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

  Widget _filterChip(String label, String code) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == code,
      onSelected: (val) {
        if (val) setState(() => _filter = code);
      },
    );
  }

  String _formatDt(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
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
          const SnackBar(content: Text('Reserva aprovada com sucesso!'), backgroundColor: Color(0xFF15803D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
          decoration: const InputDecoration(labelText: 'Motivo da recusa (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar Recusa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.api.rejectReservation(id, ctrl.text.trim());
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
    final startCtrl = TextEditingController(text: r['startAt']?.toString() ?? '');
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
                decoration: const InputDecoration(labelText: 'Início (ISO ex: 2026-11-10T14:00:00)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(labelText: 'Fim (ISO ex: 2026-11-10T18:00:00)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Observação do Porteiro'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar Reserva'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final start = DateTime.parse(startCtrl.text.trim());
        final end = DateTime.parse(endCtrl.text.trim());
        await widget.api.modifyAndConfirmReservation(
          reservationId: r['id'] as num,
          startAt: start,
          endAt: end,
          notes: notesCtrl.text.trim(),
        );
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}
