import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/core/design_system/saas_design_system.dart';

void main() {
  group('SaaSDesignSystem UI/UX Components Tests', () {
    testWidgets('SaaSLoadingState renders spinner and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SaaSLoadingState(message: 'Carregando indicadores...'),
          ),
        ),
      );

      expect(find.text('Carregando indicadores...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('SaaSEmptyState renders icon, title, subtitle and action', (tester) async {
      var actionClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaaSEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Caixa de entrada vazia',
              subtitle: 'Nenhuma notificação recebida até o momento.',
              action: ElevatedButton(
                onPressed: () => actionClicked = true,
                child: const Text('Atualizar'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Caixa de entrada vazia'), findsOneWidget);
      expect(find.text('Nenhuma notificação recebida até o momento.'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);

      await tester.tap(find.text('Atualizar'));
      expect(actionClicked, isTrue);
    });

    testWidgets('SaaSErrorState renders error banner and triggers retry', (tester) async {
      var retryClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaaSErrorState(
              message: 'Falha na conexão com a API',
              onRetry: () => retryClicked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar'), findsOneWidget);
      expect(find.text('Falha na conexão com a API'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      expect(retryClicked, isTrue);
    });

    testWidgets('SaaSSearchBar accepts input and triggers callbacks', (tester) async {
      String changedQuery = '';
      String submittedQuery = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaaSSearchBar(
              hintText: 'Pesquisar moradores...',
              onChanged: (val) => changedQuery = val,
              onSubmitted: (val) => submittedQuery = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Apartamento 101');
      expect(changedQuery, equals('Apartamento 101'));

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(submittedQuery, equals('Apartamento 101'));
    });

    testWidgets('SaaSDataCard renders title, status badge and action buttons', (tester) async {
      var actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaaSDataCard(
              title: 'Reserva do Salão Gourmet',
              subtitle: 'Data: 15/12/2026 das 14h às 22h',
              badge: const SaaSBadge(
                label: 'CONFIRMADA',
                variant: SaaSBadgeVariant.success,
              ),
              metadata: const [
                Text('Morador: Carlos Silva'),
                Text('Apto 402'),
              ],
              actions: [
                IconButton(
                  icon: const Icon(Icons.cancel_outlined),
                  onPressed: () => actionTapped = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reserva do Salão Gourmet'), findsOneWidget);
      expect(find.text('Data: 15/12/2026 das 14h às 22h'), findsOneWidget);
      expect(find.text('CONFIRMADA'), findsOneWidget);
      expect(find.text('Morador: Carlos Silva'), findsOneWidget);
      expect(find.text('Apto 402'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.cancel_outlined));
      expect(actionTapped, isTrue);
    });

    testWidgets('SaaSMetricGrid renders responsive metrics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SaaSMetricGrid(
              items: [
                SaaSMetricCard(
                  title: 'Taxa de Inadimplência',
                  value: '2.4%',
                  icon: Icons.trending_down,
                  trend: '-0.8% este mês',
                  trendPositive: true,
                ),
                SaaSMetricCard(
                  title: 'Ocorrências Abertas',
                  value: '3',
                  icon: Icons.assignment_late_outlined,
                  trend: 'Estável',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Taxa de Inadimplência'), findsOneWidget);
      expect(find.text('2.4%'), findsOneWidget);
      expect(find.text('-0.8% este mês'), findsOneWidget);
      expect(find.text('Ocorrências Abertas'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
