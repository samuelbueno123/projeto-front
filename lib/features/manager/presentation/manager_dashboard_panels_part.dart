part of 'manager_page.dart';

extension _ManagerDashboardPanelsExtension on _ManagerPageState {
  Widget _buildCondominiumCoverBanner(bool isDark) {
    final condoName = _selectedCondoName();
    final rawImageUrl = _condoDetails?['imageUrl'] as String?;
    final imageProvider =
        resolveAvatarImageProvider(rawImageUrl) ??
        const AssetImage(AppAssets.condoCoverDefault);
    final firstName = firstNameOf(widget.userName, fallback: 'Síndico');
    final openTickets = _intStat(
      'openTicketsCount',
      _tickets
          .where((t) => t['status'] == 'OPEN' || t['status'] == 'IN_PROGRESS')
          .length,
    );
    final overdueMaint = _intStat('overdueMaintenanceCount');
    final opHealthy = openTickets == 0 && overdueMaint == 0;

    final bannerContent = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$condoName • Olá, $firstName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (opHealthy
                                    ? SaaSColors.success
                                    : SaaSColors.warning)
                                .withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: (opHealthy
                                      ? SaaSColors.success
                                      : SaaSColors.warning)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                opHealthy
                                    ? Icons.verified_rounded
                                    : Icons.engineering_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                opHealthy
                                    ? 'Operação Normal'
                                    : '${openTickets + overdueMaint} pendência(s)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Painel Executivo do Síndico • Gestão integrada de unidades, finanças e operação',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_condos.length > 1) ...[
                const SizedBox(width: 12),
                Container(
                  constraints: const BoxConstraints(maxWidth: 230),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selected,
                      dropdownColor: const Color(0xFF0F1424),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      isDense: true,
                      items: _condos
                          .map(
                            (m) => DropdownMenuItem<int>(
                              value: (m['condominiumId'] as num).toInt(),
                              child: Text(
                                m['condominiumName']?.toString() ?? 'Condomínio',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        _mutate(() => _selected = value);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              if (rawImageUrl != null && rawImageUrl.isNotEmpty)
                IconButton(
                  tooltip: 'Ampliar fachada',
                  onPressed: () => showFullScreenImage(
                    context,
                    imageSource: rawImageUrl,
                    title: condoName,
                  ),
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                ),
              IconButton(
                tooltip: 'Alterar foto da fachada',
                onPressed: _changeCondominiumImage,
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _bannerActionButton(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Convidar Morador',
                  primary: true,
                  onTap: _openMemberships,
                ),
                const SizedBox(width: 8),
                _bannerActionButton(
                  icon: Icons.campaign_rounded,
                  label: 'Emitir Comunicado',
                  onTap: _sendAnnouncement,
                ),
                if (_hasFeature('ASSEMBLIES')) ...[
                  const SizedBox(width: 8),
                  _bannerActionButton(
                    icon: Icons.how_to_vote_outlined,
                    label: 'Assembleia Virtual',
                    onTap: () => _openCommunityHub(initialIndex: 12),
                  ),
                ],
                if (_hasFeature('MAINTENANCE')) ...[
                  const SizedBox(width: 8),
                  _bannerActionButton(
                    icon: Icons.build_circle_outlined,
                    label: 'Nova Manutenção',
                    onTap: _openNewMaintenanceDialog,
                  ),
                ],
                if (_hasFeature('FINANCIAL')) ...[
                  const SizedBox(width: 8),
                  _bannerActionButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Gerar Boleto',
                    onTap: _generateBoleto,
                  ),
                ],
                const SizedBox(width: 8),
                _bannerActionButton(
                  icon: Icons.mark_email_read_outlined,
                  label: 'Leituras',
                  onTap: _openAnnouncementsReceiptsDialog,
                ),
                const SizedBox(width: 8),
                _bannerActionButton(
                  icon: Icons.workspace_premium_outlined,
                  label: _subAccess.planName != null
                      ? 'Plano ${_subAccess.planName}'
                      : 'Gerenciar Plano',
                  onTap: _openPlanManagerDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0F1424),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFF1E3A8A).withValues(alpha: 0.25),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF080B14).withValues(alpha: 0.80),
                const Color(0xFF0F1424).withValues(alpha: 0.88),
              ],
            ),
          ),
          child: !isRunningTestEnvironment
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: bannerContent,
                )
              : bannerContent,
        ),
      ),
    );
  }

  Widget _bannerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: primary
            ? SaaSColors.primary
            : Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: primary
              ? BorderSide.none
              : BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildManagerMetricsGrid() {
    final totalUnits = (_dashboard?['totalUnits'] as num?)?.toInt() ?? 0;
    final occupiedUnits = _intStat('occupiedUnits');
    final vacantUnits = _intStat('vacantUnits', (totalUnits - occupiedUnits).clamp(0, totalUnits));
    final totalUsers = (_dashboard?['totalUsers'] as num?)?.toInt() ?? 0;
    final recentMembers = _intStat('recentMembershipsCount');
    final pendingReq = _intStat('pendingMembershipRequestsCount');
    final activeRes = _intStat(
      'activeReservationsCount',
      (_dashboard?['totalReservations'] as num?)?.toInt() ?? 0,
    );
    final todayRes = _intStat('todayReservationsCount');
    final weekRes = _intStat('weekReservationsCount');

    final unitTrend = totalUnits > 0
        ? '${((occupiedUnits / totalUnits) * 100).round()}% ocupação'
        : 'Sem unidades';
    final memberTrend = recentMembers > 0 ? '+$recentMembers esta semana' : null;

    return SaaSMetricGrid(
      items: [
        SaaSMetricCard(
          title: 'Unidades Cadastradas',
          value: '$totalUnits',
          icon: Icons.home_work_outlined,
          iconColor: SaaSColors.primary,
          trend: unitTrend,
          subtitle: '$occupiedUnits ocupadas • $vacantUnits vagas',
          onTap: _openUnitsMenu,
        ),
        SaaSMetricCard(
          title: 'Moradores & Vínculos',
          value: '$totalUsers',
          icon: Icons.groups_outlined,
          iconColor: SaaSColors.success,
          trend: memberTrend,
          subtitle: pendingReq > 0
              ? '$pendingReq solicitação(ões) pendente(s)'
              : 'Vínculos ativos no condomínio',
          onTap: _openMemberships,
        ),
        SaaSMetricCard(
          title: 'Reservas Ativas',
          value: '$activeRes',
          icon: Icons.event_available_outlined,
          iconColor: SaaSColors.warning,
          subtitle: '$todayRes hoje • $weekRes nos próximos 7 dias',
          onTap: _openReservationsMenu,
        ),
        SaaSMetricCard(
          title: 'Assistente IA',
          value: _hasFeature('AI_ASSISTANT')
              ? 'Ativo & Monitorando'
              : 'Plano Enterprise',
          icon: _hasFeature('AI_ASSISTANT')
              ? Icons.auto_awesome_rounded
              : Icons.lock_outline_rounded,
          iconColor: _hasFeature('AI_ASSISTANT')
              ? SaaSColors.purple
              : SaaSColors.warning,
          subtitle: _hasFeature('AI_ASSISTANT')
              ? _buildAiMonitorSummary()
              : 'Disponível no plano Enterprise ou assinatura ativa',
          onTap: _openCondoAssistant,
        ),
      ],
    );
  }

  Widget _buildFinancialPanel(bool isDark, {bool shrinkWrap = false}) {
    final units = _dashboardRecords('units');
    final summaryCollected = _doubleStat('totalCollected');
    final summaryPending = _doubleStat('totalPending');
    final summaryOverdue = _doubleStat('overdueAmount');
    final finCollected = _financialSummary['totalCollected'] is num
        ? (_financialSummary['totalCollected'] as num).toDouble()
        : summaryCollected;
    final paidCount = _intStat(
      'paidUnitsCount',
      units.where((u) => u['paymentStatus'] == 'PAID').length,
    );
    final pendingCount = _intStat(
      'pendingUnitsCount',
      units
          .where(
            (u) =>
                u['paymentStatus'] == 'PENDING' ||
                u['paymentStatus'] == 'CONFIRMATION_REQUESTED',
          )
          .length,
    );
    final overdueCount = _intStat(
      'overdueUnitsCount',
      units.where((u) => u['paymentStatus'] == 'OVERDUE').length,
    );
    final computedPending = summaryPending > 0
        ? (summaryPending - summaryOverdue).clamp(0.0, double.infinity)
        : 0.0;

    final listContent = units.isEmpty
        ? const SaaSEmptyState(
            icon: Icons.home_work_outlined,
            title: 'Nenhuma unidade encontrada',
            description: 'Verifique o filtro de busca ou cadastre unidades.',
          )
        : ListView.separated(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final unit = units[index];
              final status = unit['paymentStatus']?.toString();
              final (label, _, _) = _statusStyle(status);
              final badgeVariant = switch (status) {
                'PAID' => SaaSBadgeVariant.success,
                'OVERDUE' => SaaSBadgeVariant.error,
                'PENDING' || 'CONFIRMATION_REQUESTED' => SaaSBadgeVariant.warning,
                _ => SaaSBadgeVariant.neutral,
              };
              final amountStr = unit['amount'] == null
                  ? ''
                  : ' • R\$ ${unit['amount']}';
              final dueStr = unit['dueDate'] == null
                  ? ''
                  : ' • Venc: ${_formatDate(unit['dueDate'])}';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: SaaSColors.surfaceSubtle(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : SaaSColors.border(isDark),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${unit['sector']} • Unidade ${unit['identifier']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SaaSBadge(label: label, variant: badgeVariant),
                              if (amountStr.isNotEmpty || dueStr.isNotEmpty)
                                Text(
                                  '$amountStr$dueStr'.replaceFirst(' • ', ''),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SaaSColors.textSecondary(isDark),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _editPayment(unit),
                      icon: const Icon(Icons.payments_outlined, size: 15),
                      label: Text(
                        status == 'PENDING' || status == 'OVERDUE'
                            ? 'Cobrar / Atualizar'
                            : 'Atualizar',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );

    return SaaSGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaaSSectionHeader(
            title: 'Área Financeira',
            subtitle: 'Arrecadação, inadimplência e cobranças por unidade',
            action: FilledButton.icon(
              onPressed: _generateBoleto,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('+ Novo Boleto'),
              style: FilledButton.styleFrom(
                backgroundColor: SaaSColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
            ),
          ),
          SaaSFinancialMiniChart(
            collected: finCollected,
            pending: computedPending,
            overdue: summaryOverdue,
            paidCount: paidCount,
            pendingCount: pendingCount,
            overdueCount: overdueCount,
          ),
          if (shrinkWrap && paidCount + pendingCount + overdueCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: AncoraDonutChart(
                centerLabel: 'Unidades',
                centerValue: '${paidCount + pendingCount + overdueCount}',
                slices: [
                  AncoraDonutSlice(
                    label: 'Pagas',
                    value: paidCount.toDouble(),
                    color: AncoraChartPalette.emerald,
                  ),
                  AncoraDonutSlice(
                    label: 'Pendentes',
                    value: pendingCount.toDouble(),
                    color: AncoraChartPalette.amber,
                  ),
                  AncoraDonutSlice(
                    label: 'Inadimplentes',
                    value: overdueCount.toDouble(),
                    color: AncoraChartPalette.rose,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          EnterSearchField(
            hintText: 'Pesquisar unidades, blocos ou status (Enter)',
            onSubmitted: (query) => _mutate(() => _query = query),
          ),
          const SizedBox(height: 12),
          if (shrinkWrap) listContent else Expanded(child: listContent),
        ],
      ),
    );
  }

  Widget _buildReservationsPanel(bool isDark, {bool shrinkWrap = false}) {
    final reservations = _dashboardRecords('reservations');
    final listContent = reservations.isEmpty
        ? const SaaSEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nenhum agendamento encontrado',
            description:
                'Não há solicitações de áreas comuns registradas no momento.',
          )
        : ListView.separated(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
            itemCount: reservations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = reservations[index];
              final status = (r['status']?.toString() ?? '').toUpperCase();
              final isPending = status == 'PENDING';
              final badgeVariant = switch (status) {
                'CONFIRMED' || 'APPROVED' => SaaSBadgeVariant.success,
                'PENDING' || 'COUNTER_PROPOSED' => SaaSBadgeVariant.warning,
                'CANCELLED' || 'REJECTED' => SaaSBadgeVariant.error,
                _ => SaaSBadgeVariant.neutral,
              };
              final statusLabel = switch (status) {
                'CONFIRMED' || 'APPROVED' => 'Confirmado',
                'PENDING' => 'Em Análise',
                'COUNTER_PROPOSED' => 'Contraproposta',
                'CANCELLED' => 'Cancelado',
                'REJECTED' => 'Recusado',
                _ => _translateStatus(status),
              };
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SaaSColors.surfaceSubtle(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : SaaSColors.border(isDark),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${r['commonArea']} • ${r['residentName']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SaaSBadge(label: statusLabel, variant: badgeVariant),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDateTime(r['startAt'])} até ${_formatDateTime(r['endAt'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: SaaSColors.textSecondary(isDark),
                      ),
                    ),
                    if (isPending && r['id'] is num) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _quickApproveReservation(r['id'] as num),
                            icon: const Icon(Icons.check_rounded, size: 15),
                            label: const Text('Aprovar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _quickRejectReservation(r['id'] as num),
                            icon: const Icon(Icons.close_rounded, size: 15),
                            label: const Text('Recusar'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );

    return SaaSGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaaSSectionHeader(
            title: 'Agendamento de Áreas Comuns',
            badge: SaaSBadge(
              label: '${reservations.length}',
              variant: SaaSBadgeVariant.warning,
            ),
            action: OutlinedButton.icon(
              onPressed: _openReservationsMenu,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Ver todas'),
            ),
          ),
          if (shrinkWrap) listContent else Expanded(child: listContent),
        ],
      ),
    );
  }

  Widget _buildOperationalFeedPanel(bool isDark, {bool shrinkWrap = false}) {
    final openTickets = _tickets
        .where((t) => t['status'] == 'OPEN' || t['status'] == 'IN_PROGRESS')
        .toList();
    final openOrders = _maintenanceOrders
        .where((o) => o['status'] == 'OPEN' || o['status'] == 'IN_PROGRESS')
        .toList();
    final items = <Map<String, dynamic>>[
      ...openOrders.map(
        (o) => {
          'kind': 'MAINTENANCE',
          'title': o['title']?.toString() ?? 'Manutenção',
          'subtitle': '${o['category'] ?? 'Geral'} • ${o['priority'] ?? 'MEDIUM'}',
          'status': o['status']?.toString() ?? 'OPEN',
        },
      ),
      ...openTickets.map(
        (t) => {
          'kind': 'TICKET',
          'title': t['title']?.toString() ?? 'Chamado',
          'subtitle': '${t['authorName'] ?? 'Morador'} • ${t['location'] ?? t['category'] ?? 'Geral'}',
          'status': t['status']?.toString() ?? 'OPEN',
        },
      ),
    ];

    final content = items.isEmpty
        ? SaaSEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Sem chamados ou manutenções abertas',
            subtitle: 'Todos os chamados operacionais do condomínio estão em dia.',
            actionLabel: _hasFeature('MAINTENANCE') ? 'Nova Manutenção' : null,
            onAction: _hasFeature('MAINTENANCE') ? _openNewMaintenanceDialog : null,
          )
        : ListView.separated(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, idx) {
              final item = items[idx];
              final isMaint = item['kind'] == 'MAINTENANCE';
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openCommunityHub(initialIndex: isMaint ? 11 : 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SaaSColors.surfaceSubtle(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : SaaSColors.border(isDark),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isMaint ? SaaSColors.warning : SaaSColors.error)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isMaint
                              ? Icons.build_circle_outlined
                              : Icons.report_problem_outlined,
                          size: 18,
                          color: isMaint ? SaaSColors.warning : SaaSColors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              item['subtitle'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: SaaSColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SaaSBadge(
                        label: item['status'] == 'IN_PROGRESS'
                            ? 'Em andamento'
                            : 'Aberto',
                        variant: item['status'] == 'IN_PROGRESS'
                            ? SaaSBadgeVariant.primary
                            : SaaSBadgeVariant.warning,
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return SaaSGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaaSSectionHeader(
            title: 'Chamados & Ocorrências',
            badge: SaaSBadge(
              label: '${items.length}',
              variant: items.isEmpty
                  ? SaaSBadgeVariant.success
                  : SaaSBadgeVariant.error,
            ),
            action: OutlinedButton.icon(
              onPressed: () => _openCommunityHub(initialIndex: 0),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Hub'),
            ),
          ),
          if (shrinkWrap) content else Expanded(child: content),
        ],
      ),
    );
  }

}
