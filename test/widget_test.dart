import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_front/app/app_widget.dart';

void main() {
  testWidgets('renderiza conteúdo principal da tela inicial', (WidgetTester tester) async {
    await tester.pumpWidget(const AppWidget());

    expect(find.text('Olá, Lucas! 👋'), findsOneWidget);
    expect(find.text('Atalhos rápidos'), findsOneWidget);
    expect(find.text('Boletos em aberto'), findsOneWidget);
    expect(find.text('Comunicados recentes'), findsOneWidget);
    expect(find.text('Próximas reservas'), findsOneWidget);
  });
}
