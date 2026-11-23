import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:projeto_front/features/admin/presentation/admin_command_center_views.dart';
import 'package:projeto_front/features/admin/presentation/admin_schema_editor_dialog.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  group('Stage 4 Structured Admin DB Editor & Audit Diff UI Tests', () {
    testWidgets(
      'AdminSchemaRecordDialog renderiza schema tipado, campos protegidos, diff e reason obrigatório',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        Map<String, dynamic>? submittedBody;
        String? searchedPlanQuery;

        final api = HomeService(
          token: 'fake-admin-token',
          client: MockClient((req) async {
            final path = req.url.path;
            if (path == '/admin/data/condominium-subscriptions/schema') {
              return http.Response(
                jsonEncode({
                  'resource': 'condominium-subscriptions',
                  'label': 'Assinaturas & Planos',
                  'creatable': false,
                  'editable': true,
                  'deletable': false,
                  'requiresReason': true,
                  'immutableLedger': false,
                  'protectedFields': ['id', 'condominiumId'],
                  'fields': [
                    {
                      'name': 'id',
                      'label': 'ID',
                      'type': 'INTEGER',
                      'required': false,
                      'editable': false,
                      'immutableOnUpdate': true,
                    },
                    {
                      'name': 'condominiumId',
                      'label': 'Condomínio',
                      'type': 'RELATION',
                      'required': true,
                      'editable': false,
                      'immutableOnUpdate': true,
                      'relationResource': 'condominiums',
                      'relationDisplayField': 'name',
                    },
                    {
                      'name': 'billingPlanId',
                      'label': 'Plano Comercial',
                      'type': 'RELATION',
                      'required': true,
                      'editable': true,
                      'immutableOnUpdate': false,
                      'relationResource': 'billing-plans',
                      'relationDisplayField': 'name',
                    },
                    {
                      'name': 'status',
                      'label': 'Status Operacional',
                      'type': 'ENUM',
                      'required': true,
                      'editable': true,
                      'immutableOnUpdate': false,
                      'enumOptions': [
                        {'value': 'ACTIVE', 'label': 'ACTIVE (Liberado)'},
                        {'value': 'SUSPENDED', 'label': 'SUSPENDED (Bloqueado)'},
                      ],
                    },
                    {
                      'name': 'autoRenew',
                      'label': 'Renovação Automática',
                      'type': 'BOOLEAN',
                      'required': false,
                      'editable': true,
                      'immutableOnUpdate': false,
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path == '/admin/data/condominium-subscriptions/15' &&
                req.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'id': 15,
                  'condominiumId': 10,
                  'condominiumName': 'Condomínio Acqua',
                  'billingPlanId': 1,
                  'billingPlanName': 'Essencial',
                  'status': 'ACTIVE',
                  'autoRenew': true,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path == '/admin/data/billing-plans' && req.method == 'GET') {
              searchedPlanQuery = req.url.queryParameters['query'] ?? '';
              return http.Response(
                jsonEncode({
                  'content': [
                    {'id': 3, 'name': 'Enterprise'},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (path == '/admin/data/condominium-subscriptions/15' &&
                req.method == 'PUT') {
              submittedBody = jsonDecode(req.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'resource': 'condominium-subscriptions',
                  'id': 15,
                  'action': 'UPDATE',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 200);
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminSchemaRecordDialog(
                api: api,
                resource: 'condominium-subscriptions',
                existingItem: const {'id': 15},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica campo protegido read-only
        expect(find.text('Condomínio • Somente leitura'), findsOneWidget);
        expect(find.text('#10 • Condomínio Acqua'), findsOneWidget);

        // Testa async searchable relation picker para Plano Comercial
        await tester.tap(find.byTooltip('Buscar billing-plans'));
        await tester.pumpAndSettle();
        expect(searchedPlanQuery, isNotNull);
        expect(find.text('Enterprise'), findsOneWidget);
        await tester.tap(find.text('Enterprise'));
        await tester.pumpAndSettle();

        // Abre revisão de diff e verifica obrigatoriedade de reason
        await tester.tap(find.text('Revisar Diff & Salvar'));
        await tester.pumpAndSettle();

        expect(find.text('Confirmar Alteração Auditada'), findsOneWidget);
        expect(find.text('Plano Comercial'), findsWidgets);

        await tester.tap(find.text('Confirmar & Gravar'));
        await tester.pumpAndSettle();
        expect(find.text('Informe o motivo para a auditoria.'), findsOneWidget);

        // Preenche reason e grava
        await tester.enterText(
          find.byType(TextField).last,
          'Upgrade comercial autorizado',
        );
        await tester.tap(find.text('Confirmar & Gravar'));
        await tester.pumpAndSettle();

        expect(submittedBody, isNotNull);
        expect(submittedBody!['reason'], equals('Upgrade comercial autorizado'));
        expect(
          (submittedBody!['data'] as Map<String, dynamic>)['billingPlanId'],
          equals(3),
        );
      },
    );

    testWidgets(
      'AdminAuditLogView exibe beforeState, afterState e reason no detalhe',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockApi = HomeService(
          token: 'fake-admin-token',
          client: MockClient((req) async {
            if (req.url.path == '/admin/audit-logs') {
              return http.Response(
                jsonEncode({
                  'content': [
                    {
                      'id': 99,
                      'timestamp': '2026-11-22T20:00:00',
                      'category': 'ADMIN_DATA',
                      'eventType': 'ADMIN_DATA_UPDATE_USERS',
                      'severity': 'INFO',
                      'principal': 'admin@ancora.com',
                      'action': 'ADMIN_DATA_UPDATE_USERS',
                      'resourceType': 'USERS',
                      'resourceId': '7',
                      'outcome': 'SUCCESS',
                      'details': 'Registro #7 atualizado em users',
                      'beforeState': '{"firstName":"Joao"}',
                      'afterState': '{"firstName":"João"}',
                      'reason': 'Correção ortográfica solicitada',
                    },
                  ],
                  'totalElements': 1,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 200);
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AdminAuditLogView(api: mockApi)),
          ),
        );
        await tester.pumpAndSettle();

        final detailsBtn = find.byIcon(Icons.visibility_outlined).first;
        await tester.ensureVisible(detailsBtn);
        await tester.tap(detailsBtn);
        await tester.pumpAndSettle();

        expect(find.text('Estado Anterior (Before):'), findsOneWidget);
        expect(find.text('Novo Estado (After):'), findsOneWidget);
        expect(find.text('Correção ortográfica solicitada'), findsOneWidget);
        expect(find.text('{"firstName":"Joao"}'), findsOneWidget);
        expect(find.text('{"firstName":"João"}'), findsOneWidget);
      },
    );
  });
}
