part of 'doorman_community_views.dart';

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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
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
              content: Text(
                'Entrada liberada para ${res['visitorName'] ?? 'visitante'} (${res['unitLabel'] ?? ''})!',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              content: Text('Convite inválido ou expirado: $e'),
            ),
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
              Text(
                'Controle de Acessos (${_visitors.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SaaSLoadingState(
                        message: 'Carregando visitantes da portaria...',
                      ),
                    ),
                  )
                : _visitors.isEmpty
                ? const SaaSEmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Nenhum visitante aguardando',
                    subtitle:
                        'Não há visitantes pré-autorizados ou na fila de entrada.',
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCheckedIn
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFE0E7FF),
                            child: Icon(
                              isCheckedIn
                                  ? Icons.login_rounded
                                  : Icons.access_time_rounded,
                              color: isCheckedIn
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF2F3FB0),
                            ),
                          ),
                          title: Text(
                            v['visitorName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Código: ${v['accessCode'] ?? '—'} • Placa: ${v['vehiclePlate'] ?? 'Sem veículo'}\nUnidade: ${v['unitIdentifier'] ?? '—'} • Tipo: ${v['visitorType'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAuth) ...[
                                FilledButton.icon(
                                  icon: const Icon(
                                    Icons.login_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Entrada'),
                                  onPressed: () => _checkIn(v['id']),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                  ),
                                  onPressed: () => _deny(v['id']),
                                  child: const Text('Recusar'),
                                ),
                              ],
                              if (isCheckedIn)
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 16,
                                  ),
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

  Future<void> _toggleCheckIn(num guestId) async {
    await widget.api.checkInGuest(guestId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
              icon: Icons.celebration_outlined,
              title: 'Nenhuma lista de convidados',
              subtitle:
                  'Não há listas vinculadas a eventos ou reservas ativas.',
            )
          : ListView.separated(
              itemCount: _lists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final gl = _lists[idx];
                final guests = (gl['guests'] as List? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .toList();
                final presentCount = guests
                    .where((g) => g['checkedIn'] == true)
                    .length;

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
                      gl['eventTitle'] ?? 'Evento',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Data: ${gl['eventDate'] ?? ''} • Presentes: $presentCount / ${guests.length}',
                    ),
                    children: [
                      ...guests.map((g) {
                        final checked = g['checkedIn'] == true;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            checked
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color: checked ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            g['guestName'] ?? '',
                            style: TextStyle(
                              fontWeight: checked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            'Doc: ${g['documentNumber'] ?? 'Não informado'}',
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: checked
                                ? null
                                : () => _toggleCheckIn(g['id']),
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
