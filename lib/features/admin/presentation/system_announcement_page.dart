import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../home/data/home_service.dart';

class SystemAnnouncementPage extends StatefulWidget {
  const SystemAnnouncementPage({super.key, required this.api});
  final HomeService api;
  @override
  State<SystemAnnouncementPage> createState() => _SystemAnnouncementPageState();
}

class _SystemAnnouncementPageState extends State<SystemAnnouncementPage> {
  final _title = TextEditingController(), _message = TextEditingController();
  String? _image;
  bool _sending = false;
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
          const SnackBar(content: Text('A imagem deve ter até 1 MB.')),
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
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) return;
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
            content: Text('Aviso enviado para ${count ?? 'todos'} usuários.'),
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
    appBar: AppBar(title: const Text('Aviso geral do sistema')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _title,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          maxLines: 6,
          maxLength: 5000,
          decoration: const InputDecoration(
            labelText: 'Mensagem',
            alignLabelWithHint: true,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image_outlined),
          label: Text(_image == null ? 'Adicionar imagem' : 'Trocar imagem'),
        ),
        if (_image != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Image.memory(
              base64Decode(_image!.split(',').last),
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.campaign_outlined),
          label: Text(_sending ? 'Enviando…' : 'Enviar para todos os usuários'),
        ),
      ],
    ),
  );
}
