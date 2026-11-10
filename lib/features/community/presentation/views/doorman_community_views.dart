import 'dart:convert';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/utils/formatters.dart';
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

  Future<void> _deny(num id) async {
    await widget.api.denyVisitor(id);
    _load();
  }

  Future<void> _openValidateQrDialog() async {
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Expanded(child: Text('Validar QR Code / Código do Convite')),
          ],
        ),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Cole o Payload do QR Code ou Código de Acesso',
            hintText: 'Ex: ANCORA-VISITOR|... ou 8A4F2C',
            prefixIcon: Icon(Icons.qr_code_2_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text('Validar & Liberar Entrada'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true && codeCtrl.text.trim().isNotEmpty) {
      try {
        final res = await widget.api.validateVisitorQr(
          widget.condominiumId,
          qrCodeOrAccessCode: codeCtrl.text.trim(),
          autoCheckIn: true,
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF15803D),
              content: Text('Entrada liberada para ${res['visitorName'] ?? 'visitante'} (${res['unitLabel'] ?? ''})!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('Convite inválido ou expirado: $e')),
          );
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
              Text('Controle de Acessos (${_visitors.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Validar QR / Código'),
                    onPressed: _openValidateQrDialog,
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: SaaSLoadingState(message: 'Carregando visitantes da portaria...')))
                : _visitors.isEmpty
                    ? const SaaSEmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'Nenhum visitante aguardando',
                        subtitle: 'Não há visitantes pré-autorizados ou na fila de entrada.',
                      )
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
                                  if (isAuth) ...[
                                    FilledButton.icon(
                                      icon: const Icon(Icons.login_rounded, size: 16),
                                      label: const Text('Entrada'),
                                      onPressed: () => _checkIn(v['id']),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                                      onPressed: () => _deny(v['id']),
                                      child: const Text('Recusar'),
                                    ),
                                  ],
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
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: SaaSLoadingState(message: 'Carregando listas de convidados...')))
          : _lists.isEmpty
              ? const SaaSEmptyState(
                  icon: Icons.celebration_outlined,
                  title: 'Nenhuma lista de convidados',
                  subtitle: 'Não há listas vinculadas a eventos ou reservas ativas.',
                )
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
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: SaaSLoadingState(message: 'Carregando status dos lockers...')))
                : _lockers.isEmpty
                    ? const SaaSEmptyState(
                        icon: Icons.all_inbox_outlined,
                        title: 'Nenhum compartimento ocupado',
                        subtitle: 'Todos os armários inteligentes estão livres no momento.',
                      )
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
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: SaaSLoadingState(message: 'Carregando achados e perdidos...')))
                : _items.isEmpty
                    ? const SaaSEmptyState(
                        icon: Icons.inventory_outlined,
                        title: 'Nenhum item guardado',
                        subtitle: 'Não há objetos perdidos sob custódia da portaria.',
                      )
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
  String _category = 'SCHEDULED'; // SCHEDULED, PAST, CANCELLED
  String _subFilter = 'ALL'; // ALL, PENDING, CONFIRMED, COUNTER_PROPOSED

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
                      color: _category == 'CANCELLED' ? Colors.white : const Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: _category == 'CANCELLED',
                  selectedColor: const Color(0xFFDC2626),
                  backgroundColor: isDark
                      ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                      : const Color(0xFFFEE2E2),
                  side: BorderSide(
                    color: _category == 'CANCELLED' ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5),
                  ),
                  avatar: Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: _category == 'CANCELLED' ? Colors.white : const Color(0xFFDC2626),
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
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: SaaSLoadingState(message: 'Carregando reservas de áreas comuns...')))
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
                      final area = r['commonAreaName'] ?? r['commonArea'] ?? 'Área';
                      final resident = r['reservedByName'] ?? r['residentName'] ?? 'Morador';
                      final phone = r['contactPhone'] ?? '';
                      final status = r['status']?.toString() ?? 'PENDING';
                      final isItemCancelled = _isCancelled(r);
                      final startAt = r['startAt']?.toString() ?? '';
                      final endAt = r['endAt']?.toString() ?? '';
                      final notes = r['notes']?.toString();
                      final counterNotes = r['counterProposalNotes']?.toString();
                      final propStart = r['proposedStartAt']?.toString();
                      final imgUrl = (r['imageUrl'] ?? r['commonAreaImageUrl'])?.toString();

                      return Card(
                        elevation: 0,
                        color: isItemCancelled
                            ? (isDark
                                ? const Color(0xFF450A0A).withValues(alpha: 0.35)
                                : const Color(0xFFFEF2F2))
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isItemCancelled
                                ? const Color(0xFFFCA5A5)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                       child: (imgUrl != null && imgUrl.isNotEmpty)
                                           ? (imgUrl.startsWith('data:')
                                               ? Image.memory(
                                                   base64Decode(imgUrl.split(',').last),
                                                   fit: BoxFit.cover,
                                                   errorBuilder: (_, __, ___) => CircleAvatar(
                                                     backgroundColor: isItemCancelled
                                                         ? const Color(0xFFFEE2E2)
                                                         : status == 'CONFIRMED'
                                                         ? const Color(0xFFDCFCE7)
                                                         : status == 'COUNTER_PROPOSED'
                                                         ? const Color(0xFFFEF3C7)
                                                         : const Color(0xFFDBEAFE),
                                                     child: Icon(
                                                       isItemCancelled
                                                           ? Icons.cancel_outlined
                                                           : status == 'CONFIRMED'
                                                           ? Icons.check_circle_rounded
                                                           : status == 'COUNTER_PROPOSED'
                                                           ? Icons.schedule_send_rounded
                                                           : Icons.hourglass_top_rounded,
                                                       color: isItemCancelled
                                                           ? const Color(0xFFDC2626)
                                                           : status == 'CONFIRMED'
                                                           ? const Color(0xFF15803D)
                                                           : status == 'COUNTER_PROPOSED'
                                                           ? const Color(0xFFB45309)
                                                           : const Color(0xFF2563EB),
                                                       size: 20,
                                                     ),
                                                   ),
                                                 )
                                               : Image.network(
                                                   imgUrl,
                                                   fit: BoxFit.cover,
                                                   errorBuilder: (_, __, ___) => CircleAvatar(
                                                     backgroundColor: isItemCancelled
                                                         ? const Color(0xFFFEE2E2)
                                                         : status == 'CONFIRMED'
                                                         ? const Color(0xFFDCFCE7)
                                                         : status == 'COUNTER_PROPOSED'
                                                         ? const Color(0xFFFEF3C7)
                                                         : const Color(0xFFDBEAFE),
                                                     child: Icon(
                                                       isItemCancelled
                                                           ? Icons.cancel_outlined
                                                           : status == 'CONFIRMED'
                                                           ? Icons.check_circle_rounded
                                                           : status == 'COUNTER_PROPOSED'
                                                           ? Icons.schedule_send_rounded
                                                           : Icons.hourglass_top_rounded,
                                                       color: isItemCancelled
                                                           ? const Color(0xFFDC2626)
                                                           : status == 'CONFIRMED'
                                                           ? const Color(0xFF15803D)
                                                           : status == 'COUNTER_PROPOSED'
                                                           ? const Color(0xFFB45309)
                                                           : const Color(0xFF2563EB),
                                                       size: 20,
                                                     ),
                                                   ),
                                                 ))
                                           : CircleAvatar(
                                               backgroundColor: isItemCancelled
                                                   ? const Color(0xFFFEE2E2)
                                                   : status == 'CONFIRMED'
                                                   ? const Color(0xFFDCFCE7)
                                                   : status == 'COUNTER_PROPOSED'
                                                   ? const Color(0xFFFEF3C7)
                                                   : const Color(0xFFDBEAFE),
                                               child: Icon(
                                                 isItemCancelled
                                                     ? Icons.cancel_outlined
                                                     : status == 'CONFIRMED'
                                                     ? Icons.check_circle_rounded
                                                     : status == 'COUNTER_PROPOSED'
                                                     ? Icons.schedule_send_rounded
                                                     : Icons.hourglass_top_rounded,
                                                 color: isItemCancelled
                                                     ? const Color(0xFFDC2626)
                                                     : status == 'CONFIRMED'
                                                     ? const Color(0xFF15803D)
                                                     : status == 'COUNTER_PROPOSED'
                                                     ? const Color(0xFFB45309)
                                                     : const Color(0xFF2563EB),
                                                 size: 20,
                                               ),
                                             ),
                                     ),
                                   ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          area.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: isItemCancelled ? const Color(0xFFB91C1C) : null,
                                          ),
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
                                        if (isItemCancelled) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFF87171)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFDC2626)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'CANCELADA / RECUSADA',
                                                  style: TextStyle(
                                                    color: Color(0xFFDC2626),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 10.5,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
