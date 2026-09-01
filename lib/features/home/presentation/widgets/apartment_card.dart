import 'package:flutter/material.dart';

class ApartmentCard extends StatelessWidget {
  const ApartmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.apartment_outlined, color: Color(0xFF3E4CDF), size: 30),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apartamento 204', style: TextStyle(fontSize: 34 / 1.6, fontWeight: FontWeight.w700, color: Color(0xFF13162A))),
                  SizedBox(height: 4),
                  Text('Bloco B', style: TextStyle(fontSize: 31 / 1.6, color: Color(0xFF5C6179))),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2F3FB0),
                side: const BorderSide(color: Color(0xFFD8DDF3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: const Row(
                children: [
                  Text('Meus dados', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
