part of 'home_page.dart';

extension _HomeResidentDialogsExtension on _HomePageState {
  Future<void> _openAssistantModal() async {
    final condoId =
        _condominium?['id'] as num? ??
        (_memberships.isNotEmpty
            ? _memberships.first['condominiumId'] as num?
            : null);
    if (condoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione ou vincule-se a um condomínio para usar o Assistente.',
          ),
        ),
      );
      return;
    }
    if (!_hasFeature('AI_ASSISTANT')) {
      SaaSFeedback.showWarning(
        context,
        'O Assistente IA é exclusivo do plano Enterprise ou assinatura ativa.',
      );
      return;
    }
    await CondoAssistantSheet.show(
      context,
      api: _api,
      condominiumId: condoId,
      condominiumName: _condominium?['name']?.toString() ?? 'Condomínio',
    );
  }

  Future<void> _showNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          api: _api,
          condominiumId: (_condominium?['id'] as num?)?.toInt(),
          onInvitationChanged: _load,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _showMoreMenus() async {
    final entries = <(String, String, IconData, String)>[
      (
        'Áreas Comuns',
        'common-areas',
        Icons.deck_outlined,
        'Espaços de lazer e agendamentos',
      ),
      (
        'Galeria de Fotos',
        'gallery',
        Icons.photo_library_outlined,
        'Fotos das áreas do condomínio',
      ),
      (
        'Chat com a Portaria',
        'chat',
        Icons.chat_bubble_outline_rounded,
        'Conversa em tempo real com a portaria',
      ),
      (
        'Planos e Serviços',
        'plans',
        Icons.receipt_long_outlined,
        'Planos e recursos do condomínio',
      ),
    ];

    final selected =
        await showModalBottomSheet<(String, String, IconData, String)>(
          context: context,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(
                    title: Text(
                      'Serviços do Condomínio',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text('Selecione uma área para navegar'),
                  ),
                  const Divider(height: 1),
                  ...entries.map(
                    (entry) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE8ECFF),
                        child: Icon(entry.$3, color: const Color(0xFF2F3FB0)),
                      ),
                      title: Text(
                        entry.$1,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(entry.$4),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, entry),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    if (selected == null || !mounted) return;
    if (selected.$2 == 'common-areas') {
      _mutate(() => _tab = 2);
    } else if (selected.$2 == 'gallery') {
      _mutate(() => _tab = 5);
    } else if (selected.$2 == 'chat') {
      _mutate(() => _tab = 3);
    } else if (selected.$2 == 'plans') {
      await _showPlansInfoDialog();
    }
  }

  Future<void> _showPlansInfoDialog() async {
    List<Map<String, dynamic>> plans = const [];
    String? error;
    try {
      final res = await _api.get('/billing/plans');
      if (res is List) {
        plans = res.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    final activePlan =
        _condominium?['billingPlanName']?.toString() ?? 'Não informado';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Planos e Recursos'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plano atual do condomínio: $activePlan',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text('Não foi possível carregar os planos: $error')
                else if (plans.isEmpty)
                  const Text('Nenhum plano disponível encontrado.')
                else
                  ...plans.map((p) {
                    final name = p['name']?.toString() ?? 'Plano';
                    final fee = p['monthlyFee'];
                    final isCurrent =
                        name.toLowerCase() == activePlan.toLowerCase();
                    final features = p['features'] is List
                        ? (p['features'] as List).join(', ')
                        : '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCurrent
                            ? Icons.check_circle_rounded
                            : Icons.layers_outlined,
                        color: isCurrent ? const Color(0xFF15803D) : null,
                      ),
                      title: Text(
                        '$name${fee != null ? ' • R\$ $fee/mês' : ''}',
                      ),
                      subtitle: features.isNotEmpty ? Text(features) : null,
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createReservation() async {
    if (_condominium == null) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => CommonAreaBookingDialog(
        api: _communityApi,
        condominiumId: _condominium!['id'],
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openJoinCondominiumDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => JoinCondominiumDialog(api: _communityApi),
    );
    if (sent == true) _load();
  }

  Future<void> _openPaymentDialog() async {
    if (_condominium == null) return;
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma fatura ou boleto registrado para a sua unidade no momento.',
          ),
        ),
      );
      return;
    }
    final selected = await showAncoraDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Histórico de boletos e pagamentos'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _invoices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final invoice = _invoices[index];
              final status =
                  invoice['status']?.toString().toUpperCase() ?? 'PENDING';
              final paid = status == 'PAID' || status == 'UP_TO_DATE';
              final amount = (invoice['amount'] as num?)?.toDouble();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  paid
                      ? Icons.check_circle_outline_rounded
                      : Icons.receipt_long_outlined,
                  color: paid
                      ? const Color(0xFF15803D)
                      : const Color(0xFF2563EB),
                ),
                title: Text(
                  invoice['invoiceTitle']?.toString() ?? 'Taxa condominial',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Vencimento: ${_formatDate(invoice['dueDate'])} • ${paid ? 'Paga' : 'Em aberto'}',
                ),
                trailing: Text(formatCurrencyBrl(amount)),
                onTap: () => Navigator.of(dialogContext).pop(index),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    if (!mounted ||
        selected == null ||
        selected < 0 ||
        selected >= _invoices.length) {
      return;
    }
    await _paySingleBoleto(_invoices[selected]);
  }

  Future<void> _openExpectedPackageDialog() async {
    if (_condominium == null) return;
    final desc = TextEditingController();
    final tracking = TextEditingController();
    final sender = TextEditingController();

    final unitId = (_activeMembership?['unitId'] as num?)?.toInt();
    if (unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sua conta precisa estar vinculada a uma unidade para pré-cadastrar encomenda.',
          ),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avisar Encomenda Prevista'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cadastre o pacote para a portaria já saber de quem se trata na entrega.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                decoration: const InputDecoration(
                  labelText: 'Descrição do pacote *',
                  hintText: 'Ex: Livros da Amazon',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tracking,
                decoration: const InputDecoration(
                  labelText: 'Código de rastreio (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sender,
                decoration: const InputDecoration(
                  labelText: 'Remetente / Transportadora',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar Aviso'),
          ),
        ],
      ),
    );

    final descText = desc.text.trim();
    final trackingText = tracking.text.trim();
    final senderText = sender.text.trim();
    desc.dispose();
    tracking.dispose();
    sender.dispose();

    if (ok == true && descText.isNotEmpty) {
      await _communityApi.registerExpectedPackage(
        condoId: _condominium!['id'],
        unitId: unitId,
        description: descText,
        trackingCode: trackingText.isEmpty ? null : trackingText,
        sender: senderText.isEmpty ? null : senderText,
      );
      _load();
    }
  }

  Future<void> _requestPickup(num packageId) async {
    try {
      await _communityApi.requestPackagePickup(packageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Portaria avisada que você está a caminho para retirar a encomenda!',
            ),
          ),
        );
      }
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

class _LazyIndexedTab extends StatefulWidget {
  const _LazyIndexedTab({
    super.key,
    required this.isActive,
    required this.builder,
  });

  final bool isActive;
  final WidgetBuilder builder;

  @override
  State<_LazyIndexedTab> createState() => _LazyIndexedTabState();
}

class _LazyIndexedTabState extends State<_LazyIndexedTab> {
  bool _hasBeenOpened = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isActive) _hasBeenOpened = true;
    if (!_hasBeenOpened) return const SizedBox.shrink();
    return TickerMode(enabled: widget.isActive, child: widget.builder(context));
  }
}
