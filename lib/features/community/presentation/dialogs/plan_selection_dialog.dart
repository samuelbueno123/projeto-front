import 'package:flutter/material.dart';
import '../../../../core/design_system/motion_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/community_api.dart';

class PlanSelectionDialog extends StatefulWidget {
  const PlanSelectionDialog({
    super.key,
    required this.condominiumId,
    required this.condominiumName,
    required this.api,
    required this.onPlanSelected,
  });

  final num condominiumId;
  final String condominiumName;
  final CommunityApi api;
  final VoidCallback onPlanSelected;

  @override
  State<PlanSelectionDialog> createState() => _PlanSelectionDialogState();
}

class _PlanSelectionDialogState extends State<PlanSelectionDialog> {
  num? _selectedPlan;
  bool _submitting = false;
  bool _loadingPlans = true;
  List<Map<String, dynamic>> _plans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    try {
      final plans = await widget.api.getBillingPlans();
      if (!mounted) return;
      final activePlans = plans
          .where((plan) => plan['active'] != false)
          .toList();
      setState(() {
        _plans = activePlans;
        _selectedPlan = activePlans.isEmpty
            ? null
            : _number(activePlans.first['id']);
        _loadingPlans = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPlans = false;
        _error = 'Não foi possível carregar os planos: $error';
      });
    }
  }

  num? _number(dynamic value) => value is num ? value : num.tryParse('$value');

  List<String> _featureLabels(dynamic raw) {
    if (raw is! Iterable) return const [];
    return raw
        .map((feature) => feature.toString().trim())
        .where((feature) => feature.isNotEmpty)
        .map(
          (feature) => feature
              .replaceAll('_', ' ')
              .toLowerCase()
              .split(' ')
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' '),
        )
        .toList();
  }

  Map<String, dynamic>? get _selectedPlanData {
    for (final plan in _plans) {
      if (_number(plan['id']) == _selectedPlan) return plan;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONFIGURAÇÃO INICIAL DO SÍNDICO',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Text(
                                'Escolha o plano para ${widget.condominiumName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecione o plano ideal para gerenciar seu condomínio. Você poderá alterar o plano a qualquer momento pelo painel.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFEE2E2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                    ),
                  ),
                ),

              // Plans loaded from the billing API
              Expanded(
                child: _loadingPlans
                    ? const Center(child: CircularProgressIndicator())
                    : _plans.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error ?? 'Nenhum plano ativo está disponível.',
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadPlans,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 650;
                          final colors = <Color>[
                            const Color(0xFF0F766E),
                            const Color(0xFF2563EB),
                            const Color(0xFF7E22CE),
                            const Color(0xFFD97706),
                          ];
                          final cards = <Widget>[];
                          for (final plan in _plans) {
                            final id = _number(plan['id']);
                            if (id == null) continue;
                            final fee = _number(plan['monthlyFee']);
                            final rawName = plan['name']?.toString().trim();
                            cards.add(
                              _buildPlanCard(
                                id: id,
                                name: rawName?.isNotEmpty == true
                                    ? rawName!
                                    : 'Plano',
                                price: formatCurrencyBrl(fee),
                                badge: 'Ativo',
                                color: colors[cards.length % colors.length],
                                features: _featureLabels(plan['features']),
                                constrainFeatureList: isWide,
                              ),
                            );
                          }
                          if (cards.isEmpty) {
                            return const Center(
                              child: Text(
                                'Os planos recebidos não têm identificadores válidos.',
                              ),
                            );
                          }
                          if (isWide) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: cards
                                    .map(
                                      (card) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: card,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: cards.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (_, index) => cards[index],
                          );
                        },
                      ),
              ),
              // Bottom Confirmation
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final plan = _selectedPlanData;
                    final selectionLabel = plan == null
                        ? 'Selecione um plano disponível'
                        : 'Plano selecionado: ${plan['name'] ?? 'Plano'} • ${formatCurrencyBrl(_number(plan['monthlyFee']))}/mês';
                    final confirmButton = FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _submitting || plan == null
                          ? null
                          : _confirmSelection,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Confirmar Plano',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    );
                    if (constraints.maxWidth < 540) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            selectionLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: confirmButton,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectionLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        confirmButton,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required num id,
    required String name,
    required String price,
    required String badge,
    required Color color,
    required List<String> features,
    bool constrainFeatureList = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedPlan == id;

    return InkWell(
      onTap: () => setState(() => _selectedPlan = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: AncoraMotion.duration(context),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? color.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.06))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Radio<num>(
                  value: id,
                  groupValue: _selectedPlan,
                  activeColor: color,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPlan = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    price,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '/mês',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (features.isEmpty)
              Text(
                'Recursos não informados',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF334155),
                ),
              )
            else if (constrainFeatureList)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: features
                        .map(
                          (feature) => _buildFeatureItem(
                            feature,
                            color: color,
                            isDark: isDark,
                          ),
                        )
                        .toList(),
                  ),
                ),
              )
            else
              ...features.map(
                (feature) =>
                    _buildFeatureItem(feature, color: color, isDark: isDark),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    String feature, {
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSelection() async {
    final planId = _selectedPlan;
    if (planId == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.selectCondominiumPlan(widget.condominiumId, planId);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onPlanSelected();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Erro ao selecionar plano: $e';
      });
    }
  }
}
