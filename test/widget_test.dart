import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:projeto_front/features/auth/presentation/pages/login_page.dart';
import 'package:projeto_front/features/home/data/home_service.dart';
import 'package:projeto_front/features/home/presentation/widgets/home_header.dart';
import 'package:projeto_front/features/community/data/community_api.dart';

void main() {
  testWidgets('renderiza tela de login com ações principais', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onGoogleLogin: () async {},
          onEmailLogin: ({required String email, required String password}) async {},
          onSignUp: ({required String name, required String email, required String password}) async {},
          isLoading: false,
        ),
      ),
    );

    expect(find.text('Entrar no Âncora Gestão'), findsOneWidget);
    expect(find.text('Entrar com email'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Ainda não tem conta? Criar cadastro'), findsOneWidget);
  });

  testWidgets('renderiza saudação dinâmica no header', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeHeader(
            onLogout: _noopLogout,
            userName: 'Samuel',
            userEmail: 'samuel@example.com',
          ),
        ),
      ),
    );

    expect(find.text('Olá, Samuel! 👋'), findsOneWidget);
    expect(find.text('samuel@example.com'), findsOneWidget);
  });

  test('CommunityApi integra as 10 funcionalidades comerciais com o backend', () async {
    final recordedRequests = <String>[];
    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add('${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}');
      final path = request.url.path;

      if (path.endsWith('/parking-spots') && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {'id': 1, 'code': 'G1-101', 'status': 'ASSIGNED', 'unitIdentifier': '101'}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/maintenance/equipment') && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {'id': 10, 'name': 'Elevador Social', 'overdue': true, 'dueSoon': false}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/suppliers') && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {'id': 20, 'name': 'Atlas Elevadores', 'averageRating': 4.8, 'ratingCount': 5}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/visitors/validate-qr') && request.method == 'POST') {
        return http.Response(
          jsonEncode({'id': 30, 'visitorName': 'Carlos Visitante', 'status': 'CHECKED_IN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/waitlist') && request.method == 'POST') {
        return http.Response(
          jsonEncode({'id': 40, 'status': 'WAITLISTED', 'waitlistPosition': 1}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.contains('/reports/dashboard') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'packages': {'total': 12, 'pending': 3, 'delivered': 9},
            'visitors': {'total': 8, 'checkedIn': 2, 'checkedOut': 6},
            'occurrences': {'total': 4, 'open': 1, 'resolved': 3},
            'maintenance': {'totalOrders': 5, 'overdueEquipment': 1},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'ok': true}), 200, headers: {'content-type': 'application/json'});
    });

    final homeService = HomeService(token: 'fake-jwt', client: mockClient);
    final api = CommunityApi(api: homeService);

    final spots = await api.listParkingSpots(1);
    expect(spots.first['code'], 'G1-101');

    final equipment = await api.listMaintenanceEquipment(1);
    expect(equipment.first['overdue'], isTrue);

    final suppliers = await api.listSuppliers(1);
    expect(suppliers.first['averageRating'], 4.8);

    final visitor = await api.validateVisitorQr(
      1,
      qrCodeOrAccessCode: 'ANCORA-VISITOR:1:30:123456',
    );
    expect(visitor['status'], 'CHECKED_IN');

    final waitlist = await api.joinWaitlist(
      areaId: 2,
      startAt: DateTime.utc(2026, 12, 1, 14, 0),
      endAt: DateTime.utc(2026, 12, 1, 18, 0),
      contactPhone: '(21) 99999-0000',
    );
    expect(waitlist['status'], 'WAITLISTED');
    expect(waitlist['waitlistPosition'], 1);

    final report = await api.getDashboardReport(1, startDate: '2026-01-01', endDate: '2026-12-31');
    expect((report['packages'] as Map)['total'], 12);
    expect(recordedRequests.length, 6);
  });
}

Future<void> _noopLogout() async {}
