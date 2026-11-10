import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:projeto_front/features/admin/presentation/admin_command_center_views.dart';
import 'package:projeto_front/features/admin/presentation/admin_page.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  group('Admin Command Center Views Tests', () {
    late HomeService mockApi;

    setUp(() {
      final client = MockClient((request) async {
        final path = request.url.path;

        if (path.contains('/admin/audit-logs/stats')) {
          return http.Response(
            jsonEncode({
              'total': 42,
              'byOutcome': {'SUCCESS': 38, 'FAILURE': 4},
              'byCategory': {'ADMIN_OPERATION': 10, 'SECURITY': 12, 'AUTHENTICATION': 20},
              'bySeverity': {'INFO': 30, 'WARN': 8, 'ERROR': 4, 'CRITICAL': 0},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/audit-logs')) {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'id': 1,
                  'timestamp': '2026-11-10T14:00:00Z',
                  'category': 'SECURITY',
                  'severity': 'WARN',
                  'outcome': 'FAILURE',
                  'principal': 'attacker@bad.com',
                  'action': 'LOGIN_FAILED',
                  'eventType': 'AUTHENTICATION_FAILURE',
                  'ipAddress': '192.168.1.100',
                  'correlationId': 'corr-12345',
                  'details': 'Tentativa de login com senha incorreta',
                },
                {
                  'id': 2,
                  'timestamp': '2026-11-10T14:05:00Z',
                  'category': 'ADMIN_OPERATION',
                  'severity': 'INFO',
                  'outcome': 'SUCCESS',
                  'principal': 'admin@system.com',
                  'action': 'CREATE_CONDOMINIUM',
                  'eventType': 'ENTITY_CREATED',
                  'ipAddress': '127.0.0.1',
                  'resourceType': 'Condominium',
                  'resourceId': '10',
                  'correlationId': 'corr-67890',
                  'details': 'Condominio Edificio Solar criado com sucesso',
                },
              ],
              'totalPages': 1,
              'totalElements': 2,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/diagnostics/cache/evict')) {
          return http.Response(
            jsonEncode({
              'status': 'CLEARED',
              'clearedCaches': ['roles', 'features', 'users'],
              'timestamp': '2026-11-10T14:10:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/diagnostics')) {
          return http.Response(
            jsonEncode({
              'timestamp': '2026-11-10T14:00:00Z',
              'overallStatus': 'UP',
              'database': {
                'status': 'UP',
                'latencyMs': 4,
                'validationQuery': 'SELECT 1',
              },
              'jvm': {
                'status': 'UP',
                'heapUsedMb': 240,
                'heapMaxMb': 1024,
                'nonHeapUsedMb': 80,
                'heapUsagePercent': 23.4,
                'uptimeSeconds': 7200,
              },
              'disk': {
                'status': 'UP',
                'freeMb': 50000,
                'totalMb': 100000,
                'usagePercent': 50.0,
              },
              'realtime': {
                'status': 'UP',
                'activeConnections': 15,
                'connectedUsers': 12,
                'connectedCondominiums': 3,
              },
              'caches': [
                {'name': 'roles', 'entries': 4, 'provider': 'ConcurrentMapCache'},
                {'name': 'features', 'entries': 18, 'provider': 'ConcurrentMapCache'},
              ],
              'operationalMetrics': {
                'loginSuccess': 150,
                'loginFailure': 3,
                'reservationCreated': 25,
                'reservationConflict': 2,
                'packageReceived': 40,
                'packageDelivered': 35,
                'emergencyTriggered': 1,
                'emergencyResolved': 1,
                'visitorCheckIn': 85,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/permissions-matrix')) {
          return http.Response(
            jsonEncode({
              'roles': [
                {
                  'role': 'ROLE_ADMIN',
                  'label': 'Administrador Global',
                  'scope': 'Plataforma Global',
                  'permissions': ['Acesso irrestrito a Central de Gerenciamento'],
                },
                {
                  'role': 'ROLE_MANAGER',
                  'label': 'Sindico / Gestor Condominial',
                  'scope': 'Escopo do Condominio Vinculado',
                  'permissions': ['Gestao de setores, unidades e moradores'],
                },
                {
                  'role': 'ROLE_DOORMAN',
                  'label': 'Porteiro / Agente de Portaria',
                  'scope': 'Operacao de Portaria do Condominio',
                  'permissions': ['Recebimento e baixa de encomendas'],
                },
                {
                  'role': 'ROLE_RESIDENT',
                  'label': 'Morador / Condomino',
                  'scope': 'Unidade Habitacional e Areas Comuns',
                  'permissions': ['Acompanhamento de encomendas e reservas'],
                },
              ],
              'commercialPlans': [
                {
                  'name': 'Plano Basico',
                  'monthlyFee': '99.00',
                  'features': [
                    {'name': 'Controle de Portaria', 'code': 'PORTARIA_BASICA'},
                  ],
                },
                {
                  'name': 'Plano Completo',
                  'monthlyFee': '299.00',
                  'features': [
                    {'name': 'Armarios Inteligentes', 'code': 'SMART_LOCKERS'},
                    {'name': 'Assembleias Virtuais', 'code': 'VIRTUAL_ASSEMBLIES'},
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/overview')) {
          return http.Response(
            jsonEncode({
              'activeCondominiums': 5,
              'inactiveCondominiums': 1,
              'usersByRole': {
                'ROLE_ADMIN': 2,
                'ROLE_MANAGER': 8,
                'ROLE_DOORMAN': 15,
                'ROLE_RESIDENT': 120,
              },
              'membershipsByStatus': {'ACTIVE': 140, 'PENDING': 3},
              'moduleVolumes': {
                'users': 145,
                'condominiums': 6,
                'residents': 120,
                'reservations': 45,
              },
              'activeSseConnections': 15,
              'connectedRealtimeUsers': 12,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/dashboard')) {
          return http.Response(
            jsonEncode({
              'users': 145,
              'condominiums': 6,
              'residents': 120,
              'reservations': 45,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/users/me')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'firstName': 'Admin',
              'lastName': 'Master',
              'email': 'admin@system.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      mockApi = HomeService(token: 'test-token', client: client);
    });

    testWidgets('AdminAuditLogView renders immutability banner, filters, and records', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAuditLogView(api: mockApi),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica banner de imutabilidade
      expect(find.textContaining('Trilha de Auditoria Imutável'), findsOneWidget);

      // Verifica estatísticas
      expect(find.text('Total de Registros'), findsOneWidget);
      expect(find.text('Falhas / Bloqueios'), findsOneWidget);

      // Verifica dados na tabela
      expect(find.text('attacker@bad.com'), findsOneWidget);
      expect(find.text('admin@system.com'), findsOneWidget);
      expect(find.text('LOGIN_FAILED'), findsOneWidget);
      expect(find.text('CREATE_CONDOMINIUM'), findsOneWidget);

      // Verifica modal de detalhes ao clicar no olho
      final detailButtons = find.byIcon(Icons.visibility_outlined);
      expect(detailButtons, findsWidgets);
      await tester.ensureVisible(detailButtons.first);
      await tester.tap(detailButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Registro de Auditoria #1'), findsOneWidget);
      expect(find.text('Fechar'), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
    });

    testWidgets('AdminDiagnosticsView renders telemetry cards and operational counters', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDiagnosticsView(api: mockApi),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Status Geral
      expect(find.textContaining('SISTEMA OPERACIONAL (STATUS UP)'), findsOneWidget);

      // Cards de Infraestrutura
      expect(find.text('Banco de Dados'), findsOneWidget);
      expect(find.text('4 ms'), findsOneWidget);
      expect(find.text('Memória JVM Heap'), findsOneWidget);
      expect(find.text('23.4%'), findsOneWidget);
      expect(find.text('Armazenamento'), findsOneWidget);
      expect(find.text('SSE Realtime'), findsOneWidget);

      // Métricas Operacionais
      expect(find.text('Métricas Operacionais em Tempo Real'), findsOneWidget);
      expect(find.text('Logins Sucesso'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('Conflitos de Reserva'), findsOneWidget);

      // Botão Limpar Caches
      expect(find.text('Limpar Caches'), findsOneWidget);
    });

    testWidgets('AdminPermissionsView renders 4-role matrix and commercial billing plans', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPermissionsView(api: mockApi),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica os 4 perfis
      expect(find.text('ROLE_ADMIN'), findsOneWidget);
      expect(find.text('ROLE_MANAGER'), findsOneWidget);
      expect(find.text('ROLE_DOORMAN'), findsOneWidget);
      expect(find.text('ROLE_RESIDENT'), findsOneWidget);

      // Verifica contagem de usuários por perfil
      expect(find.text('2 usuários'), findsOneWidget);
      expect(find.text('8 usuários'), findsOneWidget);
      expect(find.text('15 usuários'), findsOneWidget);
      expect(find.text('120 usuários'), findsOneWidget);

      // Verifica Planos Comerciais
      expect(find.text('Plano Basico'), findsOneWidget);
      expect(find.text('Plano Completo'), findsOneWidget);
      expect(find.text('R\$ 99.00/mês'), findsOneWidget);
      expect(find.text('R\$ 299.00/mês'), findsOneWidget);
    });

    testWidgets('AdminPage desktop renders Command Center navigation sidebar items', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPage(
            api: mockApi,
            token: 'test-token',
            userName: 'Admin User',
            userEmail: 'admin@system.com',
            onLogout: () async {},
            reauthenticateWithGoogle: () async => '',
            refreshWithCredentials: (_, __) async {},
            refreshGoogleSession: () async {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('CENTRAL DE COMANDO'), findsOneWidget);
      expect(find.text('Visão Geral'), findsWidgets);
      expect(find.text('Logs e Auditoria'), findsOneWidget);
      expect(find.text('Saúde e Diagnóstico'), findsOneWidget);
      expect(find.text('Permissões e Papéis'), findsOneWidget);

      // Clica em 'Logs e Auditoria' e verifica que a view de auditoria abre
      await tester.tap(find.text('Logs e Auditoria'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Trilha de Auditoria Imutável'), findsOneWidget);

      // Clica em 'Saúde e Diagnóstico'
      await tester.tap(find.text('Saúde e Diagnóstico'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SISTEMA OPERACIONAL (STATUS UP)'), findsOneWidget);

      // Clica em 'Permissões e Papéis'
      await tester.tap(find.text('Permissões e Papéis'));
      await tester.pumpAndSettle();

      expect(find.text('ROLE_ADMIN'), findsOneWidget);
    });
  });
}
