import 'package:flutter/material.dart';

/// Header legado mantido para compatibilidade com consumidores existentes.
/// A tela ativa do app monta o cabeçalho conectado aos dados em HomePage.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onLogout,
    this.userName,
    this.userEmail,
  });

  final Future<void> Function() onLogout;
  final String? userName;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim().isNotEmpty == true
        ? userName!.trim()
        : 'morador';
    final email = userEmail?.trim().isNotEmpty == true
        ? userEmail!.trim()
        : 'Bem-vindo';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF2F3FB0),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, $name! 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(email, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sair',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
