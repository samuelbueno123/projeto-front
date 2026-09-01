import 'package:flutter/material.dart';

import '../domain/entities/home_models.dart';

class HomeMockData {
  static const quickActions = [
    QuickAction(label: 'Boletos', icon: Icons.receipt_long_outlined, color: Color(0xFF1EB980)),
    QuickAction(label: 'Reservas', icon: Icons.inventory_2_outlined, color: Color(0xFFFFB300)),
    QuickAction(label: 'Comunicados', icon: Icons.campaign_outlined, color: Color(0xFF7C4DFF)),
    QuickAction(label: 'Visitantes', icon: Icons.groups_outlined, color: Color(0xFF4A67F5)),
    QuickAction(label: 'Chamados', icon: Icons.support_agent_outlined, color: Color(0xFF00A86B)),
  ];

  static const bill = BillItem(
    title: 'Taxa de Condomínio – Agosto/2026',
    dueDate: '10/08/2026',
    value: 'R\$ 450,00',
    status: 'Vencido',
  );

  static const announcements = [
    AnnouncementItem(
      title: 'Manutenção no Elevador Social',
      date: '14/08/2026 às 09:15',
      description: 'Informamos que o elevador social estará em manutenção...',
      icon: Icons.campaign_outlined,
      color: Color(0xFF7C4DFF),
    ),
    AnnouncementItem(
      title: 'Campanha de Sustentabilidade',
      date: '12/08/2026 às 16:30',
      description: 'Participe da nossa campanha de coleta seletiva. Faça sua...',
      icon: Icons.energy_savings_leaf_outlined,
      color: Color(0xFF1EB980),
    ),
  ];

  static const reservation = ReservationItem(
    title: 'Salão de Festas',
    date: '20/08/2026',
    time: '14:00 - 18:00',
    status: 'Confirmada',
  );
}
