import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

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
          decoration: const InputDecoration(labelText: 'Senha atual'),
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
      if (bytes.length > 1024 * 1024) {
        _message('Escolha uma imagem de até 1 MB.');
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

  Future<void> _saveProfile() async {
    final parts = _name.text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty || !_email.text.contains('@')) {
      _message('Informe um nome e um email válidos.');
      return;
    }
    final changingEmail =
        _email.text.trim().toLowerCase() !=
        (widget.userEmail ?? '').toLowerCase();
    String? password;
    String? googleIdToken;
    if (changingEmail) {
      final proof = await _reauthenticate(action: 'alterar o email');
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
      if (changingEmail) {
        if (widget.provider == 'google') {
          await widget.refreshGoogleSession();
        } else {
          await widget.refreshWithCredentials(_email.text.trim(), password!);
        }
      }
      _message('Perfil atualizado.');
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
        title: const Text('Alterar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.provider != 'google')
              TextField(
                controller: currentPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha atual'),
              ),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova senha (mín. 8 caracteres)',
              ),
            ),
            TextField(
              controller: confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirme a nova senha',
              ),
            ),
          ],
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
            child: const Text('Salvar'),
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
      _message('Senha alterada.');
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

  ImageProvider? get _avatarImage {
    final image = _profileImage;
    if (image == null || image.isEmpty) return null;
    try {
      if (image.startsWith('data:')) {
        return MemoryImage(base64Decode(image.split(',').last));
      }
      return NetworkImage(image);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FC),
    appBar: AppBar(
      title: const Text('Minha conta'),
      backgroundColor: const Color(0xFF2F3FB0),
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Voltar',
        onPressed: widget.onClose,
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundImage: _avatarImage,
                            child: _avatarImage == null
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                          IconButton.filled(
                            onPressed: _pickImage,
                            tooltip: 'Trocar foto',
                            icon: const Icon(Icons.camera_alt),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _name.text.isEmpty ? 'Seu perfil' : _name.text,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _email.text,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Dados da conta',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Salvando…' : 'Salvar perfil'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Alterar senha'),
                      subtitle: Text(
                        widget.provider == 'google'
                            ? 'Confirme sua conta Google para continuar'
                            : 'Confirme sua senha atual para continuar',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving ? null : _changePassword,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Sair da conta'),
                      onTap: _saving ? null : widget.onLogout,
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
