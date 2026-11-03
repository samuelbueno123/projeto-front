import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/design_system/saas_design_system.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: SaaSColors.background(isDark),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use desktop split-screen only when width is wide enough (>= 980) and height allows it
          if (constraints.maxWidth >= 980 && constraints.maxHeight >= 640) {
            return _buildDesktopLayout(context, isDark);
          }
          return _buildMobileLayout(context, isDark);
        },
      ),
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (Split Screen, Full Height)
  // ==========================================
  Widget _buildDesktopLayout(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Row(
        children: [
          // Left showcase hero panel
          Expanded(
            flex: 5,
            child: Container(
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                      : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.apartment_rounded,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Âncora Gestão',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'Plataforma Inteligente de Gestão Condominial',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).saasSlideX(duration: 400.ms, begin: -0.1),

                    const SizedBox(height: 36),

                    // Showcase Cards & Features
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'SISTEMA DE GESTÃO MODERNO & INTEGRADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tudo o que seu condomínio\nprecisa, em uma única tela.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureTile(
                      icon: Icons.shield_outlined,
                      title: 'Portaria & Controle de Acesso',
                      desc: 'Registro rápido de encomendas, visitantes, veículos e comunicação instantânea.',
                    ),
                    const SizedBox(height: 14),
                    _buildFeatureTile(
                      icon: Icons.event_available_outlined,
                      title: 'Reservas & Áreas Comuns',
                      desc: 'Agendamento de churrasqueira, salão de festas e quadras sem conflitos.',
                    ),
                    const SizedBox(height: 14),
                    _buildFeatureTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Transparência Financeira',
                      desc: 'Emissão e consulta de boletos, relatórios de despesas e prestação de contas.',
                    ),

                    const SizedBox(height: 32),

                    // Footer info
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Autenticação segura via OAuth2 e JWT com criptografia ponta a ponta.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right login card
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildFormCard(context, isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE / COMPACT LAYOUT (Vertical, Touch)
  // ==========================================
  Widget _buildMobileLayout(BuildContext context, bool isDark) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Brand Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332563EB),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ).saasScale(duration: 350.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                _buildFormCard(context, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FORM CARD (Shared Logic, Shadcn / SaaS Look)
  // ==========================================
  Widget _buildFormCard(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pill tag
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
              ),
            ),
            child: Text(
              'ÂNCORA GESTÃO • SEU CONDOMÍNIO NA PALMA DA MÃO',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _isSignUp
              ? 'Criar conta no Âncora Gestão'
              : 'Entrar no Âncora Gestão',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: SaaSColors.textPrimary(isDark),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? 'Cadastre-se rapidamente para acompanhar encomendas, reservas e avisos do seu condomínio.'
              : 'Entre com seu e-mail e senha ou acesse com um toque usando sua conta Google.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: SaaSColors.textSecondary(isDark),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Form Container
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SaaSColors.surface(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SaaSColors.border(isDark)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _nameController,
                    enabled: !widget.isLoading,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      hintText: 'Como você gostaria de ser chamado?',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Informe seu nome.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _emailController,
                  enabled: !widget.isLoading,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'voce@exemplo.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Informe um email válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  enabled: !widget.isLoading,
                  autofillHints: const [AutofillHints.password],
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    hintText: _isSignUp
                        ? 'Mínimo de 8 caracteres'
                        : 'Digite sua senha de acesso',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                if (widget.errorMessage != null &&
                    widget.errorMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: isDark ? Colors.white : const Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.errorMessage!,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
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
                      : Icon(
                          _isSignUp
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                          size: 18,
                        ),
                  label: Text(
                    widget.isLoading
                        ? 'Conectando...'
                        : (_isSignUp ? 'Criar conta' : 'Entrar com email'),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: SaaSColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: SaaSColors.border(isDark))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ou acesse rapidamente',
                        style: TextStyle(
                          fontSize: 12,
                          color: SaaSColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: SaaSColors.border(isDark))),
                  ],
                ),
                const SizedBox(height: 14),
                IgnorePointer(
                  ignoring: widget.isLoading,
                  child: Opacity(
                    opacity: widget.isLoading ? 0.5 : 1,
                    child: buildGoogleLoginButton(
                      onPressed: widget.onGoogleLogin,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.isLoading
                      ? null
                      : () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Já tem conta? Entrar'
                        : 'Ainda não tem conta? Criar cadastro',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF93C5FD) : SaaSColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).saasFadeIn(duration: 350.ms);
  }
}
