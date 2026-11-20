import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projeto_front/core/design_system/motion_system.dart';
import 'package:projeto_front/core/design_system/saas_design_system.dart';
import 'package:projeto_front/core/utils/formatters.dart';
import 'package:projeto_front/core/widgets/command_palette.dart';
import 'package:projeto_front/core/widgets/custom_menus.dart';
import 'package:projeto_front/features/admin/presentation/admin_command_center_views.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/dialogs/boleto_payment_dialog.dart';
import 'package:projeto_front/features/community/presentation/dialogs/common_area_booking_dialog.dart';
import 'package:projeto_front/features/community/presentation/dialogs/join_condominium_dialog.dart';
import 'package:projeto_front/features/community/presentation/dialogs/plan_selection_dialog.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('Regressões da modernização', () {
    test('formatadores validam e normalizam entradas brasileiras', () {
      expect(formatPhone('21987654321'), '(21) 98765-4321');
      expect(validatePhone('(21) 98765-4321'), isNull);
      expect(validatePhone('123'), isNotNull);
      expect(parseBrlDouble('R\$ 1.234,56'), 1234.56);
      expect(
        matchesSearchRecord({
          'resident': 'Maria Souza',
          'unit': 101,
        }, 'maria 101'),
        isTrue,
      );
    });

    testWidgets(
      'AncoraMotion respeita animações reduzidas no ambiente de teste',
      (tester) async {
        var reduce = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                reduce = AncoraMotion.shouldReduceMotion(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(reduce, isTrue);
      },
    );

    testWidgets('AncoraDropdown seleciona a opção de 10 horas sem crash', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AncoraDropdown<int>(
                value: 4,
                items: const [
                  AncoraMenuOption(value: 4, label: '4 horas'),
                  AncoraMenuOption(value: 10, label: '10 horas'),
                ],
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AncoraDropdown<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10 horas').last);
      await tester.pumpAndSettle();

      expect(selected, 10);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'CommonAreaBookingDialog verifica uma reserva integral de 10h',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final checkedDurations = <Duration>[];
        final api = HomeService(
          client: MockClient((request) async {
            if (request.url.path == '/condominiums/1/common-areas') {
              return _json([
                {'id': 9, 'name': 'Salão de festas', 'active': true},
              ]);
            }
            if (request.url.path.endsWith('/check-availability')) {
              final start = DateTime.parse(
                request.url.queryParameters['startAt']!,
              );
              final end = DateTime.parse(request.url.queryParameters['endAt']!);
              checkedDurations.add(end.difference(start));
              return _json({'available': true, 'allowWaitlist': true});
            }
            return _json({});
          }),
        );
        addTearDown(api.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CommonAreaBookingDialog(
                api: CommunityApi(api: api),
                condominiumId: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dialogScroll = find.byType(SingleChildScrollView).first;
        await tester.drag(dialogScroll, const Offset(0, -420));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(AncoraDropdown<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('10 horas').last);
        await tester.pumpAndSettle();

        expect(checkedDurations, contains(const Duration(hours: 10)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('PlanSelectionDialog permanece utilizável em viewport mobile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = HomeService(
        client: MockClient((request) async {
          if (request.url.path == '/billing/plans') {
            return _json([
              {
                'id': 3,
                'name': 'Plano Essencial',
                'monthlyFee': 99.9,
                'active': true,
                'features': ['PACKAGES', 'REPORTS'],
              },
            ]);
          }
          return _json({});
        }),
      );
      addTearDown(api.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanSelectionDialog(
              condominiumId: 1,
              condominiumName: 'Condomínio Alameda',
              api: CommunityApi(api: api),
              onPlanSelected: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plano Essencial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'BoletoPaymentDialog não marca fatura como paga ao enviar comprovante',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final requestedPaths = <String>[];
        final api = HomeService(
          client: MockClient((request) async {
            requestedPaths.add(request.url.path);
            if (request.url.path == '/condominiums/1/units/my-payments') {
              return _json([]);
            }
            return _json({});
          }),
        );
        addTearDown(api.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoletoPaymentDialog(
                condominiumId: 1,
                unitId: 101,
                unitLabel: 'Torre A • 101',
                title: 'Cota condominial',
                amount: 450,
                dueDate: '10/12/2026',
                digitableLine: '',
                status: 'PENDING',
                api: CommunityApi(api: api),
                onPaid: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Código PIX indisponível para esta fatura.'),
          findsOneWidget,
        );
        expect(find.text('Pagar agora'), findsNothing);
        await tester.tap(find.text('Enviar comprovante para conferência'));
        await tester.pumpAndSettle();
        expect(
          find.text('Nenhuma cobrança registrada para a sua unidade.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Fechar'));
        await tester.pumpAndSettle();

        expect(find.text('Cota condominial'), findsOneWidget);
        expect(
          requestedPaths,
          isNot(contains('/condominiums/1/units/101/pay-boleto')),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('JoinCondominiumDialog aceita sector como String', (
      tester,
    ) async {
      final api = HomeService(
        client: MockClient((request) async {
          if (request.url.path == '/condominiums/available') {
            return _json([
              {'id': 1, 'name': 'Residencial Aurora'},
            ]);
          }
          if (request.url.path == '/condominiums/1/available-units') {
            return _json([
              {'id': 14, 'identifier': '101', 'sector': 'Torre Norte'},
            ]);
          }
          return _json({});
        }),
      );
      addTearDown(api.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoinCondominiumDialog(api: CommunityApi(api: api)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('101 (Torre Norte)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AncoraCommandPalette executa ações pesquisadas', (
      tester,
    ) async {
      var invoked = false;
      final actions = [
        AncoraCommandAction(
          id: 'dashboard',
          title: 'Abrir painel',
          icon: Icons.dashboard_outlined,
          onExecute: () => invoked = true,
        ),
      ];
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Portal'))),
      );
      final openFuture = AncoraCommandShortcutWrapper.open(
        tester.element(find.text('Portal')),
        actions,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir painel'));
      await tester.pumpAndSettle();
      await openFuture;

      expect(invoked, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SaaSCard aplica dark mode sem ShadTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SaaSCard(child: Text('Conteúdo do cartão')),
          ),
        ),
      );
      expect(find.text('Conteúdo do cartão'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Conteúdo do cartão'))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminPermissionsView lê planos da chave billingPlans', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = HomeService(
        client: MockClient((request) async {
          if (request.url.path == '/admin/permissions-matrix') {
            return _json({
              'roles': [
                {
                  'role': 'ROLE_ADMIN',
                  'label': 'Administrador',
                  'scope': 'Sistema',
                  'permissions': ['Gestão administrativa'],
                },
              ],
              'billingPlans': [
                {
                  'name': 'Plano da API',
                  'monthlyFee': 125,
                  'features': ['PACKAGES'],
                },
              ],
            });
          }
          if (request.url.path == '/admin/overview') {
            return _json({
              'usersByRole': {'ROLE_ADMIN': 1},
            });
          }
          return _json({});
        }),
      );
      addTearDown(api.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminPermissionsView(api: api)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plano da API'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
