import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    required this.trailing,
  });

  final String title;
  final Widget child;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 36 / 1.6, fontWeight: FontWeight.w700, color: Color(0xFF13162A))),
                const Spacer(),
                Text(
                  trailing,
                  style: const TextStyle(
                    color: Color(0xFF2F3FB0),
                    fontSize: 29 / 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
