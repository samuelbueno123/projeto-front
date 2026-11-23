import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:projeto_front/core/services/realtime_service.dart';
import 'package:projeto_front/core/theme/app_theme.dart';
import 'package:projeto_front/features/admin/presentation/admin_page.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/views/community_hub_view.dart';
import 'package:projeto_front/features/doorman/presentation/pages/doorman_page.dart';
import 'package:projeto_front/features/home/data/home_service.dart';
import 'package:projeto_front/features/home/presentation/pages/home_page.dart';
import 'package:projeto_front/features/manager/presentation/manager_page.dart';

const List<String> _testAllFeatures = [
  'PACKAGES',
  'NOTIFICATIONS',
  'ANNOUNCEMENTS',
  'RESERVATIONS',
  'REPORTS',
  'MARKETPLACE_INTEGRATION',
  'VISITORS',
  'DOORMAN_CHAT',
  'COMMUNITY_TICKETS',
  'POLLS',
  'FINANCIAL',
  'MAINTENANCE',
  'ASSEMBLIES',
  'SMART_LOCKERS',
  'CONCIERGE_OPERATIONS',
  'EMERGENCY_SOS',
  'AI_ASSISTANT',
];

void main() {
  tearDown(() {
    RealtimeService.instance.disconnect();
  });

  group('4 Dashboards SaaS Integration Widget Tests', () {
    testWidgets('Painel do Síndico renderiza métricas reais, financeiro e reservas', (
      tester,
    ) async {
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
                'address': 'Rua das Palmeiras, 400',
                'planSelected': true,
                'planName': 'Enterprise',
                'features': _testAllFeatures,
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
                'totalUnits': 120,
                'totalUsers': 342,
                'totalReservations': 14,
                'summary': {
                  'occupiedUnits': 118,
                  'vacantUnits': 2,
                  'recentMembershipsCount': 8,
                  'pendingMembershipRequestsCount': 1,
                  'activeReservationsCount': 14,
                  'todayReservationsCount': 2,
                  'weekReservationsCount': 12,
                  'openTicketsCount': 3,
                  'overdueMaintenanceCount': 1,
                  'openMaintenanceCount': 2,
                  'pendingAssembliesCount': 2,
                  'totalInvoiced': 5400.0,
                  'totalCollected': 4050.0,
                  'totalPending': 900.0,
                  'overdueAmount': 450.0,
                  'paidUnitsCount': 10,
                  'pendingUnitsCount': 2,
                  'overdueUnitsCount': 1,
                },
                'units': [
                  {
                    'id': 101,
                    'identifier': '1401',
                    'sector': 'Bloco 2',
                    'paymentStatus': 'PENDING',
                    'amount': 450.0,
                  },
                ],
                'reservations': [
                  {
                    'id': 50,
                    'commonArea': 'Salão Gourmet',
                    'residentName': 'Samuel',
                    'status': 'CONFIRMED',
                    'startAt': '2026-11-21T19:00:00',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/tickets')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 77,
                  'title': 'Elevador Bloco 1 - Manutenção Preventiva',
                  'status': 'OPEN',
                  'category': 'MAINTENANCE',
                },
              ]),
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

      expect(find.text('Condomínio Acqua'), findsWidgets);
      expect(find.text('120'), findsWidgets);
      expect(find.text('342'), findsWidgets);
      expect(find.text('Convidar Morador'), findsOneWidget);
      expect(find.text('Emitir Comunicado'), findsOneWidget);
      expect(find.text('Assembleia Virtual'), findsOneWidget);
      expect(find.text('Nova Manutenção'), findsOneWidget);
      expect(find.text('Gerar Boleto'), findsOneWidget);
      expect(
        find.text('Elevador Bloco 1 - Manutenção Preventiva'),
        findsOneWidget,
      );
    });

    testWidgets('Painel do Morador carrega dados reais e troca de condomínio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final requestedPackageCondoIds = <String>[];
      final api = HomeService(
        token: 'fake-token',
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/users/me')) {
            return http.Response(
              jsonEncode({'firstName': 'Samuel', 'email': 'samuel@ancora.com'}),
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
                  'authority': 'ROLE_RESIDENT',
                  'unitIdentifier': '1401',
                  'sectorName': 'Bloco 2',
                  'hasSeenWelcome': true,
                },
                {
                  'id': 2,
                  'condominiumId': 20,
                  'condominiumName': 'Condomínio Solar',
                  'authority': 'ROLE_RESIDENT',
                  'unitIdentifier': '302',
                  'sectorName': 'Torre A',
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
                'features': _testAllFeatures,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/packages/my')) {
            final cid = req.url.queryParameters['condominiumId'] ?? '';
            requestedPackageCondoIds.add(cid);
            return http.Response(
              jsonEncode({
                'content': [
                  {
                    'id': 91,
                    'description': 'Sedex - Teclado Mecânico',
                    'status': 'RECEIVED',
                    'receivedAt': '2026-11-21T14:10:00',
                    'pickupPin': '4821',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/my-invoices')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'status': 'PENDING',
                  'amount': 450.0,
                  'dueDate': '2026-11-27',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/reservations/my')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 11,
                  'commonAreaName': 'Salão Gourmet',
                  'status': 'CONFIRMED',
                  'startAt': '2026-11-28T19:00:00',
                },
              ]),
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
          home: HomePage(
            token: 'fake-token',
            userName: 'Samuel Costa',
            userEmail: 'samuel@ancora.com',
            onLogout: () async {},
            reauthenticateWithGoogle: () async => '',
            refreshWithCredentials: (_, __) async {},
            refreshGoogleSession: () async {},
            api: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requestedPackageCondoIds, contains('10'));
      expect(find.textContaining('Olá, Samuel!'), findsWidgets);
      expect(find.text('Ações Rápidas'), findsOneWidget);
      expect(find.text('Minhas Reservas'), findsWidgets);
      expect(find.text('Salão Gourmet'), findsWidgets);
    });

    testWidgets('Painel do Porteiro exibe encomendas, ações e fluxo lateral', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final api = HomeService(
        token: 'fake-token',
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/users/me')) {
            return http.Response(
              jsonEncode({'firstName': 'Samuel'}),
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
                  'authority': 'ROLE_DOORMAN',
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
                'features': _testAllFeatures,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/packages')) {
            return http.Response(
              jsonEncode({
                'content': [
                  {
                    'id': 5,
                    'description': 'Amazon - Notebook - Samuel',
                    'unitIdentifier': '1401',
                    'sectorName': 'BL 2',
                    'recipientName': 'Samuel',
                    'status': 'RECEIVED',
                    'receivedAt': '2026-11-21T10:30:00',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/visitors')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 88,
                  'visitorName': 'Carlos Técnico',
                  'visitorType': 'SERVICE_PROVIDER',
                  'status': 'CHECKED_IN',
                  'unitLabel': 'BL 2 • AP 1401',
                },
              ]),
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
          home: DoormanPage(
            token: 'fake-token',
            userName: 'Samuel Porteiro',
            onLogout: () async {},
            api: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Registrar Encomenda'), findsWidgets);
      expect(find.textContaining('Liberar Visitante'), findsWidgets);
      expect(find.textContaining('Ocorrência Urgente'), findsWidgets);
      expect(find.text('Amazon - Notebook - Samuel'), findsWidgets);
      expect(find.text('Dar Baixa (PIN)'), findsOneWidget);
      expect(find.text('Notificar Morador'), findsOneWidget);
      expect(find.text('Carlos Técnico'), findsOneWidget);
    });

    testWidgets('Painel do Admin renderiza uptime real, filtros e logs recentes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final api = HomeService(
        token: 'fake-token',
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/admin/overview')) {
            return http.Response(
              jsonEncode({
                'condominiums': 3,
                'activeCondominiums': 3,
                'users': 8,
                'usersByRole': {'ROLE_ADMIN': 2, 'ROLE_MANAGER': 6},
                'residents': 342,
                'units': 120,
                'memberships': 6,
                'moduleVolumes': {
                  'users': 8,
                  'condominiums': 3,
                  'memberships': 6,
                  'sectors': 4,
                  'units': 120,
                  'residents': 342,
                  'packages': 18,
                  'packageHistory': 250,
                  'announcements': 14,
                  'reservations': 22,
                  'commonAreas': 8,
                  'notifications': 31,
                },
                'recentAuditLogs': [
                  {
                    'action': 'CREATE_CONDOMINIUM',
                    'entityType': 'Condominium',
                    'actorEmail': 'admin@ancora.com',
                    'createdAt': '2026-11-21T09:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/admin/diagnostics')) {
            return http.Response(
              jsonEncode({
                'overallStatus': 'UP',
                'database': {'latencyMs': 4},
                'jvm': {'uptimeSeconds': 172800},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/admin/data/condominiums')) {
            return http.Response(
              jsonEncode({
                'content': [
                  {'id': 10, 'name': 'Condomínio Acqua'},
                ],
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
          home: AdminPage(
            token: 'fake-token',
            userName: 'Admin Global',
            userEmail: 'admin@ancora.com',
            onLogout: () async {},
            reauthenticateWithGoogle: () async => '',
            refreshWithCredentials: (_, __) async {},
            refreshGoogleSession: () async {},
            api: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Console Global • Administrador do Sistema'),
        findsOneWidget,
      );
      expect(find.text('Condomínios Ativos'), findsOneWidget);
      expect(find.text('Usuários Administrativos'), findsOneWidget);
      expect(find.text('Moradores Vinculados'), findsOneWidget);
      expect(find.text('Saúde & Uptime Real'), findsOneWidget);
      expect(find.text('2d 0h'), findsOneWidget);
      expect(find.text('Atividades Recentes (Auditoria)'), findsOneWidget);
      expect(find.textContaining('CREATE_CONDOMINIUM'), findsOneWidget);

      await tester.tap(find.text('Ver todas (38)'));
      await tester.pumpAndSettle();
      expect(find.text('Principais (12)'), findsOneWidget);
    });

    testWidgets(
      'Todos os 4 dashboards renderizam corretamente em viewport mobile (390x844) com estado vazio sem overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final emptyApi = HomeService(
          token: 'fake-token',
          client: MockClient((req) async {
            final path = req.url.path;
            if (path.endsWith('/users/me')) {
              return http.Response(
                jsonEncode({'firstName': 'Samuel', 'email': 'samuel@ancora.com'}),
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
                    'condominiumName': 'Condomínio Vazio',
                    'authority': 'ROLE_RESIDENT',
                    'hasSeenWelcome': true,
                  },
                  {
                    'id': 2,
                    'condominiumId': 10,
                    'condominiumName': 'Condomínio Vazio',
                    'authority': 'ROLE_MANAGER',
                    'hasSeenWelcome': true,
                  },
                  {
                    'id': 3,
                    'condominiumId': 10,
                    'condominiumName': 'Condomínio Vazio',
                    'authority': 'ROLE_DOORMAN',
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
                  'name': 'Condomínio Vazio',
                  'planSelected': true,
                  'features': _testAllFeatures,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/manager/dashboard')) {
              return http.Response(
                jsonEncode({
                  'condominiumId': 10,
                  'condominiumName': 'Condomínio Vazio',
                  'totalUnits': 0,
                  'totalUsers': 0,
                  'totalReservations': 0,
                  'units': [],
                  'reservations': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/admin/overview')) {
              return http.Response(
                jsonEncode({
                  'condominiums': 0,
                  'users': 0,
                  'residents': 0,
                  'recentAuditLogs': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/packages/my') || path.endsWith('/packages')) {
              return http.Response(
                jsonEncode({'content': []}),
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
            home: HomePage(
              token: 'fake-token',
              userName: 'Samuel Costa',
              userEmail: 'samuel@ancora.com',
              onLogout: () async {},
              reauthenticateWithGoogle: () async => '',
              refreshWithCredentials: (_, __) async {},
              refreshGoogleSession: () async {},
              api: emptyApi,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Olá, Samuel!'), findsWidgets);
      },
    );

    testWidgets('Mobile ManagerPage (390x844) renderiza estado vazio sem overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emptyApi = HomeService(
        token: 'fake-token',
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/memberships/my')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 2,
                  'condominiumId': 10,
                  'condominiumName': 'Condomínio Vazio',
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
                'name': 'Condomínio Vazio',
                'planSelected': true,
                'features': _testAllFeatures,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/manager/dashboard')) {
            return http.Response(
              jsonEncode({
                'condominiumId': 10,
                'condominiumName': 'Condomínio Vazio',
                'totalUnits': 0,
                'totalUsers': 0,
                'totalReservations': 0,
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
            userName: 'Gestor',
            onLogout: () async {},
            api: emptyApi,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Condomínio Vazio'), findsWidgets);
    });

    testWidgets('Mobile DoormanPage & AdminPage (390x844) renderizam sem overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emptyApi = HomeService(
        token: 'fake-token',
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/memberships/my')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 3,
                  'condominiumId': 10,
                  'condominiumName': 'Condomínio Vazio',
                  'authority': 'ROLE_DOORMAN',
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
                'name': 'Condomínio Vazio',
                'features': _testAllFeatures,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/admin/overview')) {
            return http.Response(
              jsonEncode({
                'condominiums': 0,
                'users': 0,
                'residents': 0,
                'recentAuditLogs': [],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.endsWith('/packages')) {
            return http.Response(
              jsonEncode({'content': []}),
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
          home: DoormanPage(
            token: 'fake-token',
            userName: 'Samuel',
            onLogout: () async {},
            api: emptyApi,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Encomendas Pendentes'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nenhuma encomenda'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPage(
            token: 'fake-token',
            userName: 'Admin',
            userEmail: 'admin@ancora.com',
            onLogout: () async {},
            reauthenticateWithGoogle: () async => '',
            refreshWithCredentials: (_, __) async {},
            refreshGoogleSession: () async {},
            api: emptyApi,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Console Global'), findsOneWidget);
    });

    testWidgets(
      'Sidebars recolhíveis, navegação inline, Enquetes reais e Dark Mode nos 4 dashboards',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        var pollClosed = false;
        final pollsApi = HomeService(
          token: 'fake-token',
          client: MockClient((req) async {
            final path = req.url.path;
            if (path.endsWith('/polls')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 77,
                    'title': 'Reforma do bicicletário',
                    'description': 'Aprovar orçamento?',
                    'active': !pollClosed,
                    'totalVotes': 3,
                    'myOptionId': 701,
                    'options': [
                      {'id': 701, 'label': 'Sim, aprovar', 'votes': 2},
                      {'id': 702, 'label': 'Adiar obra', 'votes': 1},
                    ],
                  },
                ]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/polls/77/close')) {
              pollClosed = true;
              return http.Response(
                jsonEncode({
                  'id': 77,
                  'title': 'Reforma do bicicletário',
                  'active': false,
                  'totalVotes': 3,
                  'options': [
                    {'id': 701, 'label': 'Sim, aprovar', 'votes': 2},
                    {'id': 702, 'label': 'Adiar obra', 'votes': 1},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/admin/overview')) {
              return http.Response(
                jsonEncode({
                  'condominiums': 1,
                  'activeCondominiums': 1,
                  'users': 4,
                  'residents': 12,
                  'recentAuditLogs': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/memberships/my')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 9,
                    'condominiumId': 10,
                    'condominiumName': 'Condomínio Acqua',
                    'authority': 'ROLE_DOORMAN',
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
                  'features': _testAllFeatures,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/packages')) {
              return http.Response(
                jsonEncode({'content': []}),
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

        // 1) AdminPage in Dark Mode: collapse sidebar & switch inline to Logs e Auditoria
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: AdminPage(
              token: 'fake-token',
              userName: 'Admin',
              userEmail: 'admin@ancora.com',
              onLogout: () async {},
              reauthenticateWithGoogle: () async => '',
              refreshWithCredentials: (_, __) async {},
              refreshGoogleSession: () async {},
              api: pollsApi,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('CENTRAL DE COMANDO'), findsOneWidget);
        await tester.tap(find.byTooltip('Recolher menu').first);
        await tester.pumpAndSettle();
        expect(find.text('CENTRAL DE COMANDO'), findsNothing);
        await tester.tap(find.byTooltip('Expandir menu lateral'));
        await tester.pumpAndSettle();
        expect(find.text('CENTRAL DE COMANDO'), findsOneWidget);

        // 2) DoormanPage in Dark Mode: collapse sidebar + switch inline to Notificações
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: DoormanPage(
              token: 'fake-token',
              userName: 'Samuel',
              onLogout: () async {},
              api: pollsApi,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Consulta de Placas'), findsOneWidget);
        await tester.tap(find.text('Notificações').first);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Notificações'),
          findsWidgets,
        );
        await tester.tap(find.byTooltip('Recolher barra lateral'));
        await tester.pumpAndSettle();
        expect(find.text('Consulta de Placas'), findsNothing);

        // 3) CommunityHubView Polls tab in Dark Mode renders real label/votes/active & closes poll
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: Scaffold(
              body: CommunityHubView(
                api: CommunityApi(api: pollsApi),
                condominiumId: 10,
                canManage: true,
                initialCategoryIndex: 2,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Reforma do bicicletário'), findsOneWidget);
        expect(find.text('Sim, aprovar'), findsOneWidget);
        expect(find.text('Adiar obra'), findsOneWidget);
        expect(find.text('2 voto(s) (67%)'), findsOneWidget);
        await tester.tap(find.byTooltip('Encerrar votação'));
        await tester.pumpAndSettle();
        expect(pollClosed, isTrue);
        expect(find.text('Encerrada'), findsOneWidget);
      },
    );
  });
}
