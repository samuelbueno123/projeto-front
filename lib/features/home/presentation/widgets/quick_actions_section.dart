import 'package:flutter/material.dart';

import '../../domain/entities/home_models.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({
    super.key,
    required this.actions,
  });

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Atalhos rápidos', style: TextStyle(fontSize: 34 / 1.6, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final action = actions[index];
              return Container(
                width: 126,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEDF0FA)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: action.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(action.icon, color: action.color),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      action.label,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Color(0xFF13162A)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
