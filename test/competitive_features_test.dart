import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/dialogs/emergency_sos_dialog.dart';
import 'package:projeto_front/features/community/presentation/dialogs/renovation_request_dialog.dart';
import 'package:projeto_front/features/community/presentation/dialogs/visitor_digital_pass_dialog.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  group('10 Competitive Features Tests', () {
    testWidgets('EmergencySOSDialog renders panic button and emergency types', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final api = CommunityApi(api: HomeService(token: 'test-token'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencySOSDialog(
              condominiumId: 1,
              api: api,
              unitId: 101,
            ),
          ),
        ),
      );

      expect(find.text('Botão de Pânico & Alerta SOS'), findsOneWidget);
      expect(find.text('Tipo de Emergência *'), findsOneWidget);
      expect(find.text('DISPARAR ALERTA DE EMERGÊNCIA'), findsOneWidget);
    });

    testWidgets('VisitorDigitalPassDialog renders visitor code and WhatsApp action', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/visitors/12/digital-pass')) {
          return http.Response(
            jsonEncode({
              'visitorId': 12,
              'visitorName': 'Carlos Alberto',
              'unitLabel': 'Bloco A • Unidade 101',
              'condominiumName': 'Condomínio Solar',
              'accessCode': '984512',
              'whatsappShareUrl': 'https://api.whatsapp.com/send?text=convite',
              'whatsappMessageText': 'Convite para Carlos Alberto',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final api = CommunityApi(api: HomeService(token: 'test-token', client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitorDigitalPassDialog(
              visitorId: 12,
              api: api,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Convite Digital de Acesso'), findsOneWidget);
      expect(find.text('Carlos Alberto'), findsOneWidget);
      expect(find.text('984512'), findsOneWidget);
      expect(find.text('Copiar Texto para WhatsApp'), findsOneWidget);
    });

    testWidgets('RenovationRequestDialog renders NBR 16.280 form fields', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final api = CommunityApi(api: HomeService(token: 'test-token'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RenovationRequestDialog(
              condominiumId: 1,
              units: const [
                {'id': 101, 'identifier': '101', 'sector': 'Bloco A'}
              ],
              api: api,
            ),
          ),
        ),
      );

      expect(find.text('Solicitação de Obra / Reforma'), findsOneWidget);
      expect(find.text('Conformidade com a ABNT NBR 16.280'), findsOneWidget);
      expect(find.text('ART / RRT Técnico'), findsOneWidget);
      expect(find.text('Enviar para Aprovação do Síndico'), findsOneWidget);
    });

    test('CommunityApi provides full competitive methods suite', () {
      final api = CommunityApi(api: HomeService(token: 'test-token'));

      // 1. Obras & Reformas
      expect(api.getRenovations, isA<Function>());
      expect(api.requestRenovation, isA<Function>());
      expect(api.approveRenovation, isA<Function>());
      expect(api.rejectRenovation, isA<Function>());
      expect(api.completeRenovation, isA<Function>());

      // 2. Passagem de Turno
      expect(api.getShiftLogs, isA<Function>());
      expect(api.createShiftLog, isA<Function>());
      expect(api.acknowledgeShiftLog, isA<Function>());

      // 3. Controle de Chaves
      expect(api.getKeys, isA<Function>());
      expect(api.createKey, isA<Function>());
      expect(api.checkoutKey, isA<Function>());
      expect(api.checkinKey, isA<Function>());

      // 4. Emergência SOS
      expect(api.getEmergencyAlerts, isA<Function>());
      expect(api.triggerEmergencyAlert, isA<Function>());
      expect(api.attendEmergencyAlert, isA<Function>());
      expect(api.resolveEmergencyAlert, isA<Function>());

      // 5. Medição de Água & Gás
      expect(api.getUtilityReadings, isA<Function>());
      expect(api.createUtilityReading, isA<Function>());

      // 6. Previsão Orçamentária
      expect(api.getBudgetComparison, isA<Function>());
      expect(api.saveBudgetForecast, isA<Function>());

      // 7. Checklists Preventivos
      expect(api.getChecklists, isA<Function>());
      expect(api.createChecklist, isA<Function>());
      expect(api.completeChecklist, isA<Function>());

      // 8. Contratos e Garantias
      expect(api.getContracts, isA<Function>());
      expect(api.createContract, isA<Function>());
      expect(api.terminateContract, isA<Function>());

      // 9. Convite Digital WhatsApp
      expect(api.getVisitorDigitalPass, isA<Function>());

      // 10. Smart Lockers
      expect(api.listLockers, isA<Function>());
      expect(api.depositLocker, isA<Function>());
      expect(api.retrieveLocker, isA<Function>());
    });
  });
}
