part of 'community_hub_view.dart';

// 13. ASSEMBLEIAS & DELIBERAÇÕES
// ----------------------------------------------------
class _AssembliesSubView extends StatefulWidget {
  const _AssembliesSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
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
      if (mounted) {
        setState(() {
          _assemblies = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateAssemblyDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final location = TextEditingController();
    final quorumCtrl = TextEditingController(text: '50');
    String type = 'ORDINARY';
    bool blockDelinquentUnits = false;
    DateTime meetingDate = DateTime.now().add(const Duration(days: 7));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.groups_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Convocar Nova Assembleia'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Título da Assembleia *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrição / Pauta Preliminar',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Assembleia',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ORDINARY',
                        child: Text('Assembleia Geral Ordinária (AGO)'),
                      ),
                      DropdownMenuItem(
                        value: 'EXTRAORDINARY',
                        child: Text('Assembleia Geral Extraordinária (AGE)'),
                      ),
                    ],
                    onChanged: (v) => setDState(() => type = v ?? 'ORDINARY'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Local ou Link da Videochamada (Meet/Zoom)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: quorumCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quórum Mínimo (%)',
                      hintText: '50',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Bloquear voto de unidades inadimplentes',
                    ),
                    subtitle: const Text(
                      'Conforme Art. 1.335 III do Código Civil',
                    ),
                    value: blockDelinquentUnits,
                    onChanged: (v) => setDState(() => blockDelinquentUnits = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      'Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(meetingDate)}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: meetingDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null && context.mounted) {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(meetingDate),
                          );
                          if (t != null) {
                            setDState(
                              () => meetingDate = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                t.hour,
                                t.minute,
                              ),
                            );
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
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

    final titleText = title.text.trim();
    final descText = desc.text.trim();
    final locationText = location.text.trim();
    final quorumVal = int.tryParse(quorumCtrl.text.trim()) ?? 50;
    title.dispose();
    desc.dispose();
    location.dispose();
    quorumCtrl.dispose();

    if (ok == true) {
      try {
        await widget.api.createAssembly(
          widget.condominiumId,
          title: titleText,
          description: descText.isNotEmpty ? descText : null,
          type: type,
          meetingDate: meetingDate,
          locationOrLink: locationText.isNotEmpty ? locationText : null,
          blockDelinquentUnits: blockDelinquentUnits,
          quorumMinimumPercent: quorumVal,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  Future<void> _checkInAssembly(num assemblyId) async {
    try {
      await widget.api.checkInAssembly(assemblyId);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presença registrada na ata da assembleia!'),
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
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Título da Pauta *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Detalhamento da Proposta',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
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

    final titleText = title.text.trim();
    final descText = desc.text.trim();
    title.dispose();
    desc.dispose();

    if (ok == true) {
      try {
        await widget.api.addAssemblyTopic(
          assemblyId,
          title: titleText,
          description: descText.isNotEmpty ? descText : null,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao votar: $e')));
      }
    }
  }

  Future<void> _toggleVoting(num topicId, bool open) async {
    try {
      await widget.api.toggleAssemblyTopicVoting(topicId, open);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
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
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SaaSLoadingState(
                  message: 'Carregando assembleias gerais...',
                ),
              ),
            )
          : _assemblies.isEmpty
          ? const SaaSEmptyState(
              icon: Icons.groups_outlined,
              title: 'Nenhuma assembleia agendada',
              subtitle:
                  'Não há assembleias ordinárias ou extraordinárias convocadas no momento.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _assemblies.length,
              itemBuilder: (context, index) {
                final a = _assemblies[index];
                final topics =
                    (a['topics'] as List?)
                        ?.whereType<Map<String, dynamic>>()
                        .toList() ??
                    [];
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final dateStr = a['meetingDate'] != null
                    ? a['meetingDate'].toString().replaceFirst('T', ' ')
                    : '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: SaaSColors.surface(isDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: SaaSColors.border(isDark)),
                  ),
                  elevation: 0,
                  child: ExpansionTile(
                    initiallyExpanded: index == 0,
                    leading: CircleAvatar(
                      backgroundColor: SaaSColors.primary.withValues(
                        alpha: isDark ? 0.22 : 0.14,
                      ),
                      child: Icon(
                        Icons.groups_outlined,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                    title: Text(
                      a['title'] ?? 'Assembleia',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${a['type'] == 'ORDINARY' ? 'AGO' : 'AGE'} • $dateStr • Presenças: ${a['participantCount'] ?? 0} (Quórum mín.: ${a['quorumMinimumPercent'] ?? 50}%)',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (a['checkedInByCurrentUser'] == true)
                          const Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              'Presente',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF15803D),
                              ),
                            ),
                            backgroundColor: Color(0xFFDCFCE7),
                          )
                        else
                          FilledButton.tonalIcon(
                            icon: const Icon(
                              Icons.how_to_reg_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Check-in',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _checkInAssembly(a['id']),
                          ),
                        if (widget.canManage)
                          IconButton(
                            icon: const Icon(
                              Icons.post_add_rounded,
                              color: Color(0xFF2563EB),
                            ),
                            tooltip: 'Adicionar Pauta',
                            onPressed: () => _openAddTopicDialog(a['id']),
                          ),
                      ],
                    ),
                    children: [
                      if (a['description'] != null &&
                          a['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            a['description'],
                            style: const TextStyle(color: Color(0xFF334155)),
                          ),
                        ),
                      if (a['locationOrLink'] != null &&
                          a['locationOrLink'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Acesso: ${a['locationOrLink']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Pautas & Deliberações (${topics.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (topics.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Nenhuma pauta cadastrada para esta assembleia.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ...topics.map((t) {
                          final open = t['votingOpen'] == true;
                          final userVote = t['userVote'];
                          final inFavor = t['inFavorCount'] ?? 0;
                          final against = t['againstCount'] ?? 0;
                          final abstain = t['abstainCount'] ?? 0;
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? SaaSColors.deepNavy
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: SaaSColors.border(isDark),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t['title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (widget.canManage)
                                      TextButton.icon(
                                        icon: Icon(
                                          open
                                              ? Icons.lock_outline
                                              : Icons.lock_open,
                                          size: 16,
                                        ),
                                        label: Text(
                                          open
                                              ? 'Encerrar Votação'
                                              : 'Abrir Votação',
                                        ),
                                        onPressed: () =>
                                            _toggleVoting(t['id'], !open),
                                      ),
                                  ],
                                ),
                                if (t['description'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    t['description'],
                                    style: TextStyle(
                                      color: SaaSColors.textSecondary(isDark),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SaaSColors.success.withValues(
                                          alpha: isDark ? 0.20 : 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Sim: $inFavor',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF15803D),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SaaSColors.error.withValues(
                                          alpha: isDark ? 0.20 : 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Não: $against',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFF87171)
                                              : const Color(0xFFB91C1C),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Abstenções: $abstain',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF475569),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (userVote != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF10B981),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Seu voto registrado: ${_voteLabel(userVote)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (open) ...[
                                  const Text(
                                    'Votação aberta aos moradores:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: SaaSColors.success
                                              .withValues(
                                                alpha: isDark ? 0.22 : 0.16,
                                              ),
                                          foregroundColor: isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF15803D),
                                        ),
                                        onPressed: () =>
                                            _castVote(t['id'], 'IN_FAVOR'),
                                        child: const Text('A Favor'),
                                      ),
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: SaaSColors.error
                                              .withValues(
                                                alpha: isDark ? 0.22 : 0.16,
                                              ),
                                          foregroundColor: isDark
                                              ? const Color(0xFFF87171)
                                              : const Color(0xFFB91C1C),
                                        ),
                                        onPressed: () =>
                                            _castVote(t['id'], 'AGAINST'),
                                        child: const Text('Contra'),
                                      ),
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFF1F5F9),
                                          foregroundColor: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF475569),
                                        ),
                                        onPressed: () =>
                                            _castVote(t['id'], 'ABSTAIN'),
                                        child: const Text('Abstenção'),
                                      ),
                                    ],
                                  ),
                                ] else
                                  const Text(
                                    'Votação encerrada ou aguardando abertura pelo síndico.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
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
      case 'IN_FAVOR':
        return 'A Favor';
      case 'AGAINST':
        return 'Contra';
      case 'ABSTAIN':
        return 'Abstenção';
      default:
        return choice;
    }
  }
}

// ----------------------------------------------------
// 14. TRANSPARÊNCIA FINANCEIRA & DESPESAS
// ----------------------------------------------------
class _FinancialSubView extends StatefulWidget {
  const _FinancialSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
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
          _summary = results[0] is Map<String, dynamic>
              ? results[0] as Map<String, dynamic>
              : null;
          _expenses = results[1] is List
              ? (results[1] as List).whereType<Map<String, dynamic>>().toList()
              : [];
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                    decoration: const InputDecoration(
                      labelText: 'Categoria da Despesa',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'MANUTENCAO',
                        child: Text('Manutenção Predial'),
                      ),
                      DropdownMenuItem(
                        value: 'ENERGIA',
                        child: Text('Energia Elétrica (Áreas Comuns)'),
                      ),
                      DropdownMenuItem(
                        value: 'AGUA',
                        child: Text('Água e Esgoto'),
                      ),
                      DropdownMenuItem(
                        value: 'PESSOAL',
                        child: Text('Folha de Pagamento / Portaria'),
                      ),
                      DropdownMenuItem(
                        value: 'SEGURANCA',
                        child: Text('Segurança / Monitoramento'),
                      ),
                      DropdownMenuItem(
                        value: 'SEGURO',
                        child: Text('Seguro Predial Obrigatório'),
                      ),
                      DropdownMenuItem(
                        value: 'JURIDICO',
                        child: Text('Assessoria Jurídica / Contábil'),
                      ),
                      DropdownMenuItem(
                        value: 'ADMINISTRATIVO',
                        child: Text('Taxas e Despesas Bancárias'),
                      ),
                      DropdownMenuItem(value: 'OUTROS', child: Text('Outros')),
                    ],
                    onChanged: (v) =>
                        setDState(() => category = v ?? 'MANUTENCAO'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: desc,
                    decoration: const InputDecoration(
                      labelText: 'Descrição / Finalidade *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor Total (R\$) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: supplier,
                    decoration: const InputDecoration(
                      labelText: 'Fornecedor / Razão Social',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: docNumber,
                    decoration: const InputDecoration(
                      labelText: 'Número da Nota Fiscal / Fatura',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      'Data de Vencimento: ${DateFormat('dd/MM/yyyy').format(dueDate)}',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (desc.text.trim().isEmpty || amount.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Lançar Despesa'),
            ),
          ],
        ),
      ),
    );

    final descText = desc.text.trim();
    final parsedAmount = double.tryParse(amount.text.replaceAll(',', '.').trim());
    final supplierText = supplier.text.trim();
    final docText = docNumber.text.trim();
    desc.dispose();
    amount.dispose();
    supplier.dispose();
    docNumber.dispose();

    if (ok == true) {
      if (parsedAmount == null) {
        if (mounted) {
          SaaSFeedback.showWarning(context, 'Informe um valor válido para a despesa.');
        }
        return;
      }
      try {
        await widget.api.createExpense(
          widget.condominiumId,
          category: category,
          description: descText,
          amount: parsedAmount,
          dueDate: dueDate,
          supplier: supplierText.isNotEmpty ? supplierText : null,
          documentNumber: docText.isNotEmpty ? docText : null,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao liquidar despesa: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalInvoiced =
        (_summary?['totalInvoiced'] as num?)?.toDouble() ?? 0.0;
    final totalCollected =
        (_summary?['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (_summary?['totalExpenses'] as num?)?.toDouble() ?? 0.0;
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
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SaaSLoadingState(
                  message: 'Carregando demonstrativo financeiro e balancete...',
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // KPI Cards Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _kpiCard(
                                'Total Arrecadado',
                                'R\$ ${totalCollected.toStringAsFixed(2)}',
                                Icons.arrow_downward_rounded,
                                const Color(0xFF10B981),
                              ),
                              _kpiCard(
                                'Despesas Pagas',
                                'R\$ ${totalExpenses.toStringAsFixed(2)}',
                                Icons.arrow_upward_rounded,
                                const Color(0xFFEF4444),
                              ),
                              _kpiCard(
                                'Saldo Operacional',
                                'R\$ ${netBalance.toStringAsFixed(2)}',
                                Icons.account_balance_rounded,
                                netBalance >= 0
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFEF4444),
                              ),
                              _kpiCard(
                                'Total Previsto',
                                'R\$ ${totalInvoiced.toStringAsFixed(2)}',
                                Icons.receipt_long_outlined,
                                const Color(0xFF64748B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Histórico de Despesas do Condomínio',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${_expenses.length} lançamentos',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expenses.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverToBoxAdapter(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nenhuma despesa registrada para este condomínio.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverList.builder(
                        itemCount: _expenses.length,
                        itemBuilder: (context, idx) {
                          final exp = _expenses[idx];
                          final status = exp['status']?.toString() ?? 'PENDING';
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final isPaid = status == 'PAID';
                          final amountVal =
                              (exp['amount'] as num?)?.toDouble() ?? 0.0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            color: SaaSColors.surface(isDark),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: SaaSColors.border(isDark)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    (isPaid
                                            ? SaaSColors.success
                                            : SaaSColors.warning)
                                        .withValues(alpha: isDark ? 0.20 : 0.14),
                                child: Icon(
                                  isPaid
                                      ? Icons.check_circle_outline
                                      : Icons.pending_actions_rounded,
                                  color: isPaid
                                      ? (isDark
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF15803D))
                                      : (isDark
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFFD97706)),
                                ),
                              ),
                              title: Text(
                                exp['description'] ?? 'Despesa',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              subtitle: Text(
                                'Venc.: ${exp['dueDate'] ?? ''} • Fornecedor: ${exp['supplier'] ?? 'Geral'}\nCat.: ${exp['category'] ?? ''}',
                                style: TextStyle(
                                  color: SaaSColors.textSecondary(isDark),
                                  fontSize: 12.5,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'R\$ ${amountVal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: SaaSColors.textPrimary(isDark),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (widget.canManage && !isPaid)
                                    SizedBox(
                                      height: 26,
                                      child: FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _payExpense(exp['id']),
                                        child: const Text(
                                          'Liquidar',
                                          style: TextStyle(fontSize: 11.5),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (isPaid
                                                    ? SaaSColors.success
                                                    : SaaSColors.warning)
                                                .withValues(
                                                  alpha: isDark ? 0.20 : 0.14,
                                                ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isPaid ? 'Pago' : 'Pendente',
                                        style: TextStyle(
                                          color: isPaid
                                              ? (isDark
                                                    ? const Color(0xFF34D399)
                                                    : const Color(0xFF15803D))
                                              : (isDark
                                                    ? const Color(0xFFFBBF24)
                                                    : const Color(0xFFD97706)),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
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
            ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaaSColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaaSColors.border(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 15. ACHADOS E PERDIDOS (Comunicação e Categorização)
// ----------------------------------------------------
class _LostFoundSubView extends StatefulWidget {
  const _LostFoundSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_LostFoundSubView> createState() => _LostFoundSubViewState();
}

class _LostFoundSubViewState extends State<_LostFoundSubView> {
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

  Future<void> _openCreateDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    String type = 'FOUND';
    String category = 'KEYS';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.find_in_page_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Expanded(child: Text('Registrar Achado ou Perdido')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Registro',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'FOUND',
                        child: Text('Objeto Encontrado (Achado)'),
                      ),
                      DropdownMenuItem(
                        value: 'LOST',
                        child: Text('Objeto Perdido (Procura-se)'),
                      ),
                    ],
                    onChanged: (v) => setD(() => type = v ?? 'FOUND'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Categoria do Objeto',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'KEYS',
                        child: Text('Chaves / Controles / Tags'),
                      ),
                      DropdownMenuItem(
                        value: 'DOCUMENTS',
                        child: Text('Documentos / Cartões'),
                      ),
                      DropdownMenuItem(
                        value: 'ELECTRONICS',
                        child: Text('Celular / Eletrônicos'),
                      ),
                      DropdownMenuItem(
                        value: 'CLOTHING',
                        child: Text('Roupas / Acessórios'),
                      ),
                      DropdownMenuItem(
                        value: 'PET',
                        child: Text('Animal de Estimação'),
                      ),
                      DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
                    ],
                    onChanged: (v) => setD(() => category = v ?? 'OTHER'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título / Objeto *',
                      hintText: 'Ex: Chaveiro com tag azul',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Local onde foi encontrado/perdido',
                      hintText: 'Ex: Hall do Bloco A / Academia',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrição e características *',
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
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    descCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(c, true);
              },
              child: const Text('Publicar Registro'),
            ),
          ],
        ),
      ),
    );

    final titleVal = titleCtrl.text.trim();
    final descVal = descCtrl.text.trim();
    final locVal = locCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();
    locCtrl.dispose();

    if (ok == true) {
      try {
        await widget.api.createLostFound(
          condoId: widget.condominiumId,
          type: type,
          category: category,
          title: titleVal,
          description: descVal,
          location: locVal,
        );
        _load();
      } catch (e) {
        if (mounted) SaaSFeedback.showError(context, 'Erro ao publicar: $e');
      }
    }
  }

  Future<void> _openMessagesDialog(Map<String, dynamic> item) async {
    final msgCtrl = TextEditingController();
    List<Map<String, dynamic>> messages = [];
    try {
      messages = await widget.api.listLostFoundMessages(item['id']);
    } catch (_) {}

    if (!mounted) {
      msgCtrl.dispose();
      return;
    }
    try {
      await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text('Mensagens: ${item['title'] ?? 'Achados e Perdidos'}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (messages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nenhuma mensagem enviada ainda. Combine a devolução por aqui!',
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${m['senderName'] ?? 'Morador'} (${m['unitLabel'] ?? ''})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          subtitle: Text(m['message'] ?? ''),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: msgCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Enviar mensagem aos envolvidos...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      onPressed: () async {
                        if (msgCtrl.text.trim().isEmpty) return;
                        await widget.api.addLostFoundMessage(
                          item['id'],
                          message: msgCtrl.text.trim(),
                        );
                        msgCtrl.clear();
                        messages = await widget.api.listLostFoundMessages(
                          item['id'],
                        );
                        setD(() {});
                        _load();
                      },
                    ),
                  ],
                ),
              ],
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
      msgCtrl.dispose();
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
                'Achados e Perdidos (${_items.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo Registro'),
                onPressed: _openCreateDialog,
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
                    icon: Icons.search_off_rounded,
                    title: 'Nenhum item registrado',
                    subtitle:
                        'Não há objetos perdidos ou encontrados registrados no momento.',
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final it = _items[idx];
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final isFound = it['type'] == 'FOUND';
                      final status = it['status']?.toString() ?? 'OPEN';
                      final isOpen = status == 'OPEN' || status == 'CLAIMED';
                      return Card(
                        elevation: 0,
                        color: SaaSColors.surface(isDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: SaaSColors.border(isDark)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      isFound ? 'ACHADO' : 'PERDIDO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isFound
                                            ? (isDark
                                                  ? const Color(0xFF34D399)
                                                  : const Color(0xFF15803D))
                                            : (isDark
                                                  ? const Color(0xFFFBBF24)
                                                  : const Color(0xFFB45309)),
                                      ),
                                    ),
                                    backgroundColor:
                                        (isFound
                                                ? SaaSColors.success
                                                : SaaSColors.warning)
                                            .withValues(
                                              alpha: isDark ? 0.20 : 0.14,
                                            ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (it['category'] != null)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        it['category'].toString(),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  const Spacer(),
                                  Text(
                                    status,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                it['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                it['description'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Local: ${it['location'] ?? 'Portaria'} • Publicado por: ${it['reportedByName'] ?? 'Morador'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.forum_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Mensagens (${it['messageCount'] ?? 0})',
                                    ),
                                    onPressed: () => _openMessagesDialog(it),
                                  ),
                                  if (isOpen) ...[
                                    FilledButton.tonalIcon(
                                      icon: const Icon(
                                        Icons.pan_tool_alt_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Reivindicar'),
                                      onPressed: () async {
                                        await widget.api.claimLostFound(
                                          it['id'],
                                        );
                                        _load();
                                      },
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                      ),
                                      label: const Text('Encerrar Publicação'),
                                      onPressed: () async {
                                        await widget.api.closeLostFound(
                                          it['id'],
                                          resolutionNotes:
                                              'Encerrado pelo responsável',
                                        );
                                        _load();
                                      },
                                    ),
                                  ],
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
// 16. RELATÓRIOS E INDICADORES GERENCIAIS (KPIs, PDF e CSV)
// ----------------------------------------------------
class _ReportsSubView extends StatefulWidget {
  const _ReportsSubView({
    required this.api,
    required this.condominiumId,
    this.canManage = false,
  });
  final CommunityApi api;
  final num condominiumId;
  final bool canManage;

  @override
  State<_ReportsSubView> createState() => _ReportsSubViewState();
}

class _ReportsSubViewState extends State<_ReportsSubView> {
  bool _loading = true;
  Map<String, dynamic>? _report;
  String? _error;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (!widget.canManage) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.getDashboardReport(
        widget.condominiumId,
        startDate: _fmtDate(_startDate),
        endDate: _fmtDate(_endDate),
      );
      if (mounted) {
        setState(() {
          _report = res;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _downloadReport({required bool pdf}) async {
    try {
      final startDate = _fmtDate(_startDate);
      final endDate = _fmtDate(_endDate);
      final bytes = pdf
          ? await widget.api.downloadDashboardReportPdf(
              widget.condominiumId,
              startDate: startDate,
              endDate: endDate,
            )
          : await widget.api.downloadDashboardReportCsv(
              widget.condominiumId,
              startDate: startDate,
              endDate: endDate,
            );
      final result = await downloadReportBytes(
        bytes: bytes,
        filename:
            'relatorio-condominio-${widget.condominiumId}.${pdf ? 'pdf' : 'csv'}',
        mimeType: pdf ? 'application/pdf' : 'text/csv;charset=utf-8',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ?? 'Download do relatório iniciado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível baixar o relatório: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canManage) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Os relatórios gerenciais consolidados são exclusivos para o Síndico e Administração.',
          ),
        ),
      );
    }

    if (_error != null && _report == null && !_loading) {
      return SaaSErrorState(
        message: 'Não foi possível carregar os relatórios: $_error',
        onRetry: _load,
      );
    }

    final pkgs = (_report?['packages'] as Map<String, dynamic>?) ?? {};
    final visitors = (_report?['visitors'] as Map<String, dynamic>?) ?? {};
    final tickets = (_report?['tickets'] as Map<String, dynamic>?) ?? {};
    final maint = (_report?['maintenance'] as Map<String, dynamic>?) ?? {};
    final fin = (_report?['financial'] as Map<String, dynamic>?) ?? {};
    final comm = (_report?['community'] as Map<String, dynamic>?) ?? {};
    final areas =
        (_report?['commonAreaUtilization'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    return _loading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: SaaSLoadingState(
                message: 'Carregando métricas e relatórios gerenciais...',
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Indicadores Operacionais & Gerenciais',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_rounded, size: 16),
                        label: Text(
                          'Período: ${_fmtDate(_startDate)} a ${_fmtDate(_endDate)}',
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                            initialDateRange: DateTimeRange(
                              start: _startDate,
                              end: _endDate,
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _startDate = picked.start;
                              _endDate = picked.end;
                            });
                            _load();
                          }
                        },
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.table_view_rounded, size: 16),
                        label: const Text('Baixar Excel (CSV)'),
                        onPressed: () => _downloadReport(pdf: false),
                      ),
                      FilledButton.icon(
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 16,
                        ),
                        label: const Text('Baixar PDF'),
                        onPressed: () => _downloadReport(pdf: true),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statBox(
                    'Encomendas no Período',
                    '${pkgs['total'] ?? 0} (${pkgs['received'] ?? 0} recebidas • ${pkgs['notified'] ?? 0} notificadas)',
                    Icons.inventory_2_outlined,
                    const Color(0xFF2563EB),
                  ),
                  _statBox(
                    'Visitantes & Acessos',
                    '${visitors['total'] ?? 0} (${visitors['checkedIn'] ?? 0} check-in)',
                    Icons.badge_outlined,
                    const Color(0xFF15803D),
                  ),
                  _statBox(
                    'Chamados & Ocorrências',
                    '${tickets['total'] ?? 0} (${tickets['resolved'] ?? 0} resolv.)',
                    Icons.report_problem_outlined,
                    const Color(0xFFD97706),
                  ),
                  _statBox(
                    'Manutenções & O.S.',
                    '${maint['totalOrders'] ?? 0} (${maint['overdueEquipment'] ?? 0} equip. atrasados)',
                    Icons.build_circle_outlined,
                    const Color(0xFF7C3AED),
                  ),
                  _statBox(
                    'Frota & Garagem',
                    '${comm['totalVehicles'] ?? 0} veículos • ${comm['occupiedParkingSpots'] ?? 0}/${comm['totalParkingSpots'] ?? 0} vagas',
                    Icons.directions_car_outlined,
                    const Color(0xFF0F766E),
                  ),
                  _statBox(
                    'Inadimplência Unidades',
                    '${fin['overdueUnits'] ?? 0} unid. em atraso',
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFFDC2626),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Utilização das Áreas Comuns',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              if (areas.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nenhuma reserva registrada para as áreas comuns neste período.',
                    ),
                  ),
                )
              else
                ...areas.map((a) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: SaaSColors.surface(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: SaaSColors.border(isDark)),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.deck_outlined,
                        color: Color(0xFF2563EB),
                      ),
                      title: Text(
                        a['commonAreaName']?.toString() ?? 'Área Comum',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Confirmadas: ${a['confirmedBookings'] ?? 0} • Pendentes: ${a['pendingBookings'] ?? 0} • Lista de Espera: ${a['waitlistedBookings'] ?? 0} • Canceladas: ${a['cancelledBookings'] ?? 0}',
                      ),
                    ),
                  );
                }),
            ],
          );
  }

  Widget _statBox(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaaSColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaaSColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
