import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/enter_search_field.dart';
import '../../community/data/community_api.dart';
import '../../community/presentation/views/community_hub_view.dart';
import '../../announcements/presentation/announcement_composer.dart';
import '../../directory/presentation/unit_directory.dart';
import '../../home/data/home_service.dart';
import '../../home/presentation/pages/notifications_page.dart';
import 'membership_management_page.dart';

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
  late final CommunityApi _communityApi = CommunityApi(api: _api);
  List<Map<String, dynamic>> _condos = [];
  int? _selected;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;
  String _query = '';

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

  List<Map<String, dynamic>> _dashboardRecords(String key) {
    final values = _dashboard?[key];
    if (values is! List) return [];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
  }

  Future<void> _sendAnnouncement() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    final sent = await showAnnouncementComposer(
      context,
      api: _api,
      directory: DirectoryApi(api: _api, condominiumId: condominiumId),
      allowCondominiumWide: true,
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comunicado publicado com sucesso!')),
      );
    }
  }

  Future<void> _openMemberships() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MembershipManagementPage(api: _api, condominiumId: condominiumId),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openCommunityHub() async {
    final condoId = _selected;
    if (condoId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Serviços da Comunidade & Operacional')),
          body: CommunityHubView(
            api: _communityApi,
            condominiumId: condoId,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openUnitsMenu() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    final units = (_dashboard?['units'] is List)
        ? (_dashboard!['units'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _ManagerUnitsMenuPage(units: units, onEditPayment: _editPayment),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openReservationsMenu() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    final reservations = (_dashboard?['reservations'] is List)
        ? (_dashboard!['reservations'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _ManagerReservationsMenuPage(api: _api, reservations: reservations),
      ),
    );
    if (mounted) _load();
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
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Situação do pagamento',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'PAID',
                      child: Text('Pago (em dia)'),
                    ),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pendente')),
                    DropdownMenuItem(
                      value: 'OVERDUE',
                      child: Text('Em atraso'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor da cota (R\$ - opcional)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDate,
                  decoration: const InputDecoration(
                    labelText: 'Data de vencimento (AAAA-MM-DD)',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar lançamento'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Situação financeira atualizada!')),
        );
      }
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
    appBar: AppBar(
      title: const Text('Painel do Síndico'),
      actions: [
        IconButton(
          tooltip: 'Publicar comunicado',
          onPressed: _selected == null ? null : _sendAnnouncement,
          icon: const Icon(Icons.campaign_outlined),
        ),
        IconButton(
          tooltip: 'Central de notificações',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  NotificationsPage(api: _api, condominiumId: _selected),
            ),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          tooltip: 'Atualizar painel',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Sair da conta',
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          )
        : _condos.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Sua conta ainda não está vinculada como síndico a nenhum condomínio.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2F3FB0), Color(0xFF4B5DE7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, ${firstNameOf(widget.userName, fallback: 'síndico')}! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gerencie moradores, porteiros, reservas e pagamentos do seu condomínio.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF2F3FB0),
                                ),
                                onPressed: _openMemberships,
                                icon: const Icon(Icons.group_add_outlined),
                                label: const Text(
                                  'Convidar moradores e porteiros',
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF3C7),
                                  foregroundColor: const Color(0xFFB45309),
                                ),
                                onPressed: _sendAnnouncement,
                                icon: const Icon(Icons.campaign_outlined),
                                label: const Text('Enviar comunicado'),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFDCFCE7),
                                  foregroundColor: const Color(0xFF15803D),
                                ),
                                onPressed: _openCommunityHub,
                                icon: const Icon(Icons.diversity_3_outlined),
                                label: const Text('Comunidade & Chamados'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _selected,
                      decoration: const InputDecoration(
                        labelText: 'Condomínio em gestão',
                        prefixIcon: Icon(Icons.apartment_rounded),
                      ),
                      items: _condos
                          .map(
                            (membership) => DropdownMenuItem<int>(
                              value: (membership['condominiumId'] as num)
                                  .toInt(),
                              child: Text(
                                membership['condominiumName']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? '${membership['condominiumName']}'
                                    : 'Condomínio vinculado',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selected = value);
                        _load();
                      },
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _metric(
                          'Unidades cadastradas',
                          _dashboard?['totalUnits'],
                          Icons.home_work_outlined,
                          accentBg: const Color(0xFFE0E7FF),
                          accentFg: const Color(0xFF2F3FB0),
                          onTap: _openUnitsMenu,
                        ),
                        _metric(
                          'Pessoas vinculadas',
                          _dashboard?['totalUsers'],
                          Icons.groups_outlined,
                          accentBg: const Color(0xFFCCFBF1),
                          accentFg: const Color(0xFF0F766E),
                          onTap: _openMemberships,
                        ),
                        _metric(
                          'Reservas registradas',
                          _dashboard?['totalReservations'],
                          Icons.event_available_outlined,
                          accentBg: const Color(0xFFDCFCE7),
                          accentFg: const Color(0xFF15803D),
                          onTap: _openReservationsMenu,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    EnterSearchField(
                      hintText:
                          'Pesquisar unidades, setores ou reservas (Enter)',
                      onSubmitted: (query) => setState(() => _query = query),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Situação financeira das unidades',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_dashboardRecords('units').isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Nenhuma unidade encontrada.'),
                        ),
                      )
                    else
                      ..._dashboardRecords('units').map((unit) {
                        final (label, bg, fg) = _statusStyle(
                          unit['paymentStatus'],
                        );
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: bg,
                              child: Icon(
                                Icons.home_outlined,
                                color: fg,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${unit['sector']} • Unidade ${unit['identifier']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Status: $label${unit['dueDate'] == null ? '' : ' • Vencimento: ${_formatDate(unit['dueDate'])}'}${unit['amount'] == null ? '' : ' • R\$ ${unit['amount']}'}',
                            ),
                            trailing: OutlinedButton.icon(
                              onPressed: () => _editPayment(unit),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Atualizar'),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                    Text(
                      'Agendamentos de áreas comuns',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_dashboardRecords('reservations').isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Nenhum agendamento encontrado.'),
                        ),
                      )
                    else
                      ..._dashboardRecords('reservations').map((reservation) {
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE0E7FF),
                              child: Icon(
                                Icons.event_available_outlined,
                                color: Color(0xFF2F3FB0),
                              ),
                            ),
                            title: Text(
                              '${reservation['commonArea']} • ${reservation['residentName']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${_formatDateTime(reservation['startAt'])} até ${_formatDateTime(reservation['endAt'])}\n${reservation['residentEmail']}${reservation['contactPhone'] != null && reservation['contactPhone'].toString().isNotEmpty ? ' • ${formatPhone(reservation['contactPhone']?.toString())}' : ''} • ${_translateStatus(reservation['status'])}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }),
                  ],
                ),
              ),
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

  (String, Color, Color) _statusStyle(dynamic status) => switch (status) {
    'PAID' => ('Pago (em dia)', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    'CONFIRMATION_REQUESTED' => (
      'Comprovante enviado / Aguardando confirmação',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'PENDING' => ('Pendente', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    'OVERDUE' => ('Atrasado', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    _ => ('Sem lançamento', const Color(0xFFF1F5F9), const Color(0xFF475569)),
  };

  Widget _metric(
    String label,
    dynamic value,
    IconData icon, {
    required VoidCallback onTap,
    Color accentBg = const Color(0xFFE8ECFF),
    Color accentFg = const Color(0xFF2F3FB0),
  }) => SizedBox(
    width: 260,
    child: Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accentFg.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accentBg,
                child: Icon(icon, color: accentFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${value ?? 0}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ManagerUnitsMenuPage extends StatefulWidget {
  const _ManagerUnitsMenuPage({
    required this.units,
    required this.onEditPayment,
  });

  final List<Map<String, dynamic>> units;
  final Future<void> Function(Map<String, dynamic> unit) onEditPayment;

  @override
  State<_ManagerUnitsMenuPage> createState() => _ManagerUnitsMenuPageState();
}

class _ManagerUnitsMenuPageState extends State<_ManagerUnitsMenuPage> {
  String _query = '';

  (String, Color, Color) _statusStyle(dynamic status) => switch (status) {
    'PAID' => ('Pago (em dia)', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    'CONFIRMATION_REQUESTED' => (
      'Comprovante enviado / Aguardando confirmação',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'PENDING' => ('Pendente', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    'OVERDUE' => ('Atrasado', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    _ => ('Sem lançamento', const Color(0xFFF1F5F9), const Color(0xFF475569)),
  };

  @override
  Widget build(BuildContext context) {
    final filtered = widget.units
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Unidades cadastradas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              EnterSearchField(
                hintText: 'Pesquisar unidades ou setores (Enter)',
                onSubmitted: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhuma unidade encontrada.'),
                  ),
                )
              else
                ...filtered.map((unit) {
                  final (label, bg, fg) = _statusStyle(unit['paymentStatus']);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: bg,
                        child: Icon(Icons.home_outlined, color: fg, size: 20),
                      ),
                      title: Text(
                        '${unit['sector']} • Unidade ${unit['identifier']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('Situação financeira: $label'),
                      trailing: unit['paymentStatus'] == 'CONFIRMATION_REQUESTED'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF15803D),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await widget.onEditPayment({
                                      ...unit,
                                      'paymentStatus': 'PAID',
                                    });
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Confirmar Pagamento'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await widget.onEditPayment(unit);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Editar'),
                                ),
                              ],
                            )
                          : OutlinedButton.icon(
                              onPressed: () async {
                                await widget.onEditPayment(unit);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Atualizar'),
                            ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerReservationsMenuPage extends StatefulWidget {
  const _ManagerReservationsMenuPage({
    required this.api,
    required this.reservations,
  });

  final HomeService api;
  final List<Map<String, dynamic>> reservations;

  @override
  State<_ManagerReservationsMenuPage> createState() =>
      _ManagerReservationsMenuPageState();
}

class _ManagerReservationsMenuPageState
    extends State<_ManagerReservationsMenuPage> {
  String _query = '';

  String _formatDateTime(dynamic dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dt = DateTime.parse(dateTimeString.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateTimeString.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.reservations
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Reservas registradas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              EnterSearchField(
                hintText: 'Pesquisar reservas por área ou morador (Enter)',
                onSubmitted: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhuma reserva encontrada.'),
                  ),
                )
              else
                ...filtered.map((reservation) {
                  final status = reservation['status']?.toString();
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Icon(
                          Icons.event_available_outlined,
                          color: Color(0xFF2F3FB0),
                        ),
                      ),
                      title: Text(
                        '${reservation['commonArea']} • ${reservation['residentName']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${_formatDateTime(reservation['startAt'])} até ${_formatDateTime(reservation['endAt'])}\n${reservation['residentEmail']}${reservation['contactPhone'] != null && reservation['contactPhone'].toString().isNotEmpty ? ' • ${formatPhone(reservation['contactPhone']?.toString())}' : ''} • ${status == 'CONFIRMED' ? 'Confirmada' : (status == 'PENDING' ? 'Aguardando Aprovação' : 'Cancelada / Recusada')}',
                      ),
                      isThreeLine: true,
                      trailing: status == 'PENDING'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF15803D),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await widget.api.send('PATCH', '/reservations/${reservation['id']}/approve');
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Aprovar'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFFECACA)),
                                  ),
                                  onPressed: () async {
                                    await widget.api.send('PATCH', '/reservations/${reservation['id']}/reject');
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Recusar'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
