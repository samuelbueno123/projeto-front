import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../home/data/home_service.dart';

class SystemAnnouncementPage extends StatefulWidget {
  const SystemAnnouncementPage({super.key, required this.api});
  final HomeService api;
  @override
  State<SystemAnnouncementPage> createState() => _SystemAnnouncementPageState();
}

class _SystemAnnouncementPageState extends State<SystemAnnouncementPage> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String? _image;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1000000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escolha uma imagem leve, com até 1 MB.'),
          ),
        );
      }
      return;
    }
    final name = file.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    setState(() => _image = 'data:$mime;base64,${base64Encode(bytes)}');
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o título e a mensagem antes de publicar.'),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final count = await widget.api.send(
        'POST',
        '/admin/system-announcements',
        body: {
          'title': _title.text.trim(),
          'message': _message.text.trim(),
          'imageUrl': _image,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Comunicado enviado com sucesso para ${count ?? 'todos os'} usuários!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Publicar comunicado geral')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aviso oficial para todas as contas',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Todos os moradores, porteiros e síndicos receberão este comunicado na central de notificações.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _title,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Título do comunicado',
                        hintText: 'Ex.: Manutenção programada no aplicativo',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _message,
                      maxLines: 6,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem detalhada',
                        hintText:
                            'Escreva de forma clara e amigável o aviso que será entregue a todos os usuários...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _sending ? null : _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _image == null
                                ? 'Anexar imagem ilustrativa'
                                : 'Trocar imagem',
                          ),
                        ),
                        if (_image != null) ...[
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: _sending
                                ? null
                                : () => setState(() => _image = null),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Remover',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_image != null) ...[
                      const SizedBox(height: 14),
                      ClickableImagePreview(
                        imageSource: _image!,
                        title: _title.text.trim(),
                        height: 200,
                        borderRadius: 14,
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _sending
                            ? 'Publicando comunicado…'
                            : 'Publicar para todos os usuários',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
