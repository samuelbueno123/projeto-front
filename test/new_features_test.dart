import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/dialogs/boleto_payment_dialog.dart';
import 'package:projeto_front/features/community/presentation/dialogs/discord_welcome_dialog.dart';
import 'package:projeto_front/features/community/presentation/dialogs/plan_selection_dialog.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  testWidgets('DiscordWelcomeDialog renders server channels and ack button', (
    tester,
  ) async {
    final api = CommunityApi(api: HomeService(token: 'test'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscordWelcomeDialog(
            condominiumName: 'Residencial Vila das Flores',
            membershipId: 1,
            api: api,
            onExplored: () {},
          ),
        ),
      ),
    );

    expect(find.text('BEM-VINDO AO CONDOMÍNIO'), findsOneWidget);
    expect(find.text('Residencial Vila das Flores'), findsOneWidget);
    expect(find.text('Começar a explorar meu condomínio!'), findsOneWidget);
    expect(find.text('# comunicados-e-avisos'), findsOneWidget);
  });

  testWidgets('PlanSelectionDialog renders 3 plans and selection button', (
    tester,
  ) async {
    final service = HomeService(
      client: MockClient((request) async {
        if (request.url.path == '/billing/plans') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Básico', 'monthlyFee': 79.9, 'active': true},
              {
                'id': 2,
                'name': 'Profissional',
                'monthlyFee': 149.9,
                'active': true,
              },
              {'id': 3, 'name': 'Premium', 'monthlyFee': 249.9, 'active': true},
            ]),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.dispose);
    final api = CommunityApi(api: service);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanSelectionDialog(
            condominiumId: 1,
            condominiumName: 'Vila das Flores',
            api: api,
            onPlanSelected: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CONFIGURAÇÃO INICIAL DO SÍNDICO'), findsOneWidget);
    expect(find.text('Básico'), findsOneWidget);
    expect(find.text('Profissional'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('BoletoPaymentDialog renders invoice details and proof upload', (
    tester,
  ) async {
    final api = CommunityApi(api: HomeService(token: 'test'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoletoPaymentDialog(
            condominiumId: 1,
            unitId: 1,
            unitLabel: 'Apartamento 204',
            title: 'Taxa de Condomínio – Agosto/2026',
            amount: 450.00,
            dueDate: '10/08/2026',
            digitableLine:
                '34191.79001 01043.510047 91020.150008 8 98010000045000',
            status: 'OVERDUE',
            api: api,
            onPaid: () {},
          ),
        ),
      ),
    );

    expect(find.text('Taxa de Condomínio – Agosto/2026'), findsOneWidget);
    expect(find.text('R\$ 450.00'), findsOneWidget);
    expect(
      find.text('Código PIX indisponível para esta fatura.'),
      findsOneWidget,
    );
    expect(find.text('Enviar comprovante para conferência'), findsOneWidget);
  });
}
