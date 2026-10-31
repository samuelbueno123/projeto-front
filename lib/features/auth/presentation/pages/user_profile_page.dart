import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/full_screen_image_viewer.dart';
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _reauthenticate({required String action}) async {
    if (widget.provider == 'google') {
      if (kIsWeb) {
        return showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Confirme sua conta Google para $action'),
            content: SizedBox(
              width: 300,
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

  ImageProvider? get _avatarImage => resolveAvatarImageProvider(_profileImage);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meu perfil e conta'),
      leading: IconButton(
        tooltip: 'Voltar',
        onPressed: widget.onClose,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureDetector(
                                onTap:
                                    (_profileImage != null &&
                                        _profileImage!.trim().isNotEmpty)
                                    ? () => showFullScreenImage(
                                        context,
                                        imageSource: _profileImage!,
                                        title: _name.text,
                                      )
                                    : null,
                                child: CircleAvatar(
                                  radius: 54,
                                  backgroundColor: const Color(0xFFE0E7FF),
                                  backgroundImage: _avatarImage,
                                  child: _avatarImage == null
                                      ? const Icon(
                                          Icons.person_rounded,
                                          size: 52,
                                          color: Color(0xFF2F3FB0),
                                        )
                                      : null,
                                ),
                              ),
                              IconButton.filled(
                                onPressed: _pickImage,
                                tooltip: 'Alterar foto de perfil',
                                icon: const Icon(Icons.camera_alt_outlined),
                              ),
                            ],
                          ),
                          if (_profileImage != null &&
                              _profileImage!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (_profileImage!.startsWith('media/pictures/'))
                                  Chip(
                                    avatar: const Icon(
                                      Icons.folder_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _profileImage!,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                TextButton.icon(
                                  onPressed: _removeImage,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Remover foto'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            _name.text.isEmpty ? 'Seu perfil' : _name.text,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email.text,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8ECFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.provider == 'google'
                                  ? 'Conectado via Google'
                                  : 'Acesso por e-mail e senha',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2F3FB0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Informações pessoais',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'As fotos de perfil são salvas no servidor em media/pictures e apenas o caminho é registrado no banco de dados.',
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _saving ? null : _saveProfile,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _saving
                                  ? 'Salvando alterações…'
                                  : 'Salvar alterações',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8ECFF),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF2F3FB0),
                            ),
                          ),
                          title: const Text(
                            'Alterar minha senha',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            widget.provider == 'google'
                                ? 'Confirme sua conta Google para definir uma nova senha'
                                : 'Confirme sua senha atual para atualizar o acesso',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _saving ? null : _changePassword,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFEE2E2),
                            child: Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          title: const Text(
                            'Sair da conta',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          subtitle: const Text(
                            'Encerrar sessão atual neste dispositivo',
                          ),
                          onTap: _saving ? null : widget.onLogout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}
