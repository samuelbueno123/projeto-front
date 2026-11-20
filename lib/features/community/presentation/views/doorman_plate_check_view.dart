part of 'doorman_community_views.dart';

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
    final residentVehicles = (_result?['residentVehicles'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final visitorAccesses = (_result?['visitorAccesses'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
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
                const Text(
                  'Exemplos de placa: ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 32,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Placa não identificada no condomínio',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Este veículo não consta cadastrado como morador nem possui pré-autorização de visitante ativa.',
                            style: TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontSize: 13,
                            ),
                          ),
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
                    const Text(
                      'Veículo de Morador Cadastrado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...residentVehicles.map(
                      (v) => Card(
                        color: const Color(0xFFF0FDF4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDCFCE7),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          title: Text(
                            '${v['brandModel']} • ${v['color']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Placa: ${v['licensePlate']} • Unidade: ${v['unitIdentifier'] ?? '—'} (${v['sectorName'] ?? ''})\nMorador: ${v['ownerName'] ?? '—'} • Vaga: ${v['parkingSpot'] ?? '—'}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (visitorAccesses.isNotEmpty) ...[
                    const Text(
                      'Veículo Autorizado para Visitante / Prestador',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...visitorAccesses.map(
                      (acc) => Card(
                        color: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDBEAFE),
                            child: Icon(
                              Icons.badge_rounded,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          title: Text(
                            'Visitante: ${acc['visitorName']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Código de Acesso: ${acc['accessCode']} • Status: ${acc['status']}\nUnidade Destino: ${acc['unitIdentifier'] ?? '—'} • Morador Responsável: ${acc['residentName'] ?? '—'}',
                          ),
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
                      ),
                    ),
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
