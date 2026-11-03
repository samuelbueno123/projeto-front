import 'package:flutter/material.dart';

/// Modern SaaS Header for Resident overview
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onLogout,
    this.userName,
    this.userEmail,
    this.condoName,
    this.unitLabel,
    this.unreadNotifications = 0,
    this.onOpenNotifications,
    this.onOpenProfile,
  });

  final Future<void> Function() onLogout;
  final String? userName;
  final String? userEmail;
  final String? condoName;
  final String? unitLabel;
  final int unreadNotifications;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = userName?.trim().isNotEmpty == true
        ? userName!.trim()
        : 'morador';
    final email = userEmail?.trim().isNotEmpty == true
        ? userEmail!.trim()
        : 'Bem-vindo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1D4ED8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Greeting & Condo context
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Olá, $name! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unitLabel != null && unitLabel!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            unitLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (condoName != null && condoName!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• $condoName',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action icons
            if (onOpenNotifications != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    tooltip: 'Notificações',
                    onPressed: onOpenNotifications,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],

            if (onOpenProfile != null) ...[
              IconButton(
                tooltip: 'Meu Perfil',
                onPressed: onOpenProfile,
                icon: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 4),
            ],

            IconButton(
              tooltip: 'Sair',
              onPressed: onLogout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
