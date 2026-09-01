import 'package:flutter/material.dart';

import '../../domain/entities/home_models.dart';

class ReservationTile extends StatelessWidget {
  const ReservationTile({
    super.key,
    required this.item,
  });

  final ReservationItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 110,
          height: 74,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E9F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.image_outlined, color: Color(0xFF7A84AA), size: 34),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: Color(0xFF13162A))),
              const SizedBox(height: 4),
              Text(item.date, style: const TextStyle(fontSize: 17, color: Color(0xFF5C6179))),
              const SizedBox(height: 2),
              Text(item.time, style: const TextStyle(fontSize: 17, color: Color(0xFF5C6179))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF8ED),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            item.status,
            style: const TextStyle(
              color: Color(0xFF15A86B),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
