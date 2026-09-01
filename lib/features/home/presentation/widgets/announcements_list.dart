import 'package:flutter/material.dart';

import '../../domain/entities/home_models.dart';

class AnnouncementsList extends StatelessWidget {
  const AnnouncementsList({
    super.key,
    required this.items,
  });

  final List<AnnouncementItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: Color(0xFF13162A))),
                    const SizedBox(height: 2),
                    Text(item.date, style: const TextStyle(fontSize: 17, color: Color(0xFF5C6179))),
                    const SizedBox(height: 4),
                    Text(item.description, style: const TextStyle(fontSize: 17, color: Color(0xFF5C6179))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Icon(Icons.circle, size: 10, color: Color(0xFF3E4CDF)),
              ),
            ],
          ),
        );
      }),
    );
  }
}
