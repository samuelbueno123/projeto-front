import 'package:flutter/material.dart';

class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 86,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _NavItem(icon: Icons.home_rounded, label: 'Início', selected: true),
            _NavItem(icon: Icons.qr_code_2_rounded, label: 'Acesso'),
            _CenterAction(),
            _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Mensagens'),
            _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF3E4CDF) : const Color(0xFF656B84);
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        ],
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF3E4CDF),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: const Color(0xFF3E4CDF).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: const Icon(Icons.grid_view_rounded, color: Colors.white),
    );
  }
}
