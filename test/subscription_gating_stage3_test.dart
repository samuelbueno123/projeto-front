import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:projeto_front/core/services/realtime_service.dart';
import 'package:projeto_front/features/admin/presentation/admin_command_center_views.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/views/community_hub_view.dart';
import 'package:projeto_front/features/home/data/home_service.dart';
import 'package:projeto_front/features/manager/presentation/manager_page.dart';

void main() {
  tearDown(() {
    RealtimeService.instance.disconnect();
  });

  group('Stage 3 Subscription & Fail-Closed Feature Gating UI Tests', () {
    testWidgets(
      'CommunityHubView bloqueia abas Fail-Closed quando enabledFeatures está vazio',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final api = CommunityApi(
          api: HomeService(
            token: 'fake-token',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode([]),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CommunityHubView(
                api: api,
                condominiumId: 10,
                initialCategoryIndex: 0,
                canManage: true,
                enabledFeatures: const [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
        expect(find.text('Recurso Exclusivo de Plano'), findsWidgets);
      },
    );

    testWidgets(
      'CommunityHubView no plano Essencial libera Chamados e bloqueia Assembleias',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final api = CommunityApi(
          api: HomeService(
            token: 'fake-token',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode([]),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CommunityHubView(
                api: api,
                condominiumId: 10,
                initialCategoryIndex: 0,
                canManage: false,
                enabledFeatures: const [
                  'PACKAGES',
                  'NOTIFICATIONS',
                  'ANNOUNCEMENTS',
                  'COMMUNITY_TICKETS',
                  'POLLS',
                  'VISITORS',
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Aba 0 (Chamados) liberada -> botão Novo Chamado presente
        expect(find.text('Novo Chamado'), findsOneWidget);

        // Muda para Assembleias (aba 12) -> bloqueada Fail-Closed
        await tester.ensureVisible(find.text('Assembleias'));
        await tester.tap(find.text('Assembleias'));
        await tester.pumpAndSettle();
        expect(find.text('Recurso Exclusivo de Plano'), findsWidgets);
      },
    );

    testWidgets(
      'ManagerPage exibe banner de assinatura suspensa e oculta módulos bloqueados',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final api = HomeService(
          token: 'fake-token',
          client: MockClient((req) async {
            final path = req.url.path;
            if (path.endsWith('/users/me')) {
              return http.Response(
                jsonEncode({'firstName': 'Gestor', 'email': 'sindico@ancora.com'}),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/memberships/my')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'condominiumId': 10,
                    'condominiumName': 'Condomínio Acqua',
                    'authority': 'ROLE_MANAGER',
                    'hasSeenWelcome': true,
                  },
                ]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/condominiums/10')) {
              return http.Response(
                jsonEncode({
                  'id': 10,
                  'name': 'Condomínio Acqua',
                  'planSelected': true,
                  'planName': 'Profissional',
                  'subscriptionStatus': 'SUSPENDED',
                  'features': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/condominiums/10/subscription')) {
              return http.Response(
                jsonEncode({
                  'condominiumId': 10,
                  'condominiumName': 'Condomínio Acqua',
                  'billingPlanId': 2,
                  'billingPlanName': 'Profissional',
                  'status': 'SUSPENDED',
                  'billingCycle': 'MONTHLY',
                  'accessAllowed': false,
                  'enabledFeatures': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/manager/dashboard')) {
              return http.Response(
                jsonEncode({
                  'condominiumId': 10,
                  'condominiumName': 'Condomínio Acqua',
                  'totalUnits': 20,
                  'totalUsers': 45,
                  'totalReservations': 0,
                  'summary': {},
                  'units': [],
                  'reservations': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode([]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ManagerPage(
              token: 'fake-token',
              userName: 'Gestor Acqua',
              onLogout: () async {},
              api: api,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Assinatura Suspensa'),
          findsWidgets,
        );
        expect(
          find.textContaining('Gestão Financeira & Boletos bloqueado'),
          findsOneWidget,
        );
        expect(find.text('Gerar Boleto'), findsNothing);
        expect(find.text('Nova Manutenção'), findsNothing);
        expect(find.text('Assembleia Virtual'), findsNothing);
        expect(find.text('Gerenciar Plano'), findsWidgets);
      },
    );

    testWidgets(
      'AdminPermissionsView exibe gestão de assinaturas e aciona renovação +30d',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool renewCalled = false;
        final mockApi = HomeService(
          token: 'fake-token',
          client: MockClient((req) async {
            final path = req.url.path;
            if (path.endsWith('/admin/roles')) {
              return http.Response(
                jsonEncode([
                  {'id': 1, 'authority': 'ROLE_ADMIN'},
                  {'id': 2, 'authority': 'ROLE_MANAGER'},
                ]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/billing/plans')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'name': 'Essencial',
                    'monthlyFee': 199.0,
                    'active': true,
                    'features': ['PACKAGES', 'COMMUNITY_TICKETS'],
                  },
                ]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/admin/subscriptions')) {
              return http.Response(
                jsonEncode([
                  {
                    'condominiumId': 10,
                    'condominiumName': 'Condomínio Acqua',
                    'billingPlanId': 1,
                    'billingPlanName': 'Essencial',
                    'status': 'PAST_DUE',
                    'billingCycle': 'MONTHLY',
                    'accessAllowed': true,
                    'enabledFeatures': ['PACKAGES', 'COMMUNITY_TICKETS'],
                  },
                ]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (req.method == 'POST' &&
                path.endsWith('/admin/subscriptions/10/renew')) {
              renewCalled = true;
              return http.Response(
                jsonEncode({
                  'condominiumId': 10,
                  'condominiumName': 'Condomínio Acqua',
                  'billingPlanId': 1,
                  'billingPlanName': 'Essencial',
                  'status': 'ACTIVE',
                  'billingCycle': 'MONTHLY',
                  'accessAllowed': true,
                  'enabledFeatures': ['PACKAGES', 'COMMUNITY_TICKETS'],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AdminPermissionsView(api: mockApi)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Condomínio Acqua'), findsOneWidget);
        expect(find.textContaining('PAST_DUE • LIBERADO'), findsOneWidget);

        await tester.ensureVisible(find.text('Renovar +30d'));
        await tester.tap(find.text('Renovar +30d'));
        await tester.pumpAndSettle();

        expect(renewCalled, isTrue);
      },
    );
  });
}
