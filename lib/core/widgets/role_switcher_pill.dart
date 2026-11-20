import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    switch (role.trim().toUpperCase()) {
      case 'ROLE_ADMIN':
      case 'ADMIN':
        return 'Administrador';
      case 'ROLE_MANAGER':
      case 'MANAGER':
        return 'Síndico / Gestor';
      case 'ROLE_DOORMAN':
      case 'DOORMAN':
      case 'ROLE_CONCIERGE':
      case 'CONCIERGE':
        return 'Portaria';
      default:
        return 'Morador';
    }
  }

  static IconData roleIcon(String role) {
    switch (role.trim().toUpperCase()) {
      case 'ROLE_ADMIN':
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'ROLE_MANAGER':
      case 'MANAGER':
        return Icons.manage_accounts_rounded;
      case 'ROLE_DOORMAN':
      case 'DOORMAN':
      case 'ROLE_CONCIERGE':
      case 'CONCIERGE':
        return Icons.security_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (availableRoles.length <= 1) return const SizedBox.shrink();

    final tokens = AncoraThemeTokens.of(context);
    final Color textColor = isLight
        ? (tokens.isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A))
        : Colors.white;
    final Color bgColor = isLight
        ? (tokens.isDark
              ? tokens.accent.withValues(alpha: 0.2)
              : const Color(0xFFEFF6FF))
        : Colors.white.withValues(alpha: 0.16);
    final Color borderColor = isLight
        ? (tokens.isDark
              ? tokens.accent.withValues(alpha: 0.45)
              : const Color(0xFFBFDBFE))
        : Colors.white.withValues(alpha: 0.32);

    return PopupMenuButton<String>(
      tooltip: 'Alternar perfil de visualização',
      onSelected: onSwitchRole,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.borderStrong),
      ),
      color: tokens.surfaceElevated,
      itemBuilder: (ctx) => availableRoles.map((role) {
        final isSelected = role == currentRole;
        return PopupMenuItem<String>(
          value: role,
          child: Row(
            children: [
              Icon(
                roleIcon(role),
                size: 18,
                color: isSelected ? tokens.accent : tokens.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  roleLabel(role),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? tokens.accent : tokens.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 16, color: tokens.accent),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roleIcon(currentRole), size: 15, color: textColor),
            const SizedBox(width: 6),
            Text(
              roleLabel(currentRole),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textColor),
          ],
        ),
      ),
    );
  }
}
