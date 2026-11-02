import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/community_api.dart';

class UploadCondominiumImageDialog extends StatefulWidget {
  const UploadCondominiumImageDialog({
    super.key,
    required this.condominiumId,
    required this.commonAreas,
    required this.api,
    required this.onUploaded,
    this.preselectedAreaId,
  });

  final num condominiumId;
  final List<Map<String, dynamic>> commonAreas;
  final CommunityApi api;
  final VoidCallback onUploaded;
  final num? preselectedAreaId;

  @override
  State<UploadCondominiumImageDialog> createState() =>
      _UploadCondominiumImageDialogState();
}

class _UploadCondominiumImageDialogState
    extends State<UploadCondominiumImageDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  num? _selectedAreaId;
  String? _base64Image;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedAreaId = widget.preselectedAreaId;
    if (_selectedAreaId != null) {
      final area = widget.commonAreas.firstWhere(
        (a) => a['id'] == _selectedAreaId,
        orElse: () => {},
      );
      if (area['name'] != null) {
        _titleCtrl.text = area['name'].toString();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nova Imagem do Condomínio',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Adicione fotos para os moradores e visitantes verem',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Area selector
                const Text(
                  'Vincular à Área Comum (Opcional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<num?>(
                  value: _selectedAreaId,
                  items: [
                    const DropdownMenuItem<num?>(
                      value: null,
                      child: Text('Foto Geral do Condomínio'),
                    ),
                    ...widget.commonAreas.map(
                      (a) => DropdownMenuItem<num?>(
                        value: a['id'] as num?,
                        child: Text(a['name']?.toString() ?? 'Área'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedAreaId = val;
                      if (val != null) {
                        final area = widget.commonAreas.firstWhere(
                          (a) => a['id'] == val,
                          orElse: () => {},
                        );
                        if (area['name'] != null && _titleCtrl.text.isEmpty) {
                          _titleCtrl.text = area['name'].toString();
                        }
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                const Text(
                  'Título da Imagem',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Salão de Festas Principal ou Piscina Adulto',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                const Text(
                  'Descrição / Detalhes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        'Ex: Espaço climatizado com churrasqueira, freezer e mesas para até 60 pessoas.',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Image preview & pick button
                const Text(
                  'Arquivo de Imagem',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (_base64Image != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          base64Decode(_base64Image!.split(',').last),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            onPressed: () => setState(() => _base64Image = null),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Clique para selecionar uma foto (JPG, PNG ou WEBP)',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      _submitting
                          ? 'Enviando imagem...'
                          : 'Publicar Imagem na Galeria',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        setState(() => _error = 'Escolha uma imagem de até 8 MB.');
        return;
      }
      final ext = file.name.toLowerCase().split('.').last;
      final mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      setState(() {
        _base64Image = 'data:$mime;base64,${base64Encode(bytes)}';
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Não foi possível carregar a imagem: $e');
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Informe um título para a imagem.');
      return;
    }
    if (_base64Image == null) {
      setState(() => _error = 'Selecione uma foto para enviar.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.api.addGalleryImage(
        widget.condominiumId,
        title: title,
        description: _descCtrl.text.trim(),
        image: _base64Image!,
        commonAreaId: _selectedAreaId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagem adicionada à galeria com sucesso!'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
      Navigator.of(context).pop();
      widget.onUploaded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Erro ao salvar imagem: $e';
      });
    }
  }
}
