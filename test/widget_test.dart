import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:projeto_front/features/auth/presentation/pages/login_page.dart';
import 'package:projeto_front/features/home/presentation/widgets/home_header.dart';

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

    expect(find.text('Entrar no Condomínio App'), findsOneWidget);
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
}

Future<void> _noopLogout() async {}
