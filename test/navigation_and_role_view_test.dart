import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/core/services/realtime_service.dart';
import 'package:projeto_front/core/widgets/role_switcher_pill.dart';
import 'package:projeto_front/features/doorman/presentation/pages/doorman_page.dart';

void main() {
  tearDown(() {
    RealtimeService.instance.disconnect();
  });

  group('RoleSwitcherPill Widget Tests', () {
    testWidgets('não renderiza nada se houver apenas 1 perfil disponível', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleSwitcherPill(
              currentRole: 'RESIDENT',
              availableRoles: const ['RESIDENT'],
              onSwitchRole: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(RoleSwitcherPill), findsOneWidget);
      expect(find.text('Morador'), findsNothing);
    });

    testWidgets('exibe perfil atual e permite alternar entre múltiplos perfis', (tester) async {
      String? selectedRole;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleSwitcherPill(
              currentRole: 'DOORMAN',
              availableRoles: const ['DOORMAN', 'RESIDENT', 'MANAGER'],
              onSwitchRole: (role) => selectedRole = role,
            ),
          ),
        ),
      );

      // Deve exibir perfil atual 'Portaria'
      expect(find.text('Portaria'), findsOneWidget);

      // Abre menu popup
      await tester.tap(find.text('Portaria'));
      await tester.pumpAndSettle();

      // Verifica itens do popup
      expect(find.text('Síndico / Gestor'), findsOneWidget);
      expect(find.text('Morador'), findsWidgets);

      // Clica em 'Síndico / Gestor'
      await tester.tap(find.text('Síndico / Gestor'));
      await tester.pumpAndSettle();

      expect(selectedRole, equals('MANAGER'));
    });
  });

  group('DoormanPage Navigation and Tabs Tests', () {
    testWidgets('renderiza todas as abas e cabeçalho operacional da portaria', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DoormanPage(
            token: null,
            userName: 'José Porteiro',
            currentRole: 'DOORMAN',
            availableRoles: const ['DOORMAN', 'RESIDENT'],
            onLogout: () async {},
            onSwitchRole: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica se as abas principais da portaria estão presentes
      expect(find.text('Encomendas'), findsOneWidget);
      expect(find.text('Visitantes'), findsOneWidget);
      expect(find.text('Consulta de Placas'), findsOneWidget);
      expect(find.text('Eventos & Convidados'), findsOneWidget);
      expect(find.text('Unidades & Achados'), findsOneWidget);
      expect(find.text('Reservas & Áreas'), findsOneWidget);
      expect(find.text('Smart Lockers'), findsOneWidget);
      expect(find.text('Chat Moradores'), findsOneWidget);

      // Verifica ações de cabeçalho
      expect(find.text('Baixa (PIN)'), findsOneWidget);
      expect(find.text('Comunicado'), findsOneWidget);
    });

    testWidgets('permite alternar entre abas na portaria', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DoormanPage(
            token: null,
            userName: 'José Porteiro',
            currentRole: 'DOORMAN',
            availableRoles: const ['DOORMAN'],
            onLogout: () async {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clica na aba Visitantes
      final visitantesTab = find.text('Visitantes');
      expect(visitantesTab, findsOneWidget);
      await tester.tap(visitantesTab);
      await tester.pumpAndSettle();

      // Clica na aba Consulta de Placas
      final placasTab = find.text('Consulta de Placas');
      expect(placasTab, findsOneWidget);
      await tester.tap(placasTab);
      await tester.pumpAndSettle();
    });
  });
}
