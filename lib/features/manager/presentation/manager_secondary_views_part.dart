part of 'manager_page.dart';

class _ManagerUnitsMenuPage extends StatefulWidget {
  const _ManagerUnitsMenuPage({
    super.key,
    required this.units,
    required this.onEditPayment,
    this.isEmbedded = false,
  });

  final List<Map<String, dynamic>> units;
  final Future<bool> Function(Map<String, dynamic> unit) onEditPayment;
  final bool isEmbedded;

  @override
  State<_ManagerUnitsMenuPage> createState() => _ManagerUnitsMenuPageState();
}

class _ManagerUnitsMenuPageState extends State<_ManagerUnitsMenuPage> {
  String _query = '';

  (String, Color, Color) _statusStyle(dynamic status, bool isDark) =>
      switch (status) {
        'PAID' => (
          'Pago (em dia)',
          isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.18)
              : const Color(0xFFDCFCE7),
          isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
        ),
        'CONFIRMATION_REQUESTED' => (
          'Comprovante enviado / Aguardando confirmação',
          isDark
              ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
              : const Color(0xFFFEF3C7),
          isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        ),
        'PENDING' => (
          'Pendente',
          isDark
              ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
              : const Color(0xFFFEF3C7),
          isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        ),
        'OVERDUE' => (
          'Atrasado',
          isDark
              ? const Color(0xFFEF4444).withValues(alpha: 0.18)
              : const Color(0xFFFEE2E2),
          isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        ),
        _ => (
          'Sem lançamento',
          SaaSColors.surfaceSubtle(isDark),
          SaaSColors.textSecondary(isDark),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.units
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            EnterSearchField(
              hintText: 'Pesquisar unidades ou setores (Enter)',
              onSubmitted: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhuma unidade encontrada.'),
                ),
              )
            else
              ...filtered.map((unit) {
                final (label, bg, fg) =
                    _statusStyle(unit['paymentStatus'], isDark);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: bg,
                      child: Icon(Icons.home_outlined, color: fg, size: 20),
                    ),
                    title: Text(
                      '${unit['sector']} • Unidade ${unit['identifier']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('Situação financeira: $label'),
                    trailing:
                        unit['paymentStatus'] == 'CONFIRMATION_REQUESTED'
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final updated = await widget.onEditPayment({
                                    ...unit,
                                    'paymentStatus': 'PAID',
                                  });
                                  if (updated &&
                                      context.mounted &&
                                      !widget.isEmbedded) {
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: const Text('Confirmar Pagamento'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final updated = await widget.onEditPayment(
                                    unit,
                                  );
                                  if (updated &&
                                      context.mounted &&
                                      !widget.isEmbedded) {
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                ),
                                label: const Text('Editar'),
                              ),
                            ],
                          )
                        : OutlinedButton.icon(
                            onPressed: () async {
                              final updated = await widget.onEditPayment(
                                unit,
                              );
                              if (updated &&
                                  context.mounted &&
                                  !widget.isEmbedded) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Atualizar'),
                          ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
    if (widget.isEmbedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Unidades cadastradas')),
      body: content,
    );
  }
}

class _ManagerReservationsMenuPage extends StatefulWidget {
  const _ManagerReservationsMenuPage({
    super.key,
    required this.api,
    required this.reservations,
    this.isEmbedded = false,
    this.onChanged,
  });

  final HomeService api;
  final List<Map<String, dynamic>> reservations;
  final bool isEmbedded;
  final VoidCallback? onChanged;

  @override
  State<_ManagerReservationsMenuPage> createState() =>
      _ManagerReservationsMenuPageState();
}

class _ManagerReservationsMenuPageState
    extends State<_ManagerReservationsMenuPage> {
  String _query = '';
  String _selectedTab = 'SCHEDULED'; // 'SCHEDULED', 'PAST', 'CANCELLED'

  String _formatDateTime(dynamic dateTimeString) {
    if (dateTimeString == null) return '';
    return formatDateTime(dateTimeString, fallback: dateTimeString.toString());
  }

  bool _isCancelled(Map<String, dynamic> r) {
    final status = r['status']?.toString().toUpperCase();
    return status == 'CANCELLED' || status == 'REJECTED';
  }

  bool _isPast(Map<String, dynamic> r) {
    if (_isCancelled(r)) return false;
    final endAt = r['endAt'];
    if (endAt == null) return false;
    try {
      final dt = parseUtcToLocal(endAt);
      if (dt == null) return false;
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  bool _isScheduled(Map<String, dynamic> r) {
    return !_isCancelled(r) && !_isPast(r);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allFiltered = widget.reservations
        .where((item) => recordMatchesQuery(item, _query))
        .toList();

    final scheduled = allFiltered.where(_isScheduled).toList();
    final past = allFiltered.where(_isPast).toList();
    final cancelled = allFiltered.where(_isCancelled).toList();

    final currentList = switch (_selectedTab) {
      'PAST' => past,
      'CANCELLED' => cancelled,
      _ => scheduled,
    };

    final listBody = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(18),
            children: [
              EnterSearchField(
                hintText: 'Pesquisar reservas por área ou morador (Enter)',
                onSubmitted: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              // Segmented Category Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Agendadas (${scheduled.length})'),
                      selected: _selectedTab == 'SCHEDULED',
                      onSelected: (val) {
                        if (val) setState(() => _selectedTab = 'SCHEDULED');
                      },
                      avatar: const Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Já passaram (${past.length})'),
                      selected: _selectedTab == 'PAST',
                      onSelected: (val) {
                        if (val) setState(() => _selectedTab = 'PAST');
                      },
                      avatar: const Icon(Icons.history_rounded, size: 16),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        'Canceladas (${cancelled.length})',
                        style: TextStyle(
                          color: _selectedTab == 'CANCELLED'
                              ? Colors.white
                              : const Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: _selectedTab == 'CANCELLED',
                      selectedColor: const Color(0xFFDC2626),
                      backgroundColor: isDark
                          ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                          : const Color(0xFFFEE2E2),
                      side: BorderSide(
                        color: _selectedTab == 'CANCELLED'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFFCA5A5),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedTab = 'CANCELLED');
                      },
                      avatar: Icon(
                        Icons.cancel_outlined,
                        size: 16,
                        color: _selectedTab == 'CANCELLED'
                            ? Colors.white
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (currentList.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Text(
                        _selectedTab == 'CANCELLED'
                            ? 'Nenhuma reserva cancelada.'
                            : _selectedTab == 'PAST'
                            ? 'Nenhuma reserva finalizada.'
                            : 'Nenhuma reserva agendada no momento.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...currentList.map((reservation) {
                  final status = reservation['status']?.toString();
                  final isItemCancelled = _isCancelled(reservation);

                  return Card(
                    color: isItemCancelled
                        ? (isDark
                              ? const Color(0xFF450A0A).withValues(alpha: 0.35)
                              : const Color(0xFFFEF2F2))
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isItemCancelled
                            ? const Color(0xFFFCA5A5)
                            : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                        width: isItemCancelled ? 1.5 : 1.0,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: (reservation['imageUrl'] != null &&
                                  reservation['imageUrl']
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                              ? SmartImage(
                                  source: reservation['imageUrl'].toString(),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  placeholderIcon: isItemCancelled
                                      ? Icons.cancel_outlined
                                      : Icons.event_available_outlined,
                                )
                              : CircleAvatar(
                                  backgroundColor: isItemCancelled
                                      ? (isDark
                                            ? const Color(0xFF7F1D1D)
                                            : const Color(0xFFFEE2E2))
                                      : (isDark
                                            ? const Color(0xFF1E3A8A)
                                            : const Color(0xFFE0E7FF)),
                                  child: Icon(
                                    isItemCancelled
                                        ? Icons.cancel_outlined
                                        : Icons.event_available_outlined,
                                    color: isItemCancelled
                                        ? const Color(0xFFDC2626)
                                        : SaaSColors.primary,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        '${reservation['commonArea']} • ${reservation['residentName']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isItemCancelled
                              ? const Color(0xFFB91C1C)
                              : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '${_formatDateTime(reservation['startAt'])} até ${_formatDateTime(reservation['endAt'])}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${reservation['residentEmail']}${reservation['contactPhone'] != null && reservation['contactPhone'].toString().isNotEmpty ? ' • ${formatPhone(reservation['contactPhone']?.toString())}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (isItemCancelled) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFF87171),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cancel_rounded,
                                    size: 13,
                                    color: Color(0xFFDC2626),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'CANCELADA / RECUSADA',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10.5,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      isThreeLine: true,
                      trailing: status == 'PENDING'
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF15803D),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                    onPressed: () async {
                                      await widget.api.send(
                                        'PATCH',
                                        '/reservations/${reservation['id']}/approve',
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Aprovar'),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFFEF3C7),
                                      foregroundColor: const Color(0xFFB45309),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final communityApi = CommunityApi(
                                        api: widget.api,
                                      );
                                      await showDialog<void>(
                                        context: context,
                                        builder: (ctx) => CounterProposalDialog(
                                          reservation: reservation,
                                          api: communityApi,
                                          onSubmitted: () {
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                            }
                                          },
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Contraproposta'),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFDC2626),
                                      side: const BorderSide(
                                        color: Color(0xFFFECACA),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final reasonCtrl =
                                          TextEditingController();
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Recusar Solicitação de Reserva',
                                          ),
                                          content: TextField(
                                            controller: reasonCtrl,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Motivo da recusa (opcional)',
                                              hintText:
                                                  'Ex: Espaço em manutenção no período.',
                                            ),
                                            maxLines: 2,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Voltar'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFDC2626,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'Confirmar Recusa',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await widget.api.send(
                                          'PATCH',
                                          '/reservations/${reservation['id']}/reject',
                                          body:
                                              reasonCtrl.text.trim().isNotEmpty
                                              ? {
                                                  'reason': reasonCtrl.text
                                                      .trim(),
                                                }
                                              : null,
                                        );
                                        widget.onChanged?.call();
                                        if (context.mounted &&
                                            !widget.isEmbedded) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Recusar'),
                                  ),
                                ],
                              ),
                            )
                          : (status == 'COUNTER_PROPOSED'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Contraproposta enviada',
                                      style: TextStyle(
                                        color: Color(0xFFB45309),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    if (widget.isEmbedded) return listBody;
    return Scaffold(
      appBar: AppBar(title: const Text('Reservas registradas')),
      body: listBody,
    );
  }
}

class _MainPhotosManagerDialog extends StatefulWidget {
  const _MainPhotosManagerDialog({
    required this.api,
    required this.condominiumId,
    required this.condominiumName,
    this.currentCondoImage,
    required this.onCondoImageUpdated,
  });

  final HomeService api;
  final int condominiumId;
  final String condominiumName;
  final String? currentCondoImage;
  final ValueChanged<String> onCondoImageUpdated;

  @override
  State<_MainPhotosManagerDialog> createState() =>
      _MainPhotosManagerDialogState();
}

class _MainPhotosManagerDialogState extends State<_MainPhotosManagerDialog> {
  String? _condoImg;
  List<Map<String, dynamic>> _commonAreas = [];
  List<Map<String, dynamic>> _sectors = [];
  bool _loadingAreas = true;
  bool _loadingSectors = true;

  @override
  void initState() {
    super.initState();
    _condoImg = widget.currentCondoImage;
    _fetchAreas();
    _fetchSectors();
  }

  Future<void> _fetchAreas() async {
    try {
      final res = await widget.api.get(
        '/condominiums/${widget.condominiumId}/common-areas/all',
      );
      if (mounted) {
        setState(() {
          _commonAreas = res is List
              ? res.whereType<Map<String, dynamic>>().toList()
              : [];
          _loadingAreas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  Future<void> _fetchSectors() async {
    try {
      final res = await widget.api.get(
        '/sectors?condominiumId=${widget.condominiumId}',
      );
      if (mounted) {
        setState(() {
          _sectors = res is List
              ? res.whereType<Map<String, dynamic>>().toList()
              : [];
          _loadingSectors = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSectors = false);
    }
  }

  Future<String?> _pickBase64Image() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> _changeCondoImage() async {
    final dataUri = await _pickBase64Image();
    if (dataUri == null) return;
    try {
      await widget.api.send(
        'PATCH',
        '/condominiums/${widget.condominiumId}/image',
        body: {'imageUrl': dataUri},
      );
      if (mounted) {
        setState(() => _condoImg = dataUri);
        widget.onCondoImageUpdated(dataUri);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto da fachada do condomínio atualizada!'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _changeAreaImage(Map<String, dynamic> area) async {
    final dataUri = await _pickBase64Image();
    if (dataUri == null) return;
    try {
      await widget.api.send(
        'PATCH',
        '/common-areas/${area['id']}/image',
        body: {'imageUrl': dataUri},
      );
      if (mounted) {
        setState(() {
          area['imageUrl'] = dataUri;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto de "${area['name']}" atualizada com sucesso!'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _changeSectorImage(Map<String, dynamic> sector) async {
    final dataUri = await _pickBase64Image();
    if (dataUri == null) return;
    try {
      await widget.api.send(
        'PATCH',
        '/sectors/${sector['id']}/image',
        body: {'imageUrl': dataUri},
      );
      if (mounted) {
        setState(() {
          sector['imageUrl'] = dataUri;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Foto de "${sector['name']}" atualizada com sucesso!',
            ),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Widget _buildPhotoThumbnail(
    String? url,
    IconData fallbackIcon, {
    String? fallbackAsset,
  }) {
    return SmartImage(
      source: url,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(10),
      placeholderIcon: fallbackIcon,
      fallbackAsset: fallbackAsset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.photo_library_outlined,
                        color: SaaSColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fotos Principais do Condomínio',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Personalize as imagens reais de fachada, áreas de lazer e blocos',
                            style: TextStyle(
                              fontSize: 12,
                              color: SaaSColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              TabBar(
                labelColor: SaaSColors.primary,
                unselectedLabelColor: SaaSColors.textSecondary(isDark),
                indicatorColor: SaaSColors.primary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.apartment_rounded, size: 18),
                    text: 'Condomínio',
                  ),
                  Tab(
                    icon: Icon(Icons.deck_rounded, size: 18),
                    text: 'Áreas Comuns',
                  ),
                  Tab(
                    icon: Icon(Icons.business_outlined, size: 18),
                    text: 'Setores / Blocos',
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Fachada
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Foto de Fachada do Condomínio',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Esta foto aparece no topo do menu de todos os moradores e na apresentação do condomínio.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: SaaSColors.textSecondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                alignment: Alignment.center,
                                child:
                                    _condoImg != null && _condoImg!.isNotEmpty
                                    ? SmartImage(
                                        source: _condoImg,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 48,
                                            color: SaaSColors.textSecondary(
                                              isDark,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Nenhuma foto de fachada definida',
                                            style: TextStyle(
                                              color: SaaSColors.textSecondary(
                                                isDark,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: FilledButton.icon(
                              onPressed: _changeCondoImage,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(
                                _condoImg == null
                                    ? 'Definir Foto da Fachada'
                                    : 'Alterar Foto da Fachada',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: Áreas Comuns
                    _loadingAreas
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: SaaSLoadingState(
                              message: 'Carregando áreas comuns...',
                            ),
                          )
                        : _commonAreas.isEmpty
                        ? const SaaSEmptyState(
                            icon: Icons.deck_rounded,
                            title: 'Nenhuma área comum',
                            subtitle:
                                'Nenhuma área comum cadastrada no condomínio.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _commonAreas.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final area = _commonAreas[idx];
                              final img = area['imageUrl']?.toString();
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 52,
                                          height: 52,
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFEFF6FF),
                                          alignment: Alignment.center,
                                          child: _buildPhotoThumbnail(
                                            img,
                                            Icons.deck_rounded,
                                            fallbackAsset:
                                                AppAssets.commonAreaDefault,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              area['name'] ?? 'Área Comum',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Capacidade: ${area['capacity'] ?? 'Livre'} pessoas • ${img != null && img.isNotEmpty ? 'Foto definida' : 'Sem foto cadastrada'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    img != null &&
                                                        img.isNotEmpty
                                                    ? const Color(0xFF15803D)
                                                    : SaaSColors.textSecondary(
                                                        isDark,
                                                      ),
                                                fontWeight:
                                                    img != null &&
                                                        img.isNotEmpty
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () => _changeAreaImage(area),
                                        icon: const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          img == null
                                              ? 'Definir Foto'
                                              : 'Alterar',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                    // Tab 3: Setores / Blocos
                    _loadingSectors
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: SaaSLoadingState(
                              message: 'Carregando setores e blocos...',
                            ),
                          )
                        : _sectors.isEmpty
                        ? const SaaSEmptyState(
                            icon: Icons.view_quilt_outlined,
                            title: 'Nenhum setor ou bloco',
                            subtitle:
                                'Nenhum setor ou bloco cadastrado no condomínio.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _sectors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final sector = _sectors[idx];
                              final img = sector['imageUrl']?.toString();
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 52,
                                          height: 52,
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFEFF6FF),
                                          alignment: Alignment.center,
                                          child: _buildPhotoThumbnail(
                                            img,
                                            Icons.apartment_rounded,
                                            fallbackAsset:
                                                AppAssets.sectorDefault,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sector['name'] ?? 'Setor',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Tipo: ${sector['structuralType'] ?? 'BLOCO'} • ${img != null && img.isNotEmpty ? 'Foto definida' : 'Sem foto cadastrada'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    img != null &&
                                                        img.isNotEmpty
                                                    ? const Color(0xFF15803D)
                                                    : SaaSColors.textSecondary(
                                                        isDark,
                                                      ),
                                                fontWeight:
                                                    img != null &&
                                                        img.isNotEmpty
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _changeSectorImage(sector),
                                        icon: const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          img == null
                                              ? 'Definir Foto'
                                              : 'Alterar',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
}
