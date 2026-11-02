import 'package:flutter/material.dart';

class RoleSwitcherPill extends StatelessWidget {
  const RoleSwitcherPill({
    super.key,
    required this.currentRole,
    required this.availableRoles,
    required this.onSwitchRole,
    this.isLight = false,
  });

  final String currentRole;
  final List<String> availableRoles;
  final ValueChanged<String> onSwitchRole;
  final bool isLight;

  static String roleLabel(String role) {
    switch (role) {
      case 'ADMIN':
        return 'Administrador';
      case 'MANAGER':
        return 'Síndico / Gestor';
      case 'DOORMAN':
        return 'Portaria';
      case 'RESIDENT':
      default:
        return 'Morador';
    }
  }

  static IconData roleIcon(String role) {
    switch (role) {
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'MANAGER':
        return Icons.business_center_rounded;
      case 'DOORMAN':
        return Icons.shield_rounded;
      case 'RESIDENT':
      default:
        return Icons.home_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (availableRoles.length <= 1) return const SizedBox.shrink();

    final textColor = isLight ? const Color(0xFF1E3A8A) : Colors.white;
    final bgColor = isLight ? const Color(0xFFEFF6FF) : Colors.white.withValues(alpha: 0.15);
    final borderColor = isLight ? const Color(0xFFBFDBFE) : Colors.white.withValues(alpha: 0.3);

    return PopupMenuButton<String>(
      tooltip: 'Alternar perfil de visualização',
      initialValue: currentRole,
      onSelected: onSwitchRole,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roleIcon(currentRole), size: 15, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                roleLabel(currentRole),
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: textColor),
          ],
        ),
      ),
      itemBuilder: (ctx) => availableRoles.map((role) {
        final isSelected = role == currentRole;
        return PopupMenuItem<String>(
          value: role,
          child: Row(
            children: [
              Icon(
                roleIcon(role),
                size: 18,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  roleLabel(role),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF2563EB) : null,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_rounded, size: 18, color: Color(0xFF2563EB)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
