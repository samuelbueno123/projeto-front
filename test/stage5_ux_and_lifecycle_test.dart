import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:projeto_front/core/services/realtime_service.dart';
import 'package:projeto_front/core/widgets/custom_menus.dart';
import 'package:projeto_front/core/widgets/saas_dashboard_widgets.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/views/doorman_chat_view.dart';
import 'package:projeto_front/features/community/presentation/views/doorman_community_views.dart';
import 'package:projeto_front/features/home/data/home_service.dart';
import 'package:projeto_front/features/home/presentation/pages/home_page.dart';

void main() {
  tearDown(() {
    RealtimeService.instance.disconnect();
  });

  group('Stage 5 UX, Lifecycle & Viewport Hardening Tests', () {
    testWidgets(
      'AncoraDropdown respeita limites da viewport, fecha com Escape e expõe Semantics',
      (tester) async {
        tester.view.physicalSize = const Size(420, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        int? selected = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: AncoraDropdown<int>(
                    value: selected,
                    maxMenuWidth: 360,
                    items: const [
                      AncoraMenuOption(value: 1, label: 'Unidade 101'),
                      AncoraMenuOption(value: 2, label: 'Unidade 202'),
                    ],
                    onChanged: (v) => selected = v,
                  ),
                ),
              ),
            ),
          ),
        );

        final semHandle = tester.ensureSemantics();
        try {
          await tester.tap(find.text('Unidade 101'));
          await tester.pumpAndSettle();

          expect(find.text('Unidade 202'), findsOneWidget);
          expect(find.bySemanticsLabel('Unidade 202'), findsOneWidget);

          // Menu deve caber dentro dos 420x480 da tela sem ultrapassar bordas
          final menuOptionRect = tester.getRect(find.text('Unidade 202'));
          expect(menuOptionRect.right, lessThanOrEqualTo(420));
          expect(menuOptionRect.left, greaterThanOrEqualTo(0));
          expect(menuOptionRect.top, greaterThanOrEqualTo(0));

          // Fechar com Escape via atalho de teclado
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.text('Unidade 202'), findsNothing);
        } finally {
          semHandle.dispose();
        }
      },
    );

    testWidgets(
      'DoormanSmartLockersView carrega dropdown de unidades reais e valida formulário inline',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final api = CommunityApi(
          api: HomeService(
            token: 'fake-token',
            client: MockClient((req) async {
              final path = req.url.path;
              if (path.endsWith('/lockers')) {
                return http.Response(
                  jsonEncode([
                    {
                      'id': 1,
                      'compartmentNumber': 'A-01',
                      'unitLabel': 'Bloco 1 • 101',
                      'courierName': 'Sedex',
                      'status': 'OCCUPIED',
                    },
                  ]),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (path.endsWith('/directory/units')) {
                return http.Response(
                  jsonEncode([
                    {'id': 11, 'identifier': '101', 'sectorName': 'Bloco 1'},
                    {'id': 22, 'identifier': '202', 'sectorName': 'Bloco 2'},
                  ]),
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
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DoormanSmartLockersView(api: api, condominiumId: 10),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('A-01'), findsOneWidget);

        await tester.tap(find.text('Novo Depósito'));
        await tester.pumpAndSettle();

        // Dropdown de unidades populado do diretório em vez de unidadeId numérico manual
        expect(find.text('Unidade Destino *'), findsOneWidget);
        expect(find.textContaining('Bloco 1 • Unidade 101'), findsOneWidget);

        // Validar submissão sem nº do compartimento exibe erro inline
        await tester.tap(find.text('Depositar & Gerar PIN'));
        await tester.pumpAndSettle();
        expect(
          find.text('Informe o compartimento e selecione a unidade destino.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DoormanChatView pula polling periódico quando SSE já está conectado',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        int chatFetchCount = 0;
        final api = CommunityApi(
          api: HomeService(
            token: 'fake-token',
            client: MockClient((req) async {
              final path = req.url.path;
              if (path.endsWith('/users/me')) {
                return http.Response(
                  jsonEncode({'id': 5, 'name': 'Samuel'}),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (path.contains('/doorman-chat/messages')) {
                chatFetchCount++;
                return http.Response(
                  jsonEncode([]),
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
          ),
        );

        RealtimeService.instance.setConnectionStateForTest(
          RealtimeConnectionState.connected,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DoormanChatView(
                api: api,
                condominiumId: 10,
                isDoormanMode: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final initialCount = chatFetchCount;
        expect(initialCount, greaterThanOrEqualTo(1));

        // Avança além do período do timer (20s): com SSE connected, nenhum poll adicional ocorre
        await tester.pump(const Duration(seconds: 25));
        expect(chatFetchCount, equals(initialCount));

        // Quando SSE cai para disconnected, o timer de fallback volta a executar polling
        RealtimeService.instance.setConnectionStateForTest(
          RealtimeConnectionState.disconnected,
        );
        await tester.pump(const Duration(seconds: 21));
        expect(chatFetchCount, greaterThan(initialCount));
      },
    );

    testWidgets(
      'HomePage alterna corretamente entre duas unidades do mesmo condomínio',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 860);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final api = HomeService(
          token: 'fake-token',
          client: MockClient((req) async {
            final path = req.url.path;
            if (path.endsWith('/users/me')) {
              return http.Response(
                jsonEncode({'id': 5, 'name': 'Samuel Morador'}),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/memberships/my')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 100,
                    'condominiumId': 10,
                    'condominiumName': 'Condomínio Acqua',
                    'authority': 'ROLE_RESIDENT',
                    'unitIdentifier': '101-A',
                    'sectorName': '1',
                    'hasSeenWelcome': true,
                  },
                  {
                    'id': 200,
                    'condominiumId': 10,
                    'condominiumName': 'Condomínio Acqua',
                    'authority': 'ROLE_RESIDENT',
                    'unitIdentifier': '202-B',
                    'sectorName': '2',
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
                  'features': ['PACKAGES', 'NOTIFICATIONS'],
                  'subscriptionStatus': 'ACTIVE',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path.endsWith('/packages/my')) {
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
              api: api,
              token: 'fake-token',
              userName: 'Samuel Morador',
              userEmail: 'samuel@condo.com',
              onLogout: () async {},
              reauthenticateWithGoogle: () async => '',
              refreshWithCredentials: (_, __) async {},
              refreshGoogleSession: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Apartamento 101-A - Bloco 1'), findsWidgets);

        // Abrir dropdown multi-unidade e selecionar Unidade 202-B (mesmo condominiumId: 10!)
        await tester.tap(find.byType(AncoraDropdown<int>));
        await tester.pumpAndSettle();
        expect(find.textContaining('Unidade 202-B'), findsWidgets);

        await tester.tap(find.textContaining('Unidade 202-B').last);
        await tester.pumpAndSettle();

        expect(find.textContaining('Apartamento 202-B - Bloco 2'), findsWidgets);
      },
    );

    testWidgets(
      'SaaSGlassCard interativo aciona callback com Enter e espõe botão acessível',
      (tester) async {
        int taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SaaSGlassCard(
                onTap: () => taps++,
                child: const Text('Abrir Painel Financeiro'),
              ),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(taps, equals(1));
      },
    );
  });
}
