import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/views/community_hub_view.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  testWidgets('CommunityHubView renders commercial tabs: Manutencao, Assembleias, Financeiro', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final api = CommunityApi(api: HomeService(token: 'test-token'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityHubView(
            api: api,
            condominiumId: 1,
            canManage: true,
            initialCategoryIndex: 11, // Manutenção & O.S.
          ),
        ),
      ),
    );

    // Initial pump and settle
    await tester.pumpAndSettle();

    expect(find.text('Manutenção & O.S.'), findsOneWidget);
    expect(find.text('Assembleias'), findsOneWidget);
    expect(find.text('Financeiro'), findsOneWidget);
  });

  test('CommunityApi contains methods for commercial modules', () {
    final api = CommunityApi(api: HomeService(token: 'test-token'));

    expect(api.getFinancialSummary, isA<Function>());
    expect(api.listExpenses, isA<Function>());
    expect(api.createExpense, isA<Function>());
    expect(api.payExpense, isA<Function>());

    expect(api.listMaintenanceOrders, isA<Function>());
    expect(api.createMaintenanceOrder, isA<Function>());
    expect(api.updateMaintenanceOrderStatus, isA<Function>());

    expect(api.listAssemblies, isA<Function>());
    expect(api.createAssembly, isA<Function>());
    expect(api.addAssemblyTopic, isA<Function>());
    expect(api.castAssemblyVote, isA<Function>());

    expect(api.askAssistant, isA<Function>());
  });
}
