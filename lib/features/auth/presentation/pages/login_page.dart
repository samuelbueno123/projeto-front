import 'package:flutter/material.dart';
import '../widgets/google_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onGoogleLogin,
    required this.onEmailLogin,
    required this.onSignUp,
    required this.isLoading,
    this.errorMessage,
  });

  final Future<void> Function() onGoogleLogin;
  final Future<void> Function({required String email, required String password})
  onEmailLogin;
  final Future<void> Function({
    required String name,
    required String email,
    required String password,
  })
  onSignUp;
  final bool isLoading;
  final String? errorMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isSignUp) {
      final name = _nameController.text.trim();
      await widget.onSignUp(name: name, email: email, password: password);
      return;
    }

    await widget.onEmailLogin(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.apartment,
                        size: 72,
                        color: Color(0xFF2F3FB0),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isSignUp
                            ? 'Criar conta no Condomínio App'
                            : 'Entrar no Condomínio App',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isSignUp
                            ? 'Informe seus dados para criar uma conta.'
                            : 'Entre com email e senha ou use sua conta Google.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _nameController,
                          enabled: !widget.isLoading,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome completo',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Informe seu nome.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        enabled: !widget.isLoading,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(text)) {
                            return 'Informe um email válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !widget.isLoading,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip: _obscurePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (_isSignUp && text.length < 8) {
                            return 'A senha deve ter pelo menos 8 caracteres.';
                          }
                          if (!_isSignUp && text.isEmpty) {
                            return 'Informe sua senha.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: widget.isLoading ? null : _submit,
                        icon: widget.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.email_outlined),
                        label: Text(
                          widget.isLoading
                              ? 'Aguarde...'
                              : (_isSignUp
                                    ? 'Criar conta'
                                    : 'Entrar com email'),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      IgnorePointer(
                        ignoring: widget.isLoading,
                        child: Opacity(
                          opacity: widget.isLoading ? 0.5 : 1,
                          child: buildGoogleLoginButton(
                            onPressed: widget.onGoogleLogin,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.isLoading
                            ? null
                            : () {
                                setState(() => _isSignUp = !_isSignUp);
                              },
                        child: Text(
                          _isSignUp
                              ? 'Já tem conta? Entrar'
                              : 'Ainda não tem conta? Criar cadastro',
                        ),
                      ),
                      if (widget.errorMessage != null &&
                          widget.errorMessage!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
