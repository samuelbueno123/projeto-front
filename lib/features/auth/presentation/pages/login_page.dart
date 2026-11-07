import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Background image (Condomínio) com desfoque suave
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Image.asset(
                'assets/images/condo_bg.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                            : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Overlay com gradiente escurecido suave para garantir legibilidade e contraste
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.black.withValues(alpha: 0.70),
                          const Color(0xFF0F172A).withValues(alpha: 0.82),
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.40),
                          const Color(0xFF0F172A).withValues(alpha: 0.62),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. Conteúdo responsivo com a aba de resumo do projeto e o formulário
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 960;

                if (isDesktop) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1060),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Aba que resume o projeto
                            Expanded(
                              flex: 5,
                              child: _buildProjectSummaryPanel(context, isDark),
                            ),
                            const SizedBox(width: 36),
                            // Formulário de Login / Cadastro
                            Expanded(
                              flex: 5,
                              child: _buildFormCard(context, isDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Layout Mobile / Telas Menores
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFormCard(context, isDark),
                          const SizedBox(height: 16),
                          _buildMobileProjectSummary(isDark),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================
  // ABA DE RESUMO DO PROJETO (Showcase Hero Panel)
  // ==========================================
  Widget _buildProjectSummaryPanel(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A)).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho da Marca
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
                        fontSize: 22,
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

          const SizedBox(height: 24),

          // Badge & Slogan
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
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tudo o que seu condomínio\nprecisa, em uma única tela.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 22),
          _buildFeatureTile(
            icon: Icons.shield_outlined,
            title: 'Portaria & Controle de Acesso',
            desc: 'Registro rápido de encomendas, visitantes, veículos e comunicação instantânea.',
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.event_available_outlined,
            title: 'Reservas & Áreas Comuns',
            desc: 'Agendamento de churrasqueira, salão de festas e quadras sem conflitos.',
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Transparência Financeira',
            desc: 'Emissão e consulta de boletos, relatórios de despesas e prestação de contas.',
          ),

          const SizedBox(height: 24),

          // Rodapé de Segurança
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
    ).saasFadeIn(duration: 400.ms);
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            child: Icon(icon, size: 18, color: Colors.white),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProjectSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A)).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apartment_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Sobre o Âncora Gestão',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Portaria 24h • Reservas de Áreas • Transparência Financeira',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FORM CARD (Blocos realçados para login)
  // ==========================================
  Widget _buildFormCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.25),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Brand Icon
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x402563EB),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ).saasScale(duration: 350.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 18),

            // Tag Pill
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  'ÂNCORA GESTÃO • CONDOMÍNIO INTELIGENTE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Título
            Text(
              _isSignUp
                  ? 'Criar conta no Âncora Gestão'
                  : 'Entrar no Âncora Gestão',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 6),

            // Subtítulo descritivo
            Text(
              _isSignUp
                  ? 'Cadastre-se rapidamente para acompanhar encomendas, reservas e avisos do seu condomínio.'
                  : 'Acesse com seu e-mail e senha ou entre diretamente com sua conta Google.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.35,
              ),
            ),

            const SizedBox(height: 24),

            // Campo de Nome (Cadastro)
            if (_isSignUp) ...[
              TextFormField(
                controller: _nameController,
                enabled: !widget.isLoading,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
                decoration: _buildInputDecoration(
                  isDark: isDark,
                  labelText: 'Nome completo',
                  hintText: 'Como você gostaria de ser chamado?',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Informe seu nome completo.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Campo de Email
            TextFormField(
              controller: _emailController,
              enabled: !widget.isLoading,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
              decoration: _buildInputDecoration(
                isDark: isDark,
                labelText: 'Email',
                hintText: 'voce@exemplo.com',
                prefixIcon: Icons.alternate_email_rounded,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Informe um email válido.';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Campo de Senha
            TextFormField(
              controller: _passwordController,
              enabled: !widget.isLoading,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
              decoration: _buildInputDecoration(
                isDark: isDark,
                labelText: 'Senha',
                hintText: _isSignUp ? 'Mínimo de 8 caracteres' : 'Digite sua senha',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    size: 20,
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

            // Bloco de Mensagem de Erro
            if (widget.errorMessage != null &&
                widget.errorMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: isDark ? Colors.white : const Color(0xFFDC2626),
                      size: 20,
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

            const SizedBox(height: 22),

            // Botão Principal de Login / Cadastro (Bloco realçado)
            FilledButton.icon(
              onPressed: widget.isLoading ? null : _submit,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isSignUp
                          ? Icons.person_add_alt_1_rounded
                          : Icons.login_rounded,
                      size: 19,
                    ),
              label: Text(
                widget.isLoading
                    ? 'Conectando...'
                    : (_isSignUp ? 'Criar conta' : 'Entrar com email'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: SaaSColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                shadowColor: SaaSColors.primary.withValues(alpha: 0.4),
              ),
            ),

            const SizedBox(height: 18),

            // Divisor "ou acesse rapidamente"
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou acesse com',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    thickness: 1,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Botão Google (Bloco realçado com contorno evidente)
            IgnorePointer(
              ignoring: widget.isLoading,
              child: Opacity(
                opacity: widget.isLoading ? 0.5 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: buildGoogleLoginButton(
                    onPressed: widget.onGoogleLogin,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Alternador de modo (Entrar / Criar conta)
            OutlinedButton(
              onPressed: widget.isLoading
                  ? null
                  : () => setState(() => _isSignUp = !_isSignUp),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isSignUp
                    ? 'Já tem conta? Entrar'
                    : 'Ainda não tem conta? Criar cadastro',
                style: TextStyle(
                  color: isDark ? const Color(0xFF93C5FD) : SaaSColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ).saasFadeIn(duration: 350.ms);
  }

  // Decoração de campos com blocos contrastantes e bordas nítidas
  InputDecoration _buildInputDecoration({
    required bool isDark,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        fontSize: 13.5,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(
          prefixIcon,
          color: SaaSColors.primary,
          size: 20,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 2.0,
        ),
      ),
    );
  }
}
