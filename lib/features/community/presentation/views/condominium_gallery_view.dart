import 'package:flutter/material.dart';
import '../../data/community_api.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import '../dialogs/upload_condominium_image_dialog.dart';

class CondominiumGalleryView extends StatefulWidget {
  const CondominiumGalleryView({
    super.key,
    required this.condominiumId,
    required this.api,
    this.canManage = false,
  });

  final num condominiumId;
  final CommunityApi api;
  final bool canManage;

  @override
  State<CondominiumGalleryView> createState() => _CondominiumGalleryViewState();
}

class _CondominiumGalleryViewState extends State<CondominiumGalleryView> {
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _commonAreas = [];
  num? _selectedAreaFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getGalleryImages(widget.condominiumId),
        _loadCommonAreas(),
      ]);
      if (!mounted) return;
      setState(() {
        _images = results[0];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadCommonAreas() async {
    try {
      final res = await widget.api.api.get('/condominiums/${widget.condominiumId}/common-areas');
      if (res is List) {
        final list = res.whereType<Map<String, dynamic>>().toList();
        _commonAreas = list;
        return list;
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> get _filteredImages {
    if (_selectedAreaFilter == null) return _images;
    return _images.where((img) => img['commonAreaId'] == _selectedAreaFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
            const SizedBox(height: 10),
            Text('Erro ao carregar galeria: $_error'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-bar with title, filter and upload button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todas as Fotos'),
                        selected: _selectedAreaFilter == null,
                        onSelected: (val) => setState(() => _selectedAreaFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ..._commonAreas.map((area) {
                        final isSelected = _selectedAreaFilter == area['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(area['name']?.toString() ?? 'Área'),
                            selected: isSelected,
                            onSelected: (val) => setState(() => _selectedAreaFilter = val ? area['id'] as num? : null),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (widget.canManage) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                  onPressed: _openUploadDialog,
                  icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                  label: const Text('Adicionar Foto'),
                ),
              ],
            ],
          ),
        ),

        // Gallery grid
        Expanded(
          child: _filteredImages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 52, color: theme.disabledColor),
                      const SizedBox(height: 14),
                      Text(
                        _selectedAreaFilter != null
                            ? 'Nenhuma imagem cadastrada para esta área comum.'
                            : 'Nenhuma foto publicada na galeria ainda.',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 14.5),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.canManage) ...[
                        const SizedBox(height: 14),
                        FilledButton.tonalIcon(
                          onPressed: _openUploadDialog,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Subir primeira imagem'),
                        ),
                      ],
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 600
                        ? 3
                        : 2;

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: _filteredImages.length,
                      itemBuilder: (context, i) {
                        final img = _filteredImages[i];
                        final title = img['title']?.toString() ?? '';
                        final desc = img['description']?.toString() ?? '';
                        final path = img['imagePath']?.toString() ?? '';
                        final areaName = img['commonAreaName']?.toString();
                        final imgId = img['id'] as num?;

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (path.isNotEmpty) {
                                showFullScreenImage(context, imageSource: path, title: title);
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildImageThumbnail(path),
                                      if (areaName != null && areaName.isNotEmpty)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              areaName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (widget.canManage && imgId != null)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.black54,
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                                              onPressed: () => _deleteImage(imgId),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          desc,
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(String path) {
    if (path.isEmpty) {
      return Container(
        color: const Color(0xFFE2E8F0),
        child: const Icon(Icons.image_outlined, size: 36, color: Color(0xFF94A3B8)),
      );
    }
    final url = path.startsWith('http')
        ? path
        : 'http://localhost:8080/${path.startsWith('/') ? path.substring(1) : path}';

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.broken_image_outlined, size: 36, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Future<void> _openUploadDialog() async {
    await showDialog(
      context: context,
      builder: (context) => UploadCondominiumImageDialog(
        condominiumId: widget.condominiumId,
        commonAreas: _commonAreas,
        api: widget.api,
        preselectedAreaId: _selectedAreaFilter,
        onUploaded: _load,
      ),
    );
  }

  Future<void> _deleteImage(num imgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover foto da galeria?'),
        content: const Text('Esta imagem será excluída permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.api.deleteGalleryImage(widget.condominiumId, imgId);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }
}
