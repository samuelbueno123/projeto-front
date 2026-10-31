import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class CommunityHubView extends StatefulWidget {
  const CommunityHubView({
    super.key,
    required this.api,
    required this.condominiumId,
    this.initialCategoryIndex = 0,
  });

  final CommunityApi api;
  final num condominiumId;
  final int initialCategoryIndex;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Compact Category TabBar avoiding page vertical scroll
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF2F3FB0),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2F3FB0),
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
            ],
          ),
        ),
        const Divider(height: 1),
        // Content area sized properly
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TicketsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _VisitorsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _PollsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _ClassifiedsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _VehiclesSubView(api: widget.api, condominiumId: widget.condominiumId),
              _PetsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _MovingSubView(api: widget.api, condominiumId: widget.condominiumId),
              _DocumentsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _InfractionsSubView(api: widget.api, condominiumId: widget.condominiumId),
              _LockersSubView(api: widget.api, condominiumId: widget.condominiumId),
              _GuestListsSubView(api: widget.api, condominiumId: widget.condominiumId),
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
  const _TicketsSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

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
                                  if (t['adminResponse'] != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                                      child: Text('Resposta da administração: ${t['adminResponse']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
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
                              trailing: Chip(
                                label: Text(status, style: const TextStyle(fontSize: 11)),
                                backgroundColor: status == 'CHECKED_IN' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
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
                                      Text('Contato: ${a['contactPhone'] ?? 'Direto no app'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.send_rounded, size: 16),
                                        label: const Text('Tenho Interesse'),
                                        onPressed: () => _sendInterest(a['id']),
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
  const _MovingSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

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
                          final status = r['status']?.toString() ?? 'PENDING';
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.local_shipping_rounded, color: Color(0xFF2F3FB0))),
                              title: Text('${r['type'] ?? 'MUDANÇA'} • ${r['movingDate'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Turno: ${r['period'] ?? ''} • Transportadora: ${r['companyName'] ?? 'Própria'}'),
                              trailing: Chip(
                                label: Text(status, style: const TextStyle(fontSize: 11)),
                                backgroundColor: status == 'APPROVED' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
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
  const _InfractionsSubView({required this.api, required this.condominiumId});
  final CommunityApi api;
  final num condominiumId;

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _infractions.isEmpty
              ? const Center(child: Text('Nenhuma advertência ou multa registrada para sua unidade. Parabéns! 🎉'))
              : ListView.separated(
                  itemCount: _infractions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final inf = _infractions[idx];
                    final status = inf['status']?.toString() ?? 'ISSUED';
                    final canDefend = status == 'ISSUED';

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
                            if (inf['defense'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: Text('Sua defesa: ${inf['defense']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              ),
                            ],
                            if (canDefend) ...[
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
