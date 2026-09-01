import 'package:flutter/material.dart';

import '../../data/home_mock_data.dart';
import '../widgets/announcements_list.dart';
import '../widgets/apartment_card.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/home_header.dart';
import '../widgets/open_bill_tile.dart';
import '../widgets/quick_actions_section.dart';
import '../widgets/reservation_tile.dart';
import '../widgets/section_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const HomeHeader(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 150, 18, 96),
              child: ListView(
                children: const [
                  ApartmentCard(),
                  SizedBox(height: 24),
                  QuickActionsSection(actions: HomeMockData.quickActions),
                  SizedBox(height: 24),
                  SectionCard(
                    title: 'Boletos em aberto',
                    trailing: 'Ver todos',
                    child: OpenBillTile(item: HomeMockData.bill),
                  ),
                  SizedBox(height: 18),
                  SectionCard(
                    title: 'Comunicados recentes',
                    trailing: 'Ver todos',
                    child: AnnouncementsList(items: HomeMockData.announcements),
                  ),
                  SizedBox(height: 18),
                  SectionCard(
                    title: 'Próximas reservas',
                    trailing: 'Ver todas',
                    child: ReservationTile(item: HomeMockData.reservation),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const HomeBottomNav(),
    );
  }
}
