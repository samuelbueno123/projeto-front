import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/features/auth/presentation/pages/login_page.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/dialogs/generate_boleto_dialog.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  setUp(() {
    // any setup if needed
  });

  group('Login Form Validations and State Tests', () {
    testWidgets('valida campos obrigatórios de email e senha no login', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Clica em Entrar com email sem preencher
      final enterButton = find.text('Entrar com email');
      expect(enterButton, findsOneWidget);
      await tester.tap(enterButton);
      await tester.pumpAndSettle();

      // Deve exibir mensagens de validação
      expect(find.text('Informe um email válido.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);
    });

    testWidgets('valida formato incorreto de email', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      final emailField = find.widgetWithText(TextFormField, 'Email');
      expect(emailField, findsOneWidget);

      await tester.enterText(emailField, 'email-invalido-sem-arroba');
      await tester.tap(find.text('Entrar com email'));
      await tester.pumpAndSettle();

      expect(find.text('Informe um email válido.'), findsOneWidget);
    });

    testWidgets('valida regras de cadastro (nome obrigatório e senha mínima de 8 caracteres)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Alterna para tela de cadastro
      final toggleSignUpButton = find.text('Ainda não tem conta? Criar cadastro');
      expect(toggleSignUpButton, findsOneWidget);
      await tester.tap(toggleSignUpButton);
      await tester.pumpAndSettle();

      expect(find.text('Criar conta no Âncora Gestão'), findsOneWidget);
      expect(find.text('Nome completo'), findsOneWidget);

      // Preenche senha curta (< 8 chars)
      final emailField = find.widgetWithText(TextFormField, 'Email');
      final passField = find.widgetWithText(TextFormField, 'Senha');
      await tester.enterText(emailField, 'novo@condo.com');
      await tester.enterText(passField, '1234');

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      expect(find.text('Informe seu nome completo.'), findsOneWidget);
      expect(find.text('A senha deve ter pelo menos 8 caracteres.'), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro da API quando fornecida', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            onGoogleLogin: () async {},
            onEmailLogin: ({required String email, required String password}) async {},
            onSignUp: ({required String name, required String email, required String password}) async {},
            isLoading: false,
            errorMessage: 'Credenciais inválidas ou conta inativa.',
          ),
        ),
      );

      expect(find.text('Credenciais inválidas ou conta inativa.'), findsOneWidget);
    });
  });

  group('Financial Dialogs Form Validations', () {
    testWidgets('GenerateBoletoDialog renders form fields and submit button', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final api = CommunityApi(api: HomeService(token: 'mock-token'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenerateBoletoDialog(
              condominiumId: 1,
              units: const [
                {'id': 101, 'identifier': '101', 'sectorName': 'Bloco A'}
              ],
              api: api,
              onGenerated: () {},
            ),
          ),
        ),
      );

      expect(find.text('Gerar Boleto Condominial'), findsOneWidget);
      expect(find.text('Valor (R\$)'), findsOneWidget);
      expect(find.text('Vencimento'), findsOneWidget);
      expect(find.text('Gerar e Enviar Cobrança'), findsOneWidget);
    });
  });
}
