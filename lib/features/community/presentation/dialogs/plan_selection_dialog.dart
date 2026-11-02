import 'package:flutter/material.dart';
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
  num _selectedPlan = 2; // Default to Profissional
  bool _submitting = false;
  String? _error;

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
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
                          child: const Icon(Icons.stars_rounded, color: Colors.white, size: 26),
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
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),

              if (_error != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFEE2E2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                  ),
                ),

              // Plans cards
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 650;
                    final plans = [
                      _buildPlanCard(
                        id: 1,
                        name: 'Básico',
                        price: 'R\$ 199,90',
                        badge: 'Essencial',
                        color: const Color(0xFF0F766E),
                        features: [
                          'Gestão de Unidades e Moradores',
                          'Comunicados e Mural Oficial',
                          'Controle de Portaria & Acesso',
                          'Reservas Simples de Espaços',
                        ],
                      ),
                      _buildPlanCard(
                        id: 2,
                        name: 'Profissional',
                        price: 'R\$ 349,90',
                        badge: 'Mais Popular',
                        color: const Color(0xFF2563EB),
                        isPopular: true,
                        features: [
                          'Tudo do Plano Básico',
                          'Chat Portaria em Tempo Real',
                          'Enquetes e Votações Digitais',
                          'Boletos com Código e Baixa Fácil',
                          'Galeria de Fotos das Instalações',
                        ],
                      ),
                      _buildPlanCard(
                        id: 3,
                        name: 'Premium',
                        price: 'R\$ 499,90',
                        badge: 'Completo',
                        color: const Color(0xFF7E22CE),
                        features: [
                          'Tudo do Plano Profissional',
                          'Armários Inteligentes (Lockers)',
                          'Classificados e Achados & Perdidos',
                          'Controle de Garagem & Placas',
                          'Gestão de Infrações e Defesas',
                          'Documentos e Atas Digitais',
                        ],
                      ),
                    ];

                    if (isWide) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: plans.map((p) => Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: p,
                          ))).toList(),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: plans.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: p,
                      )).toList(),
                    );
                  },
                ),
              ),

              // Bottom Confirmation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedPlan == 1
                            ? 'Plano selecionado: Básico (R\$ 199,90/mês)'
                            : _selectedPlan == 2
                            ? 'Plano selecionado: Profissional (R\$ 349,90/mês)'
                            : 'Plano selecionado: Premium (R\$ 499,90/mês)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submitting ? null : _confirmSelection,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Confirmar Plano',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
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
    bool isPopular = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedPlan == id;

    return InkWell(
      onTap: () => setState(() => _selectedPlan = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.06))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
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
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSelection() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.selectCondominiumPlan(widget.condominiumId, _selectedPlan);
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
