import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/data/home_service.dart';
import '../widgets/google_login_button.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.token,
    required this.userName,
    required this.userEmail,
    required this.provider,
    required this.onLogout,
    required this.onClose,
    required this.reauthenticateWithGoogle,
    required this.refreshWithCredentials,
    required this.refreshGoogleSession,
  });

  final String? token;
  final String? userName;
  final String? userEmail;
  final String provider;
  final Future<void> Function() onLogout;
  final VoidCallback onClose;
  final Future<String> Function() reauthenticateWithGoogle;
  final Future<void> Function(String email, String password)
  refreshWithCredentials;
  final Future<void> Function() refreshGoogleSession;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late HomeService _api = HomeService(token: widget.token);
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _api = HomeService(token: widget.token);
      _load();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _api.get('/users/me') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name.text =
            '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
        _email.text = profile['email']?.toString() ?? widget.userEmail ?? '';
        _profileImage = profile['profileImage'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _name.text = widget.userName ?? '';
        _email.text = widget.userEmail ?? '';
        _loading = false;
      });
      _message('Não foi possível carregar os dados atuais da conta.');
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _reauthenticate({required String action}) async {
    if (widget.provider == 'google') {
      if (kIsWeb) {
        return showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Confirme sua conta Google para $action'),
            content: SizedBox(
              width: 320,
              child: buildGoogleLoginButton(
                onPressed: () async {
                  try {
                    final token = await widget.reauthenticateWithGoogle();
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, token);
                    }
                  } catch (error) {
                    _message(error.toString());
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      }
      try {
        return await widget.reauthenticateWithGoogle();
      } catch (error) {
        _message(error.toString());
        return null;
      }
    }
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirme sua senha para $action'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Sua senha atual',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password?.isNotEmpty == true ? password : null;
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1024,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _message('Escolha uma imagem de até 5 MB.');
        return;
      }
      final extension = file.name.toLowerCase().split('.').last;
      final mime = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      setState(
        () => _profileImage = 'data:$mime;base64,${base64Encode(bytes)}',
      );
    } catch (error) {
      _message('Não foi possível abrir a galeria: $error');
    }
  }

  Future<void> _removeImage() async {
    setState(() => _profileImage = null);
  }

  Future<void> _saveProfile() async {
    final parts = _name.text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty || !_email.text.contains('@')) {
      _message('Informe um nome e um e-mail válidos.');
      return;
    }
    final changingEmail =
        _email.text.trim().toLowerCase() !=
        (widget.userEmail ?? '').toLowerCase();
    String? password;
    String? googleIdToken;
    if (changingEmail) {
      final proof = await _reauthenticate(action: 'alterar o e-mail');
      if (proof == null) return;
      if (widget.provider == 'google') {
        googleIdToken = proof;
      } else {
        password = proof;
      }
    }
    setState(() => _saving = true);
    try {
      await _api.send(
        'PUT',
        '/users/me/profile',
        body: {
          'firstName': parts.first,
          'lastName': parts.skip(1).join(' '),
          'email': _email.text.trim(),
          'profileImage': _profileImage,
          'currentPassword': password,
          'googleIdToken': googleIdToken,
        },
      );
      final updatedProfile = await _api.get('/users/me') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _profileImage = updatedProfile['profileImage'] as String?;
        });
      }
      if (changingEmail) {
        if (widget.provider == 'google') {
          await widget.refreshGoogleSession();
        } else {
          await widget.refreshWithCredentials(_email.text.trim(), password!);
        }
      }
      _message('Seus dados foram atualizados com sucesso!');
      if (changingEmail) widget.onClose();
    } catch (error) {
      _message('Não foi possível salvar o perfil: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassword = TextEditingController();
    final confirmation = TextEditingController();
    final currentPassword = TextEditingController();
    final values = await showDialog<List<String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar senha de acesso'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.provider != 'google') ...[
                TextField(
                  controller: currentPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha atual',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova senha (mín. 8 caracteres)',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirme a nova senha',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              currentPassword.text,
              newPassword.text,
              confirmation.text,
            ]),
            child: const Text('Atualizar senha'),
          ),
        ],
      ),
    );
    if (values == null) return;
    if (values[1].length < 8 || values[1] != values[2]) {
      _message(
        'A nova senha deve ter pelo menos 8 caracteres e as confirmações devem coincidir.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{'newPassword': values[1]};
      if (widget.provider == 'google') {
        final proof = await _reauthenticate(action: 'alterar a senha');
        if (proof == null) return;
        body['googleIdToken'] = proof;
      } else {
        body['currentPassword'] = values[0];
      }
      await _api.send('POST', '/users/me/password', body: body);
      if (widget.provider == 'google') {
        await widget.refreshGoogleSession();
      } else {
        await widget.refreshWithCredentials(_email.text.trim(), values[1]);
      }
      _message('Senha alterada com sucesso!');
      widget.onClose();
    } catch (error) {
      _message('Não foi possível alterar a senha: $error');
    } finally {
      currentPassword.dispose();
      newPassword.dispose();
      confirmation.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: SaaSColors.background(isDark),
      appBar: AppBar(
        title: const Text('Meu perfil e conta'),
        elevation: 0,
        backgroundColor: SaaSColors.surface(isDark),
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: widget.onClose,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return _buildDesktopLayout(isDark);
                }
                return _buildMobileLayout(isDark);
              },
            ),
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (2 Columns, Contained)
  // ==========================================
  Widget _buildDesktopLayout(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Avatar & Account Summary
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildIdentityCard(isDark),
                    const SizedBox(height: 16),
                    _buildSecurityCard(isDark),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right Column: Personal Information Form
              Expanded(
                flex: 6,
                child: _buildDetailsCard(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE LAYOUT (Single Column, Scrollable)
  // ==========================================
  Widget _buildMobileLayout(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildIdentityCard(isDark),
            const SizedBox(height: 16),
            _buildDetailsCard(isDark),
            const SizedBox(height: 16),
            _buildSecurityCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(bool isDark) {
    return SaaSCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              UserAvatar(
                imageSource: _profileImage,
                name: _name.text,
                radius: 52,
                onTap: (_profileImage != null && _profileImage!.trim().isNotEmpty)
                    ? () => showFullScreenImage(
                          context,
                          imageSource: _profileImage!,
                          title: _name.text,
                        )
                    : null,
                tooltip: (_profileImage != null && _profileImage!.trim().isNotEmpty)
                    ? 'Ver foto em tela cheia'
                    : null,
              ),
              IconButton.filled(
                onPressed: _pickImage,
                tooltip: 'Alterar foto de perfil',
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: SaaSColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_profileImage != null && _profileImage!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _removeImage,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remover foto'),
              style: TextButton.styleFrom(
                foregroundColor: SaaSColors.error,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            _name.text.isEmpty ? 'Seu perfil' : _name.text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SaaSColors.textPrimary(isDark),
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _email.text,
            style: TextStyle(
              fontSize: 13,
              color: SaaSColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SaaSBadge(
            label: widget.provider == 'google'
                ? 'Conectado via Google'
                : 'Acesso por e-mail e senha',
            icon: widget.provider == 'google'
                ? Icons.g_mobiledata_rounded
                : Icons.badge_outlined,
            variant: SaaSBadgeVariant.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(bool isDark) {
    return SaaSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SaaSSectionHeader(
            title: 'Informações Pessoais',
            subtitle: 'Atualize seus dados de cadastro e foto de exibição',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nome de exibição',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail da conta',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              _saving ? 'Salvando alterações…' : 'Salvar alterações',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: SaaSColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(bool isDark) {
    return SaaSCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: SaaSColors.primary,
                size: 20,
              ),
            ),
            title: const Text(
              'Alterar minha senha',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              widget.provider == 'google'
                  ? 'Confirme sua conta Google para definir uma nova senha'
                  : 'Confirme sua senha atual para atualizar o acesso',
              style: TextStyle(
                fontSize: 12,
                color: SaaSColors.textSecondary(isDark),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _saving ? null : _changePassword,
          ),
          Divider(height: 1, color: SaaSColors.border(isDark)),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: SaaSColors.error,
                size: 20,
              ),
            ),
            title: const Text(
              'Sair da conta',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: SaaSColors.error,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Encerrar sessão atual neste dispositivo',
              style: TextStyle(
                fontSize: 12,
                color: SaaSColors.textSecondary(isDark),
              ),
            ),
            onTap: _saving ? null : widget.onLogout,
          ),
        ],
      ),
    );
  }
}
