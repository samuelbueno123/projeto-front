part of 'community_hub_view.dart';

// 5. VEÍCULOS & VAGAS
// ----------------------------------------------------
class _VehiclesSubView extends StatefulWidget {
  const _VehiclesSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_VehiclesSubView> createState() => _VehiclesSubViewState();
}

class _VehiclesSubViewState extends State<_VehiclesSubView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _parkingSpots = [];

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
      final results = await Future.wait([
        widget.api.listVehicles(widget.condominiumId),
        widget.api
            .listParkingSpots(widget.condominiumId)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (mounted) {
        setState(() {
          _vehicles = results[0];
          _parkingSpots = results[1];
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

  Future<void> _openParkingSpotsDialog() async {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String spotType = 'RESIDENT';

    try {
      await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.local_parking_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Expanded(child: Text('Gerenciar Vagas de Garagem')),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.canManage) ...[
                    const Text(
                      'Nova Vaga de Garagem',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Código da Vaga *',
                              hintText: 'Ex: G-101',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: spotType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'RESIDENT',
                                child: Text('Morador'),
                              ),
                              DropdownMenuItem(
                                value: 'VISITOR',
                                child: Text('Visitante'),
                              ),
                              DropdownMenuItem(
                                value: 'ACCESSIBLE',
                                child: Text('PCD / Idoso'),
                              ),
                              DropdownMenuItem(
                                value: 'MOTORCYCLE',
                                child: Text('Moto'),
                              ),
                            ],
                            onChanged: (v) =>
                                setD(() => spotType = v ?? 'RESIDENT'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Localização / Observação',
                              hintText: 'Subsolo 1',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Criar Vaga'),
                          onPressed: () async {
                            if (codeCtrl.text.trim().isEmpty) return;
                            try {
                              await widget.api.createParkingSpot(
                                condoId: widget.condominiumId,
                                code: codeCtrl.text.trim(),
                                spotType: spotType,
                                description: descCtrl.text.trim(),
                              );
                              codeCtrl.clear();
                              descCtrl.clear();
                              await _load();
                              setD(() {});
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                  ],
                  Text(
                    'Vagas Cadastradas (${_parkingSpots.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_parkingSpots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Nenhuma vaga cadastrada.'),
                    )
                  else
                    ..._parkingSpots.map(
                      (sp) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.local_parking_rounded,
                          color: sp['status'] == 'OCCUPIED'
                              ? const Color(0xFFD97706)
                              : const Color(0xFF15803D),
                        ),
                        title: Text(
                          '${sp['code']} (${sp['spotType'] ?? 'RESIDENT'})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Status: ${sp['status'] ?? 'AVAILABLE'} • ${sp['unitLabel'] ?? sp['description'] ?? 'Livre'}',
                        ),
                        trailing: widget.canManage
                            ? IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  await widget.api.deleteParkingSpot(sp['id']);
                                  await _load();
                                  setD(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
    } finally {
      codeCtrl.dispose();
      descCtrl.dispose();
    }
  }

  Future<void> _openNewVehicleDialog() async {
    final model = TextEditingController();
    final plate = TextEditingController();
    final color = TextEditingController();
    final spot = TextEditingController();
    String type = 'CAR';
    num? selectedSpotId;

    try {
      final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Cadastrar Veículo'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'CAR', child: Text('Carro')),
                      DropdownMenuItem(
                        value: 'MOTORCYCLE',
                        child: Text('Moto'),
                      ),
                      DropdownMenuItem(
                        value: 'BICYCLE',
                        child: Text('Bicicleta'),
                      ),
                    ],
                    onChanged: (v) => setD(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: model,
                    decoration: const InputDecoration(
                      labelText: 'Modelo / Marca *',
                      hintText: 'Ex: Honda Civic',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: plate,
                    decoration: const InputDecoration(
                      labelText: 'Placa *',
                      hintText: 'Ex: ABC1D23',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: color,
                    decoration: const InputDecoration(
                      labelText: 'Cor *',
                      hintText: 'Ex: Prata',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_parkingSpots.isNotEmpty) ...[
                    DropdownButtonFormField<num?>(
                      value: selectedSpotId,
                      decoration: const InputDecoration(
                        labelText: 'Vincular Vaga Cadastrada (opcional)',
                      ),
                      items: [
                        const DropdownMenuItem<num?>(
                          value: null,
                          child: Text('Informar manualmente / Sem vaga fixa'),
                        ),
                        ..._parkingSpots.map(
                          (s) => DropdownMenuItem<num?>(
                            value: s['id'] as num?,
                            child: Text(
                              '${s['code']} (${s['status'] ?? 'AVAILABLE'})',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setD(() => selectedSpotId = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: spot,
                    decoration: const InputDecoration(
                      labelText: 'Identificação da Vaga',
                      hintText: 'Ex: Vaga 102',
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
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

      final modelVal = model.text.trim();
      final plateVal = plate.text.trim().toUpperCase();
      final colorVal = color.text.trim();
      final spotVal = spot.text.trim();
      if (ok == true && modelVal.isNotEmpty && plateVal.isNotEmpty) {
        try {
          await widget.api.createVehicle(
            condoId: widget.condominiumId,
            type: type,
            brandModel: modelVal,
            color: colorVal.isEmpty ? 'Padrão' : colorVal,
            licensePlate: plateVal,
            parkingSpot: spotVal.isEmpty ? null : spotVal,
            parkingSpotId: selectedSpotId,
          );
          _load();
        } catch (e) {
          if (mounted) {
            SaaSFeedback.showError(context, 'Erro ao cadastrar veículo: $e');
          }
        }
      }
    } finally {
      model.dispose();
      plate.dispose();
      color.dispose();
      spot.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Frota de Veículos (${_vehicles.length}) • Vagas (${_parkingSpots.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.local_parking_rounded, size: 18),
                    label: Text(
                      widget.canManage ? 'Gerenciar Vagas' : 'Ver Vagas',
                    ),
                    onPressed: _openParkingSpotsDialog,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar Veículo'),
                    onPressed: _openNewVehicleDialog,
                  ),
                ],
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
                        message: 'Carregando veículos cadastrados...',
                      ),
                    ),
                  )
                : _error != null
                ? SaaSErrorState(
                    message: 'Falha ao carregar veículos: $_error',
                    onRetry: _load,
                  )
                : _vehicles.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'Nenhum veículo registrado',
                    subtitle:
                        'Cadastre seus carros ou motos para controle de acesso às vagas.',
                  )
                : ListView.separated(
                    itemCount: _vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final v = _vehicles[idx];
                      final status = v['status']?.toString() ?? 'APPROVED';
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
                              Icons.directions_car_rounded,
                              color: Color(0xFF2F3FB0),
                            ),
                          ),
                          title: Text(
                            '${v['brandModel']} (${v['color']})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Placa: ${v['licensePlate']} • Vaga: ${v['parkingSpotCode'] ?? v['parkingSpot'] ?? 'Livre / Rotativa'}',
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Unidade: ${v['unitLabel'] ?? '-'} • Proprietário: ${v['ownerName'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.canManage &&
                                  status == 'PENDING_APPROVAL') ...[
                                IconButton(
                                  tooltip: 'Aprovar Veículo',
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: Color(0xFF15803D),
                                  ),
                                  onPressed: () async {
                                    await widget.api.approveVehicle(v['id']);
                                    _load();
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Recusar Veículo',
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Color(0xFFDC2626),
                                  ),
                                  onPressed: () async {
                                    await widget.api.rejectVehicle(v['id']);
                                    _load();
                                  },
                                ),
                              ],
                              Chip(
                                label: Text(
                                  status,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: status == 'APPROVED'
                                    ? const Color(0xFFDCFCE7)
                                    : (status == 'REJECTED'
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFFEF3C7)),
                              ),
                              IconButton(
                                tooltip: 'Remover Veículo',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () async {
                                  await widget.api.deleteVehicle(v['id']);
                                  _load();
                                },
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
// 6. CENSO DE PETS
// ----------------------------------------------------
class _PetsSubView extends StatefulWidget {
  const _PetsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_PetsSubView> createState() => _PetsSubViewState();
}

class _PetsSubViewState extends State<_PetsSubView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pets = [];

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
      final list = await widget.api.listPets(widget.condominiumId);
      if (mounted) {
        setState(() {
          _pets = list;
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

  Future<void> _openNewPetDialog() async {
    final name = TextEditingController();
    final breed = TextEditingController();
    String species = 'DOG';
    String size = 'MEDIUM';
    bool vaccinated = true;

    try {
      final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Cadastrar Animal de Estimação'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: species,
                    decoration: const InputDecoration(labelText: 'Espécie'),
                    items: const [
                      DropdownMenuItem(value: 'DOG', child: Text('Cão')),
                      DropdownMenuItem(value: 'CAT', child: Text('Gato')),
                      DropdownMenuItem(value: 'BIRD', child: Text('Pássaro')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Outro')),
                    ],
                    onChanged: (v) => setD(() => species = v ?? species),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Pet *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: breed,
                    decoration: const InputDecoration(labelText: 'Raça'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: size,
                    decoration: const InputDecoration(labelText: 'Porte'),
                    items: const [
                      DropdownMenuItem(value: 'SMALL', child: Text('Pequeno')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Médio')),
                      DropdownMenuItem(value: 'LARGE', child: Text('Grande')),
                    ],
                    onChanged: (v) => setD(() => size = v ?? size),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Vacinação em dia'),
                    value: vaccinated,
                    onChanged: (v) => setD(() => vaccinated = v),
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
              child: const Text('Cadastrar Pet'),
            ),
          ],
        ),
      ),
    );

      final nameVal = name.text.trim();
      final breedVal = breed.text.trim();
      if (ok == true && nameVal.isNotEmpty) {
        try {
          await widget.api.createPet(
            condoId: widget.condominiumId,
            name: nameVal,
            species: species,
            breed: breedVal.isEmpty ? null : breedVal,
            size: size,
            vaccinated: vaccinated,
          );
          _load();
        } catch (e) {
          if (mounted) {
            SaaSFeedback.showError(context, 'Erro ao cadastrar pet: $e');
          }
        }
      }
    } finally {
      name.dispose();
      breed.dispose();
    }
  }

  Future<void> _openEditPetDialog(Map<String, dynamic> pet) async {
    final name = TextEditingController(text: pet['name']?.toString() ?? '');
    final breed = TextEditingController(text: pet['breed']?.toString() ?? '');
    final notes = TextEditingController(text: pet['notes']?.toString() ?? '');
    final managerNotes = TextEditingController(
      text: pet['managerNotes']?.toString() ?? '',
    );
    String species = pet['species']?.toString() ?? 'DOG';
    String size = pet['size']?.toString() ?? 'MEDIUM';
    bool vaccinated = pet['vaccinated'] == true;

    try {
      final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Editar Cadastro do Pet'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: ['DOG', 'CAT', 'BIRD', 'OTHER'].contains(species)
                        ? species
                        : 'DOG',
                    decoration: const InputDecoration(labelText: 'Espécie'),
                    items: const [
                      DropdownMenuItem(value: 'DOG', child: Text('Cão')),
                      DropdownMenuItem(value: 'CAT', child: Text('Gato')),
                      DropdownMenuItem(value: 'BIRD', child: Text('Pássaro')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Outro')),
                    ],
                    onChanged: (v) => setD(() => species = v ?? species),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Pet *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: breed,
                    decoration: const InputDecoration(labelText: 'Raça'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: ['SMALL', 'MEDIUM', 'LARGE'].contains(size)
                        ? size
                        : 'MEDIUM',
                    decoration: const InputDecoration(labelText: 'Porte'),
                    items: const [
                      DropdownMenuItem(value: 'SMALL', child: Text('Pequeno')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Médio')),
                      DropdownMenuItem(value: 'LARGE', child: Text('Grande')),
                    ],
                    onChanged: (v) => setD(() => size = v ?? size),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Vacinação em dia'),
                    value: vaccinated,
                    onChanged: (v) => setD(() => vaccinated = v),
                  ),
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(
                      labelText: 'Observações do Tutor',
                    ),
                  ),
                  if (widget.canManage) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: managerNotes,
                      decoration: const InputDecoration(
                        labelText: 'Observações da Administração / Síndico',
                      ),
                    ),
                  ],
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
              child: const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );

      final nameVal = name.text.trim();
      final breedVal = breed.text.trim();
      final notesVal = notes.text.trim();
      final managerNotesVal = managerNotes.text.trim();
      if (ok == true && nameVal.isNotEmpty) {
        try {
          await widget.api.updatePet(
            pet['id'],
            name: nameVal,
            species: species,
            breed: breedVal,
            size: size,
            vaccinated: vaccinated,
            notes: notesVal,
            managerNotes: widget.canManage ? managerNotesVal : null,
          );
          _load();
        } catch (e) {
          if (mounted) {
            SaaSFeedback.showError(context, 'Erro ao atualizar pet: $e');
          }
        }
      }
    } finally {
      name.dispose();
      breed.dispose();
      notes.dispose();
      managerNotes.dispose();
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
                'Animais de Estimação (${_pets.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.pets, size: 18),
                label: const Text('Cadastrar Pet'),
                onPressed: _openNewPetDialog,
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
                        message: 'Carregando pets cadastrados...',
                      ),
                    ),
                  )
                : _error != null
                ? SaaSErrorState(
                    message: 'Falha ao carregar pets: $_error',
                    onRetry: _load,
                  )
                : _pets.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.pets_outlined,
                    title: 'Nenhum animal cadastrado',
                    subtitle:
                        'Cadastre seu animal de estimação para melhor identificação e convivência.',
                  )
                : ListView.separated(
                    itemCount: _pets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final p = _pets[idx];
                      final vac = p['vaccinated'] == true;
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFEF3C7),
                            child: Icon(Icons.pets, color: Color(0xFFB45309)),
                          ),
                          title: Text(
                            p['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p['species'] ?? ''} • ${p['breed'] ?? 'SRD'} • Porte: ${p['size'] ?? 'Médio'}',
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Unidade: ${p['unitLabel'] ?? '-'} • Tutor: ${p['ownerName'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (p['managerNotes'] != null &&
                                  p['managerNotes'].toString().isNotEmpty)
                                Text(
                                  'Nota do Síndico: ${p['managerNotes']}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  vac ? 'Vacinado' : 'Vacina Pendente',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: vac
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                              ),
                              IconButton(
                                tooltip: 'Editar Pet',
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                onPressed: () => _openEditPetDialog(p),
                              ),
                              IconButton(
                                tooltip: 'Remover Pet',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () async {
                                  await widget.api.deletePet(p['id']);
                                  _load();
                                },
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
// 7. MUDANÇAS & CARGAS PESADAS
// ----------------------------------------------------
class _MovingSubView extends StatefulWidget {
  const _MovingSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_MovingSubView> createState() => _MovingSubViewState();
}

class _MovingSubViewState extends State<_MovingSubView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

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
      final list = await widget.api.listMovingRequests(widget.condominiumId);
      if (mounted) {
        setState(() {
          _requests = list;
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

  Future<void> _approveMoving(num id) async {
    try {
      await widget.api.approveMovingRequest(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento de mudança aprovado!'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao aprovar: $e')));
      }
    }
  }

  Future<void> _rejectMoving(num id) async {
    final reason = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recusar Agendamento de Mudança'),
          content: TextField(
            controller: reason,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Motivo da recusa *',
              hintText: 'Ex: Horário reservado para manutenção predial',
            ),
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
              child: const Text('Confirmar Recusa'),
            ),
          ],
        ),
      );
      final reasonVal = reason.text.trim();
      if (ok == true && reasonVal.isNotEmpty) {
        try {
          await widget.api.rejectMovingRequest(id, reasonVal);
          _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Agendamento recusado.'),
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
    } finally {
      reason.dispose();
    }
  }

  Future<void> _cancelMoving(num id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar agendamento?'),
        content: const Text(
          'Deseja realmente cancelar este agendamento de mudança? O turno será liberado para outros moradores.',
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
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.api.cancelMovingRequest(id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agendamento cancelado com sucesso.')),
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

  Future<void> _openNewMovingDialog() async {
    DateTime date = DateTime.now().add(const Duration(days: 3));
    String period = 'MORNING';
    String type = 'IN';
    final company = TextEditingController();
    final notes = TextEditingController();
    bool checking = true;
    bool morningAvailable = true;
    bool afternoonAvailable = true;
    bool initialLoaded = false;
    bool dialogOpen = true;

    bool isPeriodAvailable() =>
        period == 'MORNING' ? morningAvailable : afternoonAvailable;

    Future<void> refreshAvailability(
      DateTime targetDate,
      void Function(void Function()) setD,
    ) async {
      try {
        final res = await widget.api.checkMovingAvailability(
          widget.condominiumId,
          targetDate,
        );
        if (!dialogOpen) return;
        setD(() {
          checking = false;
          morningAvailable = res['morningAvailable'] != false;
          afternoonAvailable = res['afternoonAvailable'] != false;
        });
      } catch (_) {
        if (!dialogOpen) return;
        setD(() {
          checking = false;
        });
      }
    }

    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (c, setD) {
            if (!initialLoaded) {
              initialLoaded = true;
              refreshAvailability(date, setD);
            }
            final available = isPeriodAvailable();
            return AlertDialog(
              title: const Text('Agendar Mudança / Carga'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(
                            value: 'IN',
                            child: Text('Mudança de Entrada'),
                          ),
                          DropdownMenuItem(
                            value: 'OUT',
                            child: Text('Mudança de Saída'),
                          ),
                          DropdownMenuItem(
                            value: 'LARGE_DELIVERY',
                            child: Text('Entrega de Carga Pesada'),
                          ),
                        ],
                        onChanged: (v) => setD(() => type = v ?? type),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        title: Text(
                          'Data: ${date.day}/${date.month}/${date.year}',
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 90),
                            ),
                          );
                          if (d != null && dialogOpen) {
                            setD(() {
                              date = d;
                              checking = true;
                            });
                            await refreshAvailability(d, setD);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: period,
                        decoration: const InputDecoration(
                          labelText: 'Turno do Elevador de Serviço',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'MORNING',
                            child: Text('Manhã (08h às 12h)'),
                          ),
                          DropdownMenuItem(
                            value: 'AFTERNOON',
                            child: Text('Tarde (13h às 17h)'),
                          ),
                        ],
                        onChanged: (v) => setD(() => period = v ?? period),
                      ),
                      const SizedBox(height: 10),
                      if (checking)
                        const LinearProgressIndicator()
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: available
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            available
                                ? 'Turno livre para agendamento'
                                : 'Turno ocupado por outro morador',
                            style: TextStyle(
                              color: available
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB91C1C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: company,
                        decoration: const InputDecoration(
                          labelText: 'Empresa / Transportadora',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notes,
                        decoration: const InputDecoration(
                          labelText: 'Itens volumosos / Observações',
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
                  onPressed: !checking && available
                      ? () => Navigator.pop(c, true)
                      : null,
                  child: const Text('Solicitar Agendamento'),
                ),
              ],
            );
          },
        ),
      );
      dialogOpen = false;

      if (ok == true) {
        final dateStr =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        await widget.api.createMovingRequest(
          condoId: widget.condominiumId,
          type: type,
          movingDate: dateStr,
          period: period,
          companyName: company.text.trim().isEmpty ? null : company.text.trim(),
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        SaaSFeedback.showError(
          context,
          'Não foi possível agendar a mudança: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      dialogOpen = false;
      company.dispose();
      notes.dispose();
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
                'Agendamentos de Mudança (${_requests.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agendar Mudança'),
                onPressed: _openNewMovingDialog,
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
                        message: 'Carregando agendamentos de mudança...',
                      ),
                    ),
                  )
                : _error != null
                ? SaaSErrorState(
                    message: 'Falha ao carregar agendamentos: $_error',
                    onRetry: _load,
                  )
                : _requests.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Nenhum agendamento de mudança',
                    subtitle:
                        'Reserve elevadores de serviço e horários para carga e descarga.',
                  )
                : ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final r = _requests[idx];
                      final status = (r['status']?.toString() ?? 'PENDING')
                          .toUpperCase();
                      final isPending = status == 'PENDING';
                      final isApproved = status == 'APPROVED';
                      final isRejected = status == 'REJECTED';
                      final color = isApproved
                          ? const Color(0xFF15803D)
                          : (isRejected
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFB45309));
                      final bg = isApproved
                          ? const Color(0xFFDCFCE7)
                          : (isRejected
                                ? const Color(0xFFFEE2E2)
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFE0E7FF),
                                    child: Icon(
                                      Icons.local_shipping_rounded,
                                      color: Color(0xFF2F3FB0),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r['type'] ?? 'MUDANÇA'} • ${r['movingDate'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Turno: ${r['period'] ?? ''} • Transportadora: ${r['companyName'] ?? 'Própria'}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Unidade: ${r['unitLabel'] ?? '-'} • Solicitante: ${r['requestedByName'] ?? '-'} • Solicitado em: ${formatDate(r['createdAt'])}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (r['notes'] != null &&
                                            r['notes'].toString().isNotEmpty)
                                          Text(
                                            'Obs: ${r['notes']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        if (r['rejectionReason'] != null)
                                          Text(
                                            'Motivo da recusa: ${r['rejectionReason']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFDC2626),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
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
                                      isApproved
                                          ? 'Aprovado'
                                          : (isRejected
                                                ? 'Recusado'
                                                : 'Pendente'),
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      if (widget.canManage) ...[
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
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          icon: const Icon(
                                            Icons.check_rounded,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Aprovar Mudança',
                                            style: TextStyle(fontSize: 11.5),
                                          ),
                                          onPressed: () =>
                                              _approveMoving(r['id']),
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
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Recusar',
                                            style: TextStyle(fontSize: 11.5),
                                          ),
                                          onPressed: () =>
                                              _rejectMoving(r['id']),
                                        ),
                                      ] else ...[
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
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Cancelar Agendamento',
                                            style: TextStyle(fontSize: 11.5),
                                          ),
                                          onPressed: () =>
                                              _cancelMoving(r['id']),
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
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 8. DOCUMENTOS, ATAS & REGIMENTO
// ----------------------------------------------------
class _DocumentsSubView extends StatefulWidget {
  const _DocumentsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final bool canManage;
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_DocumentsSubView> createState() => _DocumentsSubViewState();
}

class _DocumentsSubViewState extends State<_DocumentsSubView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openNewDocumentDialog() async {
    final title = TextEditingController();
    final summary = TextEditingController();
    final content = TextEditingController();
    final phone = TextEditingController();
    String category = 'INTERNAL_RULES';
    bool pinned = false;

    try {
      final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Publicar Novo Documento'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(
                        value: 'INTERNAL_RULES',
                        child: Text('Regimento Interno & Convenção'),
                      ),
                      DropdownMenuItem(
                        value: 'MINUTES',
                        child: Text('Ata de Assembleia'),
                      ),
                      DropdownMenuItem(
                        value: 'FINANCIAL',
                        child: Text('Prestação de Contas / Balancete'),
                      ),
                      DropdownMenuItem(
                        value: 'NOTICE',
                        child: Text('Comunicado Oficial / Edital'),
                      ),
                      DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
                    ],
                    onChanged: (v) => setD(() => category = v ?? category),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Título do Documento *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: summary,
                    decoration: const InputDecoration(
                      labelText: 'Resumo / Ementa',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: content,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Conteúdo / Link de Download *',
                      hintText:
                          'Cole o texto do documento ou link (Drive, PDF, etc.)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone para Contato / Dúvidas',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Fixar no topo do mural'),
                    value: pinned,
                    onChanged: (v) => setD(() => pinned = v),
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
                if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(c, true);
              },
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );

      final titleVal = title.text.trim();
      final summaryVal = summary.text.trim();
      final contentVal = content.text.trim();
      if (ok == true && titleVal.isNotEmpty && contentVal.isNotEmpty) {
        try {
          await widget.api.createDocument(
            condoId: widget.condominiumId,
            category: category,
            title: titleVal,
            summary: summaryVal.isEmpty ? null : summaryVal,
            contentOrUrl: contentVal,
            pinned: pinned,
          );
          _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Documento publicado com sucesso!'),
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
    } finally {
      title.dispose();
      summary.dispose();
      content.dispose();
      phone.dispose();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.listDocuments(widget.condominiumId);
      if (mounted) {
        setState(() {
          _docs = list;
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
                'Documentos & Regimento (${_docs.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.canManage)
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Publicar Documento'),
                  onPressed: _openNewDocumentDialog,
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
                        message: 'Carregando documentos e atas...',
                      ),
                    ),
                  )
                : _error != null
                ? SaaSErrorState(
                    message: 'Falha ao carregar documentos: $_error',
                    onRetry: _load,
                  )
                : _docs.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'Nenhum documento publicado',
                    subtitle:
                        'Não há regimentos, atas ou convenções disponíveis no momento.',
                  )
                : ListView.separated(
                    itemCount: _docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final d = _docs[idx];
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
                              Icons.description_outlined,
                              color: Color(0xFF2F3FB0),
                            ),
                          ),
                          title: Text(
                            d['title'] ?? 'Documento',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${d['category'] ?? 'GERAL'} • Publicado por: ${d['createdByName'] ?? 'Administração'} • ${formatDate(d['createdAt'])}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (d['summary'] != null)
                                    Text(
                                      d['summary'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    d['contentOrUrl'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
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
