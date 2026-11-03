import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/realtime_service.dart';
import '../../data/community_api.dart';
import '../dialogs/plan_selection_dialog.dart';

class CommunityHubView extends StatefulWidget {
  const CommunityHubView({
    super.key,
    required this.api,
    required this.condominiumId,
    this.initialCategoryIndex = 0,
    this.canManage = false,
    this.enabledFeatures,
  });

  final CommunityApi api;
  final num condominiumId;
  final int initialCategoryIndex;
  final bool canManage;
  final List<String>? enabledFeatures;

  @override
  State<CommunityHubView> createState() => _CommunityHubViewState();
}

class _CommunityHubViewState extends State<CommunityHubView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = [
    'Ocorrências',
    'Visitantes',
    'Votações',
    'Classificados',
    'Veículos',
    'Pets',
    'Mudanças',
    'Documentos',
    'Multas & Notificações',
    'Smart Lockers',
    'Lista de Convidados',
    'Manutenção & O.S.',
    'Assembleias',
    'Financeiro',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: widget.initialCategoryIndex.clamp(0, _categories.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPlanGatedWrapper({
    required String? requiredFeature,
    required Widget child,
    required String featureName,
  }) {
    if (requiredFeature == null || widget.enabledFeatures == null) {
      return child;
    }
    final isEnabled = widget.enabledFeatures!
        .map((e) => e.toUpperCase())
        .contains(requiredFeature.toUpperCase());
    if (isEnabled) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 36, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recurso Exclusivo de Plano',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'O recurso "$featureName" não está habilitado no plano atual deste condomínio.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Faça upgrade para os planos Profissional ou Premium para desbloquear acesso total a esta e outras funcionalidades operacionais.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
            ),
            if (widget.canManage) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('Ver Planos de Assinatura'),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => PlanSelectionDialog(
                      condominiumId: widget.condominiumId,
                      condominiumName: 'Condomínio',
                      api: widget.api,
                      onPlanSelected: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Plano atualizado com sucesso!')),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Compact Category TabBar avoiding page vertical scroll
        Container(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.report_problem_outlined, size: 20), text: 'Ocorrências'),
              Tab(icon: Icon(Icons.badge_outlined, size: 20), text: 'Visitantes'),
              Tab(icon: Icon(Icons.how_to_vote_outlined, size: 20), text: 'Votações'),
              Tab(icon: Icon(Icons.storefront_outlined, size: 20), text: 'Classificados'),
              Tab(icon: Icon(Icons.directions_car_outlined, size: 20), text: 'Veículos'),
              Tab(icon: Icon(Icons.pets_outlined, size: 20), text: 'Pets'),
              Tab(icon: Icon(Icons.local_shipping_outlined, size: 20), text: 'Mudanças'),
              Tab(icon: Icon(Icons.menu_book_outlined, size: 20), text: 'Documentos'),
              Tab(icon: Icon(Icons.gavel_outlined, size: 20), text: 'Notificações & Multas'),
              Tab(icon: Icon(Icons.lock_clock_outlined, size: 20), text: 'Lockers'),
              Tab(icon: Icon(Icons.people_outline_rounded, size: 20), text: 'Convidados'),
              Tab(icon: Icon(Icons.build_circle_outlined, size: 20), text: 'Manutenção & O.S.'),
              Tab(icon: Icon(Icons.groups_outlined, size: 20), text: 'Assembleias'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 20), text: 'Financeiro'),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content area sized properly
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TicketsSubView(api: widget.api, condominiumId: widget.condominiumId, canManage: widget.canManage),
              _VisitorsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _PollsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _buildPlanGatedWrapper(
                requiredFeature: 'MARKETPLACE_INTEGRATION',
                featureName: 'Classificados e Vagas',
                child: _ClassifiedsSubView(api: widget.api, condominiumId: widget.condominiumId),
              ),
              _VehiclesSubView(api: widget.api, condominiumId: widget.condominiumId),
              _PetsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _MovingSubView(api: widget.api, condominiumId: widget.condominiumId, canManage: widget.canManage),
              _DocumentsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _buildPlanGatedWrapper(
                requiredFeature: 'NOTIFICATIONS',
                featureName: 'Notificações & Multas',
                child: _InfractionsSubView(api: widget.api, condominiumId: widget.condominiumId, canManage: widget.canManage),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'PACKAGES',
                featureName: 'Armários Inteligentes (Lockers)',
                child: _LockersSubView(api: widget.api, condominiumId: widget.condominiumId),
              ),
              _buildPlanGatedWrapper(
                requiredFeature: 'RESERVATIONS',
                featureName: 'Lista de Convidados',
                child: _GuestListsSubView(api: widget.api, condominiumId: widget.condominiumId),
              ),
              _MaintenanceSubView(api: widget.api, condominiumId: widget.condominiumId, canManage: widget.canManage),
              _AssembliesSubView(api: widget.api, condominiumId: widget.condominiumId, canManage: widget.canManage),
              _FinancialSubView(api: widget.api, condominiumId: widget.condominiumId, canManage: widget.canManage),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// 1. OCORRÊNCIAS & CHAMADOS
// ----------------------------------------------------
class _TicketsSubView extends StatefulWidget {
  const _TicketsSubView({required this.api, required this.condominiumId, this.canManage = false});
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_TicketsSubView> createState() => _TicketsSubViewState();
}

class _TicketsSubViewState extends State<_TicketsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listTickets(widget.condominiumId);
      if (mounted) setState(() { _tickets = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewTicketDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final location = TextEditingController();
    String category = 'MAINTENANCE';
    String priority = 'MEDIUM';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Abrir Chamado / Ocorrência'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'MAINTENANCE', child: Text('Manutenção')),
                      DropdownMenuItem(value: 'NOISE', child: Text('Barulho / Silêncio')),
                      DropdownMenuItem(value: 'SECURITY', child: Text('Segurança')),
                      DropdownMenuItem(value: 'CLEANING', child: Text('Limpeza')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
                    ],
                    onChanged: (v) => setDState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título da Ocorrência *', hintText: 'Ex: Lâmpada do 2º andar queimada'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Local exato', hintText: 'Ex: Bloco B, corredor em frente ao 203'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'Prioridade'),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('Baixa')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Média')),
                      DropdownMenuItem(value: 'HIGH', child: Text('Alta (Urgente)')),
                    ],
                    onChanged: (v) => setDState(() => priority = v ?? priority),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrição detalhada *', hintText: 'Explique o que ocorreu...'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar Chamado'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && title.text.isNotEmpty && desc.text.isNotEmpty) {
      await widget.api.createTicket(
        condoId: widget.condominiumId,
        category: category,
        title: title.text.trim(),
        description: desc.text.trim(),
        location: location.text.trim().isEmpty ? null : location.text.trim(),
        priority: priority,
      );
      _load();
    }
  }

  Future<void> _openUpdateStatusDialog(Map<String, dynamic> ticket) async {
    String currentStatus = (ticket['status']?.toString() ?? 'OPEN').toUpperCase();
    if (currentStatus != 'OPEN' && currentStatus != 'IN_PROGRESS' && currentStatus != 'RESOLVED' && currentStatus != 'REJECTED') {
      currentStatus = 'OPEN';
    }
    String selectedStatus = currentStatus;
    final responseCtrl = TextEditingController(text: ticket['adminResponse']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Atualizar Status do Chamado'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket['title'] ?? 'Ocorrência', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Novo Status'),
                    items: const [
                      DropdownMenuItem(value: 'OPEN', child: Text('Aberto (Pendente)')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Em Análise / Atendimento')),
                      DropdownMenuItem(value: 'RESOLVED', child: Text('Resolvido / Concluído')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Recusado / Arquivado')),
                    ],
                    onChanged: (v) => setDState(() => selectedStatus = v ?? selectedStatus),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: responseCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Resposta / Parecer Administrativo',
                      hintText: 'Explique as providências tomadas ou resolução...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar Alteração'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await widget.api.updateTicketStatus(
        ticketId: ticket['id'],
        status: selectedStatus,
        adminResponse: responseCtrl.text.trim().isEmpty ? null : responseCtrl.text.trim(),
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chamado atualizado com sucesso!')),
        );
      }
    }
  }

  Widget _buildStatusTimeline(String rawStatus) {
    final status = rawStatus.toUpperCase();
    final isResolved = status == 'RESOLVED';
    final isInProgress = status == 'IN_PROGRESS' || isResolved;
    final isOpen = true;
    final isRejected = status == 'REJECTED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isRejected
          ? const Row(
              children: [
                Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 16),
                SizedBox(width: 6),
                Text(
                  'Chamado Recusado / Arquivado',
                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 11.5),
                ),
              ],
            )
          : Row(
              children: [
                _buildTimelineStep(title: 'Aberto', isActive: isOpen, isDone: isInProgress, activeColor: const Color(0xFFD97706)),
                Expanded(
                  child: Container(
                    height: 2,
                    color: isInProgress ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                  ),
                ),
                _buildTimelineStep(title: 'Em Análise', isActive: isInProgress, isDone: isResolved, activeColor: const Color(0xFF1D4ED8)),
                Expanded(
                  child: Container(
                    height: 2,
                    color: isResolved ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                  ),
                ),
                _buildTimelineStep(title: 'Resolvido', isActive: isResolved, isDone: isResolved, activeColor: const Color(0xFF15803D)),
              ],
            ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required bool isActive,
    required bool isDone,
    required Color activeColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : (isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
          size: 15,
          color: isActive ? activeColor : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ],
    );
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
              Text('Total de chamados: ${_tickets.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo Chamado'),
                onPressed: _openNewTicketDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tickets.isEmpty
                    ? const Center(child: Text('Nenhuma ocorrência registrada no condomínio.'))
                    : ListView.separated(
                        itemCount: _tickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final t = _tickets[idx];
                          final status = t['status']?.toString();
                          final isResolved = status == 'RESOLVED';
                          final inProgress = status == 'IN_PROGRESS';
                          final color = isResolved ? const Color(0xFF15803D) : (inProgress ? const Color(0xFF1D4ED8) : const Color(0xFFB45309));
                          final bg = isResolved ? const Color(0xFFDCFCE7) : (inProgress ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7));

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(t['title'] ?? 'Sem título', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                                        child: Text(status ?? 'OPEN', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(t['description'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                                  if (t['location'] != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(t['location'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  _buildStatusTimeline(status ?? 'OPEN'),
                                  if (t['adminResponse'] != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                                      child: Text('Resposta da administração: ${t['adminResponse']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        FilledButton.tonalIcon(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.rate_review_outlined, size: 15),
                                          label: const Text('Responder / Atualizar Status', style: TextStyle(fontSize: 11.5)),
                                          onPressed: () => _openUpdateStatusDialog(t),
                                        ),
                                      ],
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
      ),
    );
  }
}

// ----------------------------------------------------
// 2. VISITANTES & PRE-AUTORIZAÇÃO
// ----------------------------------------------------
class _VisitorsSubView extends StatefulWidget {
  const _VisitorsSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_VisitorsSubView> createState() => _VisitorsSubViewState();
}

class _VisitorsSubViewState extends State<_VisitorsSubView> {
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

  Future<void> _openNewVisitorDialog() async {
    final name = TextEditingController();
    final doc = TextEditingController();
    final plate = TextEditingController();
    String type = 'GUEST';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: const Text('Pré-Autorizar Visitante / Prestador'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Tipo de Visitante'),
                    items: const [
                      DropdownMenuItem(value: 'GUEST', child: Text('Convidado / Amigo / Familiar')),
                      DropdownMenuItem(value: 'SERVICE_PROVIDER', child: Text('Prestador de Serviços / Obra')),
                      DropdownMenuItem(value: 'DELIVERY', child: Text('Entregador')),
                    ],
                    onChanged: (v) => setDState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome Completo *')),
                  const SizedBox(height: 10),
                  TextField(controller: doc, decoration: const InputDecoration(labelText: 'RG ou CPF (opcional)')),
                  const SizedBox(height: 10),
                  TextField(controller: plate, decoration: const InputDecoration(labelText: 'Placa do Veículo (se houver)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Autorizar')),
          ],
        ),
      ),
    );

    if (ok == true && name.text.isNotEmpty) {
      await widget.api.createVisitor(
        condoId: widget.condominiumId,
        visitorName: name.text.trim(),
        documentNumber: doc.text.trim().isEmpty ? null : doc.text.trim(),
        vehiclePlate: plate.text.trim().isEmpty ? null : plate.text.trim(),
        visitorType: type,
      );
      _load();
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
              Text('Autorizações de Acesso (${_visitors.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              FilledButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Pré-Autorizar'),
                onPressed: _openNewVisitorDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visitors.isEmpty
                    ? const Center(child: Text('Nenhum visitante pré-autorizado.'))
                    : ListView.separated(
                        itemCount: _visitors.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final v = _visitors[idx];
                          final code = v['accessCode']?.toString() ?? '';
                          final status = v['status']?.toString() ?? 'AUTHORIZED';

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE0E7FF),
                                child: Text(code.isNotEmpty ? code.substring(0, code.length.clamp(0, 3)) : 'OK', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2F3FB0))),
                              ),
                              title: Text(v['visitorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Código: $code • Placa: ${v['vehiclePlate'] ?? 'Pedestre'} • ${v['visitorType'] ?? ''}'),
                              trailing: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Compartilhar Convite no WhatsApp',
                                      icon: const Icon(Icons.share_rounded, color: Color(0xFF16A34A), size: 20),
                                      onPressed: () {
                                        final invite = '''
🏢 *CONVITE DE ACESSO — CONDOMÍNIO ÂNCORA*
Olá, *${v['visitorName']}*!
Você possui acesso pré-autorizado ao condomínio.
🔑 *Código de Acesso:* $code
🚗 *Veículo:* ${v['vehiclePlate'] ?? 'A pé / Pedestre'}
Por favor, apresente este código ou seu documento na portaria ao chegar.
''';
                                        Clipboard.setData(ClipboardData(text: invite));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Convite formatado copiado! Cole no WhatsApp do visitante.'),
                                            backgroundColor: Color(0xFF15803D),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Chip(
                                      label: Text(status, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: status == 'CHECKED_IN' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    ),
                                  ],
                                ),
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
// 3. VOTAÇÕES & ENQUETES
// ----------------------------------------------------
class _PollsSubView extends StatefulWidget {
  const _PollsSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_PollsSubView> createState() => _PollsSubViewState();
}

class _PollsSubViewState extends State<_PollsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _polls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listPolls(widget.condominiumId);
      if (mounted) setState(() { _polls = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vote(num pollId, num optionId) async {
    try {
      await widget.api.votePoll(pollId: pollId, optionId: optionId);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? const Center(child: Text('Nenhuma votação ou assembleia virtual aberta no momento.'))
              : ListView.separated(
                  itemCount: _polls.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final p = _polls[idx];
                    final options = (p['options'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
                    final totalVotes = (p['totalVotes'] as num?)?.toInt() ?? 0;
                    final myOptionId = p['myOptionId'];
                    final isClosed = p['closed'] == true;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: isClosed ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                                  child: Text(isClosed ? 'Encerrada' : 'Em Votação', style: TextStyle(color: isClosed ? const Color(0xFF64748B) : const Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(p['description'] ?? '', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                            const SizedBox(height: 14),
                            ...options.map((opt) {
                              final optId = opt['id'];
                              final votes = (opt['voteCount'] as num?)?.toInt() ?? 0;
                              final pct = totalVotes > 0 ? (votes / totalVotes) : 0.0;
                              final isSelected = myOptionId == optId;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: (!isClosed) ? () => _vote(p['id'], optId) : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                      border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8)),
                                                const SizedBox(width: 8),
                                                Text(opt['optionText'] ?? '', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                                              ],
                                            ),
                                            Text('$votes votos (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(value: pct, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8)), minHeight: 6),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ----------------------------------------------------
// 4. CLASSIFICADOS INTERNOS
// ----------------------------------------------------
class _ClassifiedsSubView extends StatefulWidget {
  const _ClassifiedsSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_ClassifiedsSubView> createState() => _ClassifiedsSubViewState();
}

class _ClassifiedsSubViewState extends State<_ClassifiedsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listClassifieds(widget.condominiumId);
      if (mounted) setState(() { _ads = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewAdDialog() async {
    final title = TextEditingController();
    final price = TextEditingController();
    final desc = TextEditingController();
    final phone = TextEditingController();
    String cat = 'PARKING_RENTAL';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Novo Anúncio nos Classificados'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: cat,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'PARKING_RENTAL', child: Text('Aluguel de Vaga de Garagem')),
                      DropdownMenuItem(value: 'SALE', child: Text('Venda de Objeto / Móvel')),
                      DropdownMenuItem(value: 'DONATION', child: Text('Doação')),
                      DropdownMenuItem(value: 'SERVICE', child: Text('Serviço Profissional')),
                    ],
                    onChanged: (v) => setD(() => cat = v ?? cat),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Título *')),
                  const SizedBox(height: 10),
                  TextField(controller: price, decoration: const InputDecoration(labelText: 'Preço (R\$)')),
                  const SizedBox(height: 10),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefone para Contato *')),
                  const SizedBox(height: 10),
                  TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição detalhada *')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Publicar')),
          ],
        ),
      ),
    );

    if (ok == true && title.text.isNotEmpty && desc.text.isNotEmpty) {
      await widget.api.createClassified(
        condoId: widget.condominiumId,
        category: cat,
        title: title.text.trim(),
        description: desc.text.trim(),
        price: price.text.trim().isEmpty ? null : price.text.trim(),
        contactPhone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      );
      _load();
    }
  }

  Future<void> _sendInterest(num adId) async {
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demonstrar Interesse'),
        content: TextField(
          controller: msg,
          decoration: const InputDecoration(labelText: 'Mensagem para o anunciante', hintText: 'Tenho interesse! Ainda está disponível?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar Mensagem')),
        ],
      ),
    );
    if (ok == true && msg.text.isNotEmpty) {
      await widget.api.sendClassifiedInterest(adId, msg.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensagem de interesse enviada ao anunciante!')));
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
              Text('Mural de Classificados (${_ads.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Anunciar'),
                onPressed: _openNewAdDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _ads.isEmpty
                    ? const Center(child: Text('Nenhum anúncio disponível no momento.'))
                    : ListView.separated(
                        itemCount: _ads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final a = _ads[idx];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                      if (a['price'] != null)
                                        Text('R\$ ${a['price']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontSize: 15)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(a['description'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text('Contato: ${a['contactPhone'] ?? 'Direto no app'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (a['contactPhone'] != null && a['contactPhone'].toString().trim().isNotEmpty) ...[
                                              IconButton(
                                                tooltip: 'Copiar mensagem para WhatsApp',
                                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 19),
                                                onPressed: () {
                                                  final digits = a['contactPhone'].toString().replaceAll(RegExp(r'\D'), '');
                                                  final title = a['title'] ?? 'anúncio';
                                                  final msg = 'Olá! Vi seu anúncio "$title" nos Classificados do Condomínio e gostaria de informações.';
                                                  Clipboard.setData(ClipboardData(text: msg));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Mensagem de contato copiada! Envie para o WhatsApp ($digits).'),
                                                      backgroundColor: const Color(0xFF15803D),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            FilledButton.tonalIcon(
                                              style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.send_rounded, size: 15),
                                              label: const Text('Tenho Interesse', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _sendInterest(a['id']),
                                            ),
                                          ],
                                        ),
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
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 5. VEÍCULOS & VAGAS
// ----------------------------------------------------
class _VehiclesSubView extends StatefulWidget {
  const _VehiclesSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_VehiclesSubView> createState() => _VehiclesSubViewState();
}

class _VehiclesSubViewState extends State<_VehiclesSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listVehicles(widget.condominiumId);
      if (mounted) setState(() { _vehicles = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewVehicleDialog() async {
    final model = TextEditingController();
    final plate = TextEditingController();
    final color = TextEditingController();
    final spot = TextEditingController();
    String type = 'CAR';

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
                      DropdownMenuItem(value: 'MOTORCYCLE', child: Text('Moto')),
                      DropdownMenuItem(value: 'BICYCLE', child: Text('Bicicleta')),
                    ],
                    onChanged: (v) => setD(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: model, decoration: const InputDecoration(labelText: 'Modelo / Marca *', hintText: 'Ex: Honda Civic')),
                  const SizedBox(height: 10),
                  TextField(controller: plate, decoration: const InputDecoration(labelText: 'Placa *', hintText: 'Ex: ABC1D23')),
                  const SizedBox(height: 10),
                  TextField(controller: color, decoration: const InputDecoration(labelText: 'Cor *', hintText: 'Ex: Prata')),
                  const SizedBox(height: 10),
                  TextField(controller: spot, decoration: const InputDecoration(labelText: 'Vaga de Estacionamento', hintText: 'Ex: Vaga 102')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );

    if (ok == true && model.text.isNotEmpty && plate.text.isNotEmpty) {
      await widget.api.createVehicle(
        condoId: widget.condominiumId,
        type: type,
        brandModel: model.text.trim(),
        color: color.text.trim().isEmpty ? 'Padrão' : color.text.trim(),
        licensePlate: plate.text.trim().toUpperCase(),
        parkingSpot: spot.text.trim().isEmpty ? null : spot.text.trim(),
      );
      _load();
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
              Text('Frota de Veículos (${_vehicles.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar Veículo'),
                onPressed: _openNewVehicleDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _vehicles.isEmpty
                    ? const Center(child: Text('Nenhum veículo registrado na sua unidade.'))
                    : ListView.separated(
                        itemCount: _vehicles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final v = _vehicles[idx];
                          final status = v['status']?.toString() ?? 'APPROVED';
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.directions_car_rounded, color: Color(0xFF2F3FB0))),
                              title: Text('${v['brandModel']} (${v['color']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Placa: ${v['licensePlate']} • Vaga: ${v['parkingSpot'] ?? '—'}'),
                              trailing: Chip(label: Text(status, style: const TextStyle(fontSize: 11)), backgroundColor: status == 'APPROVED' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)),
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
  const _PetsSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_PetsSubView> createState() => _PetsSubViewState();
}

class _PetsSubViewState extends State<_PetsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listPets(widget.condominiumId);
      if (mounted) setState(() { _pets = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewPetDialog() async {
    final name = TextEditingController();
    final breed = TextEditingController();
    String species = 'DOG';
    String size = 'MEDIUM';
    bool vaccinated = true;

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
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do Pet *')),
                  const SizedBox(height: 10),
                  TextField(controller: breed, decoration: const InputDecoration(labelText: 'Raça')),
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
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cadastrar Pet')),
          ],
        ),
      ),
    );

    if (ok == true && name.text.isNotEmpty) {
      await widget.api.createPet(
        condoId: widget.condominiumId,
        name: name.text.trim(),
        species: species,
        breed: breed.text.trim().isEmpty ? null : breed.text.trim(),
        size: size,
        vaccinated: vaccinated,
      );
      _load();
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
              Text('Animais de Estimação (${_pets.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                ? const Center(child: CircularProgressIndicator())
                : _pets.isEmpty
                    ? const Center(child: Text('Nenhum animal cadastrado no condomínio.'))
                    : ListView.separated(
                        itemCount: _pets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final p = _pets[idx];
                          final vac = p['vaccinated'] == true;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.pets, color: Color(0xFFB45309))),
                              title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${p['species'] ?? ''} • ${p['breed'] ?? 'SRD'} • Porte: ${p['size'] ?? 'Médio'}'),
                              trailing: Chip(
                                label: Text(vac ? 'Vacinado' : 'Vacina Pendente', style: const TextStyle(fontSize: 11)),
                                backgroundColor: vac ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
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
  const _MovingSubView({required this.api, required this.condominiumId, this.canManage = false});
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_MovingSubView> createState() => _MovingSubViewState();
}

class _MovingSubViewState extends State<_MovingSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listMovingRequests(widget.condominiumId);
      if (mounted) setState(() { _requests = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveMoving(num id) async {
    try {
      await widget.api.approveMovingRequest(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agendamento de mudança aprovado!'), backgroundColor: Color(0xFF15803D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao aprovar: $e')));
    }
  }

  Future<void> _rejectMoving(num id) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recusar Agendamento de Mudança'),
        content: TextField(
          controller: reason,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo da recusa *', hintText: 'Ex: Horário reservado para manutenção predial'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Recusa'),
          ),
        ],
      ),
    );
    if (ok == true && reason.text.isNotEmpty) {
      try {
        await widget.api.rejectMovingRequest(id, reason.text.trim());
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agendamento recusado.'), backgroundColor: Color(0xFFDC2626)),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _cancelMoving(num id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar agendamento?'),
        content: const Text('Deseja realmente cancelar este agendamento de mudança? O turno será liberado para outros moradores.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.api.rejectMovingRequest(id, 'Cancelado pelo morador');
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agendamento cancelado com sucesso.')),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _openNewMovingDialog() async {
    DateTime date = DateTime.now().add(const Duration(days: 3));
    String period = 'MORNING';
    String type = 'IN';
    final company = TextEditingController();
    final notes = TextEditingController();
    bool checking = false;
    bool available = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
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
                      DropdownMenuItem(value: 'IN', child: Text('Mudança de Entrada')),
                      DropdownMenuItem(value: 'OUT', child: Text('Mudança de Saída')),
                      DropdownMenuItem(value: 'LARGE_DELIVERY', child: Text('Entrega de Carga Pesada')),
                    ],
                    onChanged: (v) => setD(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: Text('Data: ${date.day}/${date.month}/${date.year}'),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (d != null) {
                        setD(() { date = d; checking = true; });
                        final res = await widget.api.checkMovingAvailability(widget.condominiumId, d);
                        setD(() {
                          checking = false;
                          available = period == 'MORNING' ? res['morningAvailable'] == true : res['afternoonAvailable'] == true;
                        });
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: period,
                    decoration: const InputDecoration(labelText: 'Turno do Elevador de Serviço'),
                    items: const [
                      DropdownMenuItem(value: 'MORNING', child: Text('Manhã (08h às 12h)')),
                      DropdownMenuItem(value: 'AFTERNOON', child: Text('Tarde (13h às 17h)')),
                    ],
                    onChanged: (v) => setD(() => period = v ?? period),
                  ),
                  const SizedBox(height: 10),
                  if (checking)
                    const LinearProgressIndicator()
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: available ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                      child: Text(available ? 'Turno livre para agendamento' : 'Turno ocupado por outro morador', style: TextStyle(color: available ? const Color(0xFF15803D) : const Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 10),
                  TextField(controller: company, decoration: const InputDecoration(labelText: 'Empresa / Transportadora')),
                  const SizedBox(height: 10),
                  TextField(controller: notes, decoration: const InputDecoration(labelText: 'Itens volumosos / Observações')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: available ? () => Navigator.pop(c, true) : null,
              child: const Text('Solicitar Agendamento'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
              Text('Agendamentos de Mudança (${_requests.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? const Center(child: Text('Nenhum agendamento de mudança registrado.'))
                    : ListView.separated(
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final r = _requests[idx];
                          final status = (r['status']?.toString() ?? 'PENDING').toUpperCase();
                          final isPending = status == 'PENDING';
                          final isApproved = status == 'APPROVED';
                          final isRejected = status == 'REJECTED';
                          final color = isApproved ? const Color(0xFF15803D) : (isRejected ? const Color(0xFFDC2626) : const Color(0xFFB45309));
                          final bg = isApproved ? const Color(0xFFDCFCE7) : (isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
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
                                        child: Icon(Icons.local_shipping_rounded, color: Color(0xFF2F3FB0)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${r['type'] ?? 'MUDANÇA'} • ${r['movingDate'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text('Turno: ${r['period'] ?? ''} • Transportadora: ${r['companyName'] ?? 'Própria'}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                            if (r['notes'] != null && r['notes'].toString().isNotEmpty)
                                              Text('Obs: ${r['notes']}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                            if (r['rejectionReason'] != null)
                                              Text('Motivo da recusa: ${r['rejectionReason']}', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                                        child: Text(isApproved ? 'Aprovado' : (isRejected ? 'Recusado' : 'Pendente'), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
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
                                                backgroundColor: const Color(0xFF15803D),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.check_rounded, size: 15),
                                              label: const Text('Aprovar Mudança', style: TextStyle(fontSize: 11.5)),
                                              onPressed: () => _approveMoving(r['id']),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                side: const BorderSide(color: Color(0xFFF87171)),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.close_rounded, size: 15),
                                              label: const Text('Recusar', style: TextStyle(fontSize: 11.5)),
                                              onPressed: () => _rejectMoving(r['id']),
                                            ),
                                          ] else ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                side: const BorderSide(color: Color(0xFFF87171)),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.close_rounded, size: 15),
                                              label: const Text('Cancelar Agendamento', style: TextStyle(fontSize: 11.5)),
                                              onPressed: () => _cancelMoving(r['id']),
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
  const _DocumentsSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

  @override
  State<_DocumentsSubView> createState() => _DocumentsSubViewState();
}

class _DocumentsSubViewState extends State<_DocumentsSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listDocuments(widget.condominiumId);
      if (mounted) setState(() { _docs = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? const Center(child: Text('Nenhum documento ou regimento publicado pela administração ainda.'))
              : ListView.separated(
                  itemCount: _docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final d = _docs[idx];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: ExpansionTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.description_outlined, color: Color(0xFF2F3FB0))),
                        title: Text(d['title'] ?? 'Documento', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(d['category'] ?? 'GERAL'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (d['summary'] != null) Text(d['summary'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(d['contentOrUrl'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ----------------------------------------------------
// 9. INFRAÇÕES, NOTIFICAÇÕES & DEFESAS
// ----------------------------------------------------
class _InfractionsSubView extends StatefulWidget {
  const _InfractionsSubView({required this.api, required this.condominiumId, this.canManage = false});
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
      if (mounted) setState(() { _infractions = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewInfractionDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();
    final unit = TextEditingController();
    String type = 'WARNING';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Registrar Notificação ou Multa'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Tipo de Notificação'),
                    items: const [
                      DropdownMenuItem(value: 'WARNING', child: Text('Advertência Formal')),
                      DropdownMenuItem(value: 'FINE', child: Text('Multa por Infração ao Regimento')),
                    ],
                    onChanged: (v) => setD(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: unit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ID da Unidade / Apartamento *', hintText: 'Ex: 101'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título da Ocorrência *', hintText: 'Ex: Barulho após horário permitido'),
                  ),
                  if (type == 'FINE') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor da Multa (R\$) *', hintText: '150.00'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrição e artigo do regimento *', hintText: 'Descreva a ocorrência constatada...'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Emitir Notificação'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && title.text.isNotEmpty && unit.text.isNotEmpty) {
      final unitId = num.tryParse(unit.text.trim()) ?? 1;
      final fineVal = amount.text.trim().isNotEmpty ? amount.text.trim() : null;
      await widget.api.createInfraction(
        condoId: widget.condominiumId,
        unitId: unitId,
        type: type,
        title: title.text.trim(),
        description: desc.text.trim(),
        fineAmount: fineVal,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação registrada com sucesso!')),
        );
      }
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
          decoration: const InputDecoration(labelText: 'Justificativa para o síndico *', hintText: 'Apresente suas razões e evidências...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar Defesa')),
        ],
      ),
    );

    if (ok == true && def.text.isNotEmpty) {
      await widget.api.submitDefense(id, def.text.trim());
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Defesa enviada à administração!')));
    }
  }

  Future<void> _judgeDefense(num id, String status, String defaultJudgment) async {
    final notes = TextEditingController(text: defaultJudgment);
    final isCancel = status == 'CANCELLED';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isCancel ? 'Acatar Defesa (Cancelar Multa)' : 'Indeferir Defesa (Manter Infração)'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Parecer do síndico / administração',
            hintText: 'Justifique a decisão para o morador...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: isCancel ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
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
                Text('Total: ${_infractions.length} ocorrências', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                ? const Center(child: CircularProgressIndicator())
                : _infractions.isEmpty
                    ? const Center(child: Text('Nenhuma advertência ou multa registrada para sua unidade. Parabéns! 🎉'))
                    : ListView.separated(
                        itemCount: _infractions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final inf = _infractions[idx];
                          final status = (inf['status']?.toString() ?? 'ISSUED').toUpperCase();
                          final canDefend = status == 'ISSUED';
                          final hasDefense = inf['defense'] != null && inf['defense'].toString().isNotEmpty;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${inf['type'] == 'FINE' ? 'Multa' : 'Advertência'}: ${inf['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Chip(label: Text(status, style: const TextStyle(fontSize: 11)), backgroundColor: const Color(0xFFFEF3C7)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(inf['description'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                                  if (hasDefense) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: Text('Defesa do morador: ${inf['defense']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                    ),
                                  ],
                                  if (inf['judgment'] != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                      child: Text('Parecer da administração: ${inf['judgment']}', style: const TextStyle(fontSize: 12, color: Color(0xFF065F46))),
                                    ),
                                  ],
                                  if (widget.canManage && hasDefense && status != 'CANCELLED' && status != 'CONFIRMED') ...[
                                    const SizedBox(height: 10),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF15803D),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.check_rounded, size: 15),
                                            label: const Text('Acatar Defesa (Cancelar)', style: TextStyle(fontSize: 11.5)),
                                            onPressed: () => _judgeDefense(inf['id'], 'CANCELLED', 'Defesa acolhida pela administração.'),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFDC2626),
                                              side: const BorderSide(color: Color(0xFFF87171)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.close_rounded, size: 15),
                                            label: const Text('Manter Multa', style: TextStyle(fontSize: 11.5)),
                                            onPressed: () => _judgeDefense(inf['id'], 'CONFIRMED', 'Defesa indeferida. Infração mantida.'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (canDefend && !widget.canManage) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.tonalIcon(
                                        icon: const Icon(Icons.shield_outlined, size: 16),
                                        label: const Text('Apresentar Defesa Prévia'),
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
  const _LockersSubView({required this.api, required this.condominiumId});
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listLockers(widget.condominiumId);
      if (mounted) setState(() { _lockers = list; _loading = false; });
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
          decoration: const InputDecoration(labelText: 'Digite o PIN de 6 dígitos', hintText: '123456'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar Retirada')),
        ],
      ),
    );

    if (ok == true && pin.text.isNotEmpty) {
      await widget.api.retrieveLocker(lockerId, pin.text.trim());
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Armário destravado com sucesso!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lockers.isEmpty
              ? const Center(child: Text('Nenhuma encomenda aguardando em armários inteligentes.'))
              : ListView.separated(
                  itemCount: _lockers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final l = _lockers[idx];
                    final isOccupied = l['status'] == 'OCCUPIED';
                    final pin = l['pinCode'];

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFDCFCE7),
                              child: Icon(Icons.lock_open_rounded, color: Color(0xFF15803D)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Compartimento ${l['compartmentNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Código: ${l['trackingCode'] ?? 'Sem rastreio'} • Entregador: ${l['courierName'] ?? 'Portaria'}'),
                                  if (pin != null)
                                    Text('Seu PIN: $pin', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            if (isOccupied)
                              FilledButton.icon(
                                icon: const Icon(Icons.vpn_key_rounded, size: 16),
                                label: const Text('Retirar'),
                                onPressed: () => _retrieve(l['id']),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ----------------------------------------------------
// 11. LISTAS DE CONVIDADOS DE EVENTOS
// ----------------------------------------------------
class _GuestListsSubView extends StatefulWidget {
  const _GuestListsSubView({required this.api, required this.condominiumId});
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listGuestLists(widget.condominiumId);
      if (mounted) setState(() { _lists = list; _loading = false; });
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
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome Completo *')),
            const SizedBox(height: 10),
            TextField(controller: doc, decoration: const InputDecoration(labelText: 'Documento (RG/CPF)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Adicionar')),
        ],
      ),
    );

    if (ok == true && name.text.isNotEmpty) {
      await widget.api.addGuest(guestListId: listId, guestName: name.text.trim(), documentNumber: doc.text.trim().isEmpty ? null : doc.text.trim());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? const Center(child: Text('Nenhuma lista de convidados criada para eventos.'))
              : ListView.separated(
                  itemCount: _lists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final gl = _lists[idx];
                    final guests = (gl['guests'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: ExpansionTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.celebration_rounded, color: Color(0xFF2F3FB0))),
                        title: Text(gl['eventTitle'] ?? 'Festa', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Data: ${gl['eventDate'] ?? ''} • ${guests.length} convidados'),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_add_alt),
                          tooltip: 'Adicionar Convidado',
                          onPressed: () => _addGuestDialog(gl['id']),
                        ),
                        children: [
                          ...guests.map((g) => ListTile(
                                dense: true,
                                leading: Icon(g['checkedIn'] == true ? Icons.check_circle : Icons.person_outline, color: g['checkedIn'] == true ? Colors.green : Colors.grey),
                                title: Text(g['guestName'] ?? ''),
                                subtitle: Text(g['documentNumber'] ?? 'Sem documento'),
                              )),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ----------------------------------------------------
// 12. MANUTENÇÃO PREDIAL & ORDENS DE SERVIÇO
// ----------------------------------------------------
class _MaintenanceSubView extends StatefulWidget {
  const _MaintenanceSubView({required this.api, required this.condominiumId, this.canManage = false});
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_MaintenanceSubView> createState() => _MaintenanceSubViewState();
}

class _MaintenanceSubViewState extends State<_MaintenanceSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
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
      final list = await widget.api.listMaintenanceOrders(widget.condominiumId, _statusFilter);
      if (mounted) setState(() { _orders = list; _loading = false; });
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Título da Manutenção *')),
                  const SizedBox(height: 10),
                  TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição do Problema / Serviço *')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'HIDRAULICA', child: Text('Hidráulica')),
                      DropdownMenuItem(value: 'ELETRICA', child: Text('Elétrica')),
                      DropdownMenuItem(value: 'ELEVADORES', child: Text('Elevadores')),
                      DropdownMenuItem(value: 'ESTRUTURAL', child: Text('Estrutural / Alvenaria')),
                      DropdownMenuItem(value: 'SEGURANCA', child: Text('Segurança / CFTV')),
                      DropdownMenuItem(value: 'AVCB_INCENDIO', child: Text('Incêndio / AVCB')),
                      DropdownMenuItem(value: 'LIMPEZA', child: Text('Limpeza / Conservação')),
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
                            DropdownMenuItem(value: 'CORRECTIVE', child: Text('Corretiva')),
                            DropdownMenuItem(value: 'PREVENTIVE', child: Text('Preventiva')),
                          ],
                          onChanged: (v) => setDState(() => type = v ?? 'CORRECTIVE'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          decoration: const InputDecoration(labelText: 'Prioridade'),
                          items: const [
                            DropdownMenuItem(value: 'LOW', child: Text('Baixa')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Média')),
                            DropdownMenuItem(value: 'HIGH', child: Text('Alta')),
                            DropdownMenuItem(value: 'URGENT', child: Text('Urgente')),
                          ],
                          onChanged: (v) => setDState(() => priority = v ?? 'MEDIUM'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: contractor, decoration: const InputDecoration(labelText: 'Empresa / Prestador Contratado')),
                  const SizedBox(height: 10),
                  TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contato do Prestador (Telefone/Email)')),
                  const SizedBox(height: 10),
                  TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo Estimado (R\$)')),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(scheduledDate == null ? 'Data Agendada: Não definida' : 'Data: ${DateFormat('dd/MM/yyyy').format(scheduledDate!)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDState(() => scheduledDate = picked);
                      },
                      child: const Text('Selecionar'),
                    ),
                  ),
                  TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações / Recomendações')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || desc.text.trim().isEmpty) return;
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
          contractorName: contractor.text.trim().isNotEmpty ? contractor.text.trim() : null,
          contractorContact: contact.text.trim().isNotEmpty ? contact.text.trim() : null,
          scheduledDate: scheduledDate,
          estimatedCost: double.tryParse(cost.text.replaceAll(',', '.')),
          notes: notes.text.trim().isNotEmpty ? notes.text.trim() : null,
        );
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _updateStatusDialog(Map<String, dynamic> order) async {
    final statusCtrl = TextEditingController(text: order['status'] ?? 'OPEN');
    final actualCost = TextEditingController(text: order['actualCost']?.toString() ?? '');
    final notes = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text('Atualizar O.S. #${order['id']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: statusCtrl.text,
                decoration: const InputDecoration(labelText: 'Novo Status'),
                items: const [
                  DropdownMenuItem(value: 'OPEN', child: Text('Aberta')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Em Andamento')),
                  DropdownMenuItem(value: 'COMPLETED', child: Text('Concluída')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelada')),
                ],
                onChanged: (v) => setDState(() => statusCtrl.text = v ?? 'OPEN'),
              ),
              const SizedBox(height: 10),
              if (statusCtrl.text == 'COMPLETED') ...[
                TextField(controller: actualCost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo Real Finalizado (R\$)')),
                const SizedBox(height: 10),
              ],
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas da Conclusão / Andamento')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
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
        );
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'OPEN': return const Color(0xFFF59E0B);
      case 'IN_PROGRESS': return const Color(0xFF2563EB);
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'CANCELLED': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'OPEN': return 'Aberta';
      case 'IN_PROGRESS': return 'Em Andamento';
      case 'COMPLETED': return 'Concluída';
      case 'CANCELLED': return 'Cancelada';
      default: return status ?? 'Aberta';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Ordem de Serviço'),
        onPressed: _openNewOrderDialog,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todas'),
                        selected: _statusFilter == null,
                        onSelected: (_) { setState(() => _statusFilter = null); _load(); },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Abertas'),
                        selected: _statusFilter == 'OPEN',
                        onSelected: (_) { setState(() => _statusFilter = 'OPEN'); _load(); },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Em Andamento'),
                        selected: _statusFilter == 'IN_PROGRESS',
                        onSelected: (_) { setState(() => _statusFilter = 'IN_PROGRESS'); _load(); },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Concluídas'),
                        selected: _statusFilter == 'COMPLETED',
                        onSelected: (_) { setState(() => _statusFilter = 'COMPLETED'); _load(); },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _orders.isEmpty
                      ? const Center(child: Text('Nenhuma ordem de serviço encontrada.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final o = _orders[index];
                            final status = o['status']?.toString() ?? 'OPEN';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                                          child: Text(o['category'] ?? 'Geral', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                                        ),
                                        const Spacer(),
                                        if (widget.canManage)
                                          IconButton(
                                            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
                                            tooltip: 'Atualizar Status',
                                            onPressed: () => _updateStatusDialog(o),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(o['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(o['description'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
                                    const Divider(height: 20),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      children: [
                                        if (o['contractorName'] != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.engineering_outlined, size: 16, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text('Prestador: ${o['contractorName']}', style: const TextStyle(fontSize: 12.5)),
                                            ],
                                          ),
                                        if (o['scheduledDate'] != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text('Data: ${o['scheduledDate']}', style: const TextStyle(fontSize: 12.5)),
                                            ],
                                          ),
                                        if (o['estimatedCost'] != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.attach_money_rounded, size: 16, color: Color(0xFF64748B)),
                                              Text('Est.: R\$ ${(o['estimatedCost'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5)),
                                            ],
                                          ),
                                        if (o['actualCost'] != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                                              const SizedBox(width: 4),
                                              Text('Final: R\$ ${(o['actualCost'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
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
              ],
            ),
    );
  }
}

// ----------------------------------------------------
// 13. ASSEMBLEIAS & DELIBERAÇÕES
// ----------------------------------------------------
class _AssembliesSubView extends StatefulWidget {
  const _AssembliesSubView({required this.api, required this.condominiumId, this.canManage = false});
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_AssembliesSubView> createState() => _AssembliesSubViewState();
}

class _AssembliesSubViewState extends State<_AssembliesSubView> {
  bool _loading = true;
  List<Map<String, dynamic>> _assemblies = [];
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.events.listen((event) {
      if (event.type == 'ASSEMBLY_UPDATED' && mounted) {
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
      final list = await widget.api.listAssemblies(widget.condominiumId);
      if (mounted) setState(() { _assemblies = list; _loading = false; });
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateAssemblyDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final location = TextEditingController();
    String type = 'ORDINARY';
    DateTime meetingDate = DateTime.now().add(const Duration(days: 7));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.groups_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Convocar Nova Assembleia'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Título da Assembleia *')),
                  const SizedBox(height: 10),
                  TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição / Pauta Preliminar')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Tipo de Assembleia'),
                    items: const [
                      DropdownMenuItem(value: 'ORDINARY', child: Text('Assembleia Geral Ordinária (AGO)')),
                      DropdownMenuItem(value: 'EXTRAORDINARY', child: Text('Assembleia Geral Extraordinária (AGE)')),
                    ],
                    onChanged: (v) => setDState(() => type = v ?? 'ORDINARY'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: location, decoration: const InputDecoration(labelText: 'Local ou Link da Videochamada (Meet/Zoom)')),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text('Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(meetingDate)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: meetingDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null && context.mounted) {
                          final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(meetingDate));
                          if (t != null) {
                            setDState(() => meetingDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                          }
                        }
                      },
                      child: const Text('Alterar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Convocar Assembleia'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await widget.api.createAssembly(
          widget.condominiumId,
          title: title.text.trim(),
          description: desc.text.trim().isNotEmpty ? desc.text.trim() : null,
          type: type,
          meetingDate: meetingDate,
          locationOrLink: location.text.trim().isNotEmpty ? location.text.trim() : null,
        );
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _openAddTopicDialog(num assemblyId) async {
    final title = TextEditingController();
    final desc = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Pauta de Votação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Título da Pauta *')),
            const SizedBox(height: 10),
            TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Detalhamento da Proposta')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Adicionar Pauta'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await widget.api.addAssemblyTopic(
          assemblyId,
          title: title.text.trim(),
          description: desc.text.trim().isNotEmpty ? desc.text.trim() : null,
        );
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _castVote(num topicId, String choice) async {
    try {
      await widget.api.castAssemblyVote(topicId, choice);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voto registrado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao votar: $e')));
    }
  }

  Future<void> _toggleVoting(num topicId, bool open) async {
    try {
      await widget.api.toggleAssemblyTopicVoting(topicId, open);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Convocar Assembleia'),
              onPressed: _openCreateAssemblyDialog,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assemblies.isEmpty
              ? const Center(child: Text('Nenhuma assembleia agendada no momento.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _assemblies.length,
                  itemBuilder: (context, index) {
                    final a = _assemblies[index];
                    final topics = (a['topics'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
                    final dateStr = a['meetingDate'] != null ? a['meetingDate'].toString().replaceFirst('T', ' ') : '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      elevation: 0,
                      child: ExpansionTile(
                        initiallyExpanded: index == 0,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEFF6FF),
                          child: Icon(Icons.groups_outlined, color: Color(0xFF2563EB)),
                        ),
                        title: Text(a['title'] ?? 'Assembleia', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                          '${a['type'] == 'ORDINARY' ? 'AGO' : 'AGE'} • $dateStr',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        trailing: widget.canManage
                            ? IconButton(
                                icon: const Icon(Icons.post_add_rounded, color: Color(0xFF2563EB)),
                                tooltip: 'Adicionar Pauta',
                                onPressed: () => _openAddTopicDialog(a['id']),
                              )
                            : null,
                        children: [
                          if (a['description'] != null && a['description'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(a['description'], style: const TextStyle(color: Color(0xFF334155))),
                            ),
                          if (a['locationOrLink'] != null && a['locationOrLink'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text('Acesso: ${a['locationOrLink']}', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13))),
                                ],
                              ),
                            ),
                          const Divider(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text('Pautas & Deliberações (${topics.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (topics.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Nenhuma pauta cadastrada para esta assembleia.', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ...topics.map((t) {
                              final open = t['votingOpen'] == true;
                              final userVote = t['userVote'];
                              final inFavor = t['inFavorCount'] ?? 0;
                              final against = t['againstCount'] ?? 0;
                              final abstain = t['abstainCount'] ?? 0;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        ),
                                        if (widget.canManage)
                                          TextButton.icon(
                                            icon: Icon(open ? Icons.lock_outline : Icons.lock_open, size: 16),
                                            label: Text(open ? 'Encerrar Votação' : 'Abrir Votação'),
                                            onPressed: () => _toggleVoting(t['id'], !open),
                                          ),
                                      ],
                                    ),
                                    if (t['description'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(t['description'], style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                                          child: Text('Sim: $inFavor', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                                          child: Text('Não: $against', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                          child: Text('Abstenções: $abstain', style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (userVote != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                          const SizedBox(width: 6),
                                          Text('Seu voto registrado: ${_voteLabel(userVote)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 12)),
                                        ],
                                      )
                                    else if (open) ...[
                                      const Text('Votação aberta aos moradores:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          FilledButton.tonal(
                                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDCFCE7), foregroundColor: const Color(0xFF15803D)),
                                            onPressed: () => _castVote(t['id'], 'IN_FAVOR'),
                                            child: const Text('A Favor'),
                                          ),
                                          FilledButton.tonal(
                                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFEE2E2), foregroundColor: const Color(0xFFB91C1C)),
                                            onPressed: () => _castVote(t['id'], 'AGAINST'),
                                            child: const Text('Contra'),
                                          ),
                                          FilledButton.tonal(
                                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), foregroundColor: const Color(0xFF475569)),
                                            onPressed: () => _castVote(t['id'], 'ABSTAIN'),
                                            child: const Text('Abstenção'),
                                          ),
                                        ],
                                      ),
                                    ] else
                                      const Text('Votação encerrada ou aguardando abertura pelo síndico.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _voteLabel(String choice) {
    switch (choice) {
      case 'IN_FAVOR': return 'A Favor';
      case 'AGAINST': return 'Contra';
      case 'ABSTAIN': return 'Abstenção';
      default: return choice;
    }
  }
}

// ----------------------------------------------------
// 14. TRANSPARÊNCIA FINANCEIRA & DESPESAS
// ----------------------------------------------------
class _FinancialSubView extends StatefulWidget {
  const _FinancialSubView({required this.api, required this.condominiumId, this.canManage = false});
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_FinancialSubView> createState() => _FinancialSubViewState();
}

class _FinancialSubViewState extends State<_FinancialSubView> {
  bool _loading = true;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _expenses = [];
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.events.listen((event) {
      if (event.type == 'INVOICE_UPDATED' && mounted) {
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
        widget.api.getFinancialSummary(widget.condominiumId),
        widget.api.listExpenses(widget.condominiumId),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] is Map<String, dynamic> ? results[0] as Map<String, dynamic> : null;
          _expenses = results[1] is List ? (results[1] as List).whereType<Map<String, dynamic>>().toList() : [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateExpenseDialog() async {
    final desc = TextEditingController();
    final amount = TextEditingController();
    final supplier = TextEditingController();
    final docNumber = TextEditingController();
    String category = 'MANUTENCAO';
    DateTime dueDate = DateTime.now().add(const Duration(days: 15));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Lançar Despesa Operacional'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria da Despesa'),
                    items: const [
                      DropdownMenuItem(value: 'MANUTENCAO', child: Text('Manutenção Predial')),
                      DropdownMenuItem(value: 'ENERGIA', child: Text('Energia Elétrica (Áreas Comuns)')),
                      DropdownMenuItem(value: 'AGUA', child: Text('Água e Esgoto')),
                      DropdownMenuItem(value: 'PESSOAL', child: Text('Folha de Pagamento / Portaria')),
                      DropdownMenuItem(value: 'SEGURANCA', child: Text('Segurança / Monitoramento')),
                      DropdownMenuItem(value: 'SEGURO', child: Text('Seguro Predial Obrigatório')),
                      DropdownMenuItem(value: 'JURIDICO', child: Text('Assessoria Jurídica / Contábil')),
                      DropdownMenuItem(value: 'ADMINISTRATIVO', child: Text('Taxas e Despesas Bancárias')),
                      DropdownMenuItem(value: 'OUTROS', child: Text('Outros')),
                    ],
                    onChanged: (v) => setDState(() => category = v ?? 'MANUTENCAO'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrição / Finalidade *')),
                  const SizedBox(height: 10),
                  TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor Total (R\$) *')),
                  const SizedBox(height: 10),
                  TextField(controller: supplier, decoration: const InputDecoration(labelText: 'Fornecedor / Razão Social')),
                  const SizedBox(height: 10),
                  TextField(controller: docNumber, decoration: const InputDecoration(labelText: 'Número da Nota Fiscal / Fatura')),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text('Data de Vencimento: ${DateFormat('dd/MM/yyyy').format(dueDate)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDState(() => dueDate = picked);
                      },
                      child: const Text('Selecionar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (desc.text.trim().isEmpty || amount.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Lançar Despesa'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await widget.api.createExpense(
          widget.condominiumId,
          category: category,
          description: desc.text.trim(),
          amount: double.parse(amount.text.replaceAll(',', '.')),
          dueDate: dueDate,
          supplier: supplier.text.trim().isNotEmpty ? supplier.text.trim() : null,
          documentNumber: docNumber.text.trim().isNotEmpty ? docNumber.text.trim() : null,
        );
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _payExpense(num expenseId) async {
    try {
      await widget.api.payExpense(expenseId);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Despesa liquidada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao liquidar despesa: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalInvoiced = (_summary?['totalInvoiced'] as num?)?.toDouble() ?? 0.0;
    final totalCollected = (_summary?['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (_summary?['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final netBalance = (_summary?['netBalance'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Lançar Despesa'),
              onPressed: _openCreateExpenseDialog,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // KPI Cards Row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpiCard('Total Arrecadado', 'R\$ ${totalCollected.toStringAsFixed(2)}', Icons.arrow_downward_rounded, const Color(0xFF10B981)),
                      _kpiCard('Despesas Pagas', 'R\$ ${totalExpenses.toStringAsFixed(2)}', Icons.arrow_upward_rounded, const Color(0xFFEF4444)),
                      _kpiCard('Saldo Operacional', 'R\$ ${netBalance.toStringAsFixed(2)}', Icons.account_balance_rounded, netBalance >= 0 ? const Color(0xFF2563EB) : const Color(0xFFEF4444)),
                      _kpiCard('Total Previsto', 'R\$ ${totalInvoiced.toStringAsFixed(2)}', Icons.receipt_long_outlined, const Color(0xFF64748B)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Histórico de Despesas do Condomínio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${_expenses.length} lançamentos', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_expenses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nenhuma despesa registrada para este condomínio.', textAlign: TextAlign.center),
                      ),
                    )
                  else
                    ..._expenses.map((exp) {
                      final status = exp['status']?.toString() ?? 'PENDING';
                      final isPaid = status == 'PAID';
                      final amountVal = (exp['amount'] as num?)?.toDouble() ?? 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            child: Icon(isPaid ? Icons.check_circle_outline : Icons.pending_actions_rounded, color: isPaid ? const Color(0xFF15803D) : const Color(0xFFD97706)),
                          ),
                          title: Text(exp['description'] ?? 'Despesa', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                          subtitle: Text(
                            'Venc.: ${exp['dueDate'] ?? ''} • Fornecedor: ${exp['supplier'] ?? 'Geral'}\nCat.: ${exp['category'] ?? ''}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'R\$ ${amountVal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              if (widget.canManage && !isPaid)
                                SizedBox(
                                  height: 26,
                                  child: FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _payExpense(exp['id']),
                                    child: const Text('Liquidar', style: TextStyle(fontSize: 11.5)),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPaid ? 'Pago' : 'Pendente',
                                    style: TextStyle(color: isPaid ? const Color(0xFF15803D) : const Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

