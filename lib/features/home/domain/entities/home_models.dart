import 'package:flutter/material.dart';

class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class BillItem {
  const BillItem({
    required this.title,
    required this.dueDate,
    required this.value,
    required this.status,
  });

  final String title;
  final String dueDate;
  final String value;
  final String status;
}

class AnnouncementItem {
  const AnnouncementItem({
    required this.title,
    required this.date,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String date;
  final String description;
  final IconData icon;
  final Color color;
}

class ReservationItem {
  const ReservationItem({
    required this.title,
    required this.date,
    required this.time,
    required this.status,
  });

  final String title;
  final String date;
  final String time;
  final String status;
}
