import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF2F3FB0),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(38),
          bottomRight: Radius.circular(38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none, color: Colors.white, size: 30),
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      height: 20,
                      width: 20,
                      decoration: const BoxDecoration(color: Color(0xFFFF4D67), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text(
                        '3',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  onLogout();
                },
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Olá, Lucas! 👋',
            style: TextStyle(color: Colors.white, fontSize: 42 / 1.6, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bem-vindo ao Residencial Vila das Flores',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
