import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../home/data/home_service.dart';
import '../../home/presentation/pages/notifications_page.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({
    super.key,
    required this.token,
    required this.userName,
    required this.onLogout,
  });

  final String? token;
  final String? userName;
  final Future<void> Function() onLogout;

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  late final HomeService _api = HomeService(token: widget.token);
  List<Map<String, dynamic>> _condos = [];
  int? _selected;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final result = await _api.get('/memberships/my');
      final memberships = result is List
          ? result.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final managed = memberships
          .where((membership) => membership['authority'] == 'ROLE_MANAGER')
          .toList();
      if (!mounted) return;
      setState(() => _condos = managed);
      if (managed.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      _selected = (managed.first['condominiumId'] as num).toInt();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    if (_selected == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.get(
        '/manager/dashboard?condominiumId=$_selected',
      );
      if (mounted) {
        setState(() {
          _dashboard = result as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _editPayment(Map<String, dynamic> unit) async {
    var status = unit['paymentStatus'] == 'NOT_RECORDED'
        ? 'PENDING'
        : unit['paymentStatus'] as String;
    final amount = TextEditingController(
      text: unit['amount']?.toString() ?? '',
    );
    final dueDate = TextEditingController(
      text: unit['dueDate']?.toString() ?? '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Unidade ${unit['identifier']} • ${unit['sector']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'PAID', child: Text('Pago')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pendente')),
                  DropdownMenuItem(value: 'OVERDUE', child: Text('Atrasado')),
                ],
                onChanged: (value) =>
                    setDialogState(() => status = value ?? status),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor (opcional)',
                ),
              ),
              TextField(
                controller: dueDate,
                decoration: const InputDecoration(
                  labelText: 'Vencimento (AAAA-MM-DD)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await _api.send(
        'PUT',
        '/manager/condominiums/$_selected/units/${unit['id']}/payment-status',
        body: {
          'status': status,
          'amount': amount.text.trim().isEmpty
              ? null
              : double.tryParse(amount.text.replaceAll(',', '.')),
          'dueDate': dueDate.text.trim().isEmpty ? null : dueDate.text.trim(),
        },
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FC),
    appBar: AppBar(
      title: const Text('Painel do síndico'),
      backgroundColor: const Color(0xFF2F3FB0),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Notificações',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  NotificationsPage(api: _api, condominiumId: _selected),
            ),
          ),
          icon: const Icon(Icons.notifications_none),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Sair',
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          )
        : _condos.isEmpty
        ? const Center(
            child: Text(
              'Sua conta não está vinculada como síndico a nenhum condomínio.',
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Olá, ${widget.userName ?? 'síndico'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _selected,
                  decoration: const InputDecoration(labelText: 'Condomínio'),
                  items: _condos
                      .map(
                        (membership) => DropdownMenuItem<int>(
                          value: (membership['condominiumId'] as num).toInt(),
                          child: Text(
                            'Condomínio #${membership['condominiumId']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selected = value);
                    _load();
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _metric('Unidades', _dashboard?['totalUnits']),
                    _metric('Usuários vinculados', _dashboard?['totalUsers']),
                    _metric('Agendamentos', _dashboard?['totalReservations']),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Pagamentos das unidades',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...((_dashboard?['units'] as List?) ?? []).map((value) {
                  final unit = Map<String, dynamic>.from(value as Map);
                  return Card(
                    child: ListTile(
                      title: Text('${unit['sector']} • ${unit['identifier']}'),
                      subtitle: Text(
                        'Pagamento: ${_status(unit['paymentStatus'])}${unit['dueDate'] == null ? '' : ' • Vence: ${_formatDate(unit['dueDate'])}'}${unit['amount'] == null ? '' : ' • R\$ ${unit['amount']}'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Registrar status',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editPayment(unit),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Text(
                  'Agendamentos do condomínio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...((_dashboard?['reservations'] as List?) ?? []).map((value) {
                  final reservation = value as Map;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(
                        '${reservation['commonArea']} • ${reservation['residentName']}',
                      ),
                      subtitle: Text(
                        '${_formatDateTime(reservation['startAt'])} – ${_formatDateTime(reservation['endAt'])}\n${reservation['residentEmail']} • ${_translateStatus(reservation['status'])}',
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
  );

  String _formatDate(dynamic dateString) {
    if (dateString == null) return '';
    try {
      final dt = DateTime.parse(dateString.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateString.toString();
    }
  }

  String _formatDateTime(dynamic dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dt = DateTime.parse(dateTimeString.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateTimeString.toString();
    }
  }

  String _translateStatus(dynamic status) {
    if (status == 'CONFIRMED') return 'Confirmada';
    if (status == 'CANCELLED') return 'Cancelada';
    return status?.toString() ?? '—';
  }

  String _status(dynamic status) => switch (status) {
    'PAID' => 'Pago',
    'PENDING' => 'Pendente',
    'OVERDUE' => 'Atrasado',
    'NOT_RECORDED' => 'Sem lançamento',
    _ => '—',
  };

  Widget _metric(String label, dynamic value) => SizedBox(
    width: 155,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${value ?? 0}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
