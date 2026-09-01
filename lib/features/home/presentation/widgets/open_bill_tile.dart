import 'package:flutter/material.dart';

import '../../domain/entities/home_models.dart';

class OpenBillTile extends StatelessWidget {
  const OpenBillTile({
    super.key,
    required this.item,
  });

  final BillItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.description_outlined, color: Color(0xFFEF4444)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: Color(0xFF13162A))),
              const SizedBox(height: 4),
              Text('Vencimento: ${item.dueDate}', style: const TextStyle(fontSize: 17, color: Color(0xFF5C6179))),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(item.value, style: const TextStyle(fontSize: 32 / 1.6, fontWeight: FontWeight.w700, color: Color(0xFF13162A))),
            const SizedBox(height: 4),
            Text(item.status, style: const TextStyle(fontSize: 17, color: Color(0xFFEF4444))),
          ],
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2F3FB0),
            side: const BorderSide(color: Color(0xFFD8DDF3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: const Text('Pagar agora', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
