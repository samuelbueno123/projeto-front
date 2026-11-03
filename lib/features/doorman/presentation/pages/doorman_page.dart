import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/widgets/enter_search_field.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import '../../../../core/widgets/role_switcher_pill.dart';
import '../../../announcements/presentation/announcement_composer.dart';
import '../../../auth/presentation/pages/user_profile_page.dart';
import '../../../community/data/community_api.dart';
import '../../../community/presentation/views/doorman_chat_view.dart';
import '../../../community/presentation/views/doorman_community_views.dart';
import '../../../directory/presentation/unit_directory.dart';
import '../../../home/data/home_service.dart';
import '../../../home/presentation/pages/notifications_page.dart';

class DoormanPage extends StatefulWidget {
  const DoormanPage({
    super.key,
    required this.token,
    required this.userName,
    required this.onLogout,
    this.currentRole,
    this.availableRoles = const [],
    this.onSwitchRole,
  });

  final String? token;
  final String? userName;
  final Future<void> Function() onLogout;
  final String? currentRole;
  final List<String> availableRoles;
  final ValueChanged<String>? onSwitchRole;

  @override
  State<DoormanPage> createState() => _DoormanPageState();
}

class _DoormanPageState extends State<DoormanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);
  DirectoryApi? _directory;
  late final HomeService _api;
  late final CommunityApi _communityApi;
  List<Map<String, dynamic>> _condominiums = [];
  Map<String, dynamic>? _selectedCondominium;
  List<Map<String, dynamic>> _packages = [];
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  String? _error;
  String _query = '';
  StreamSubscription<RealtimeEvent>? _sseSub;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    _api = HomeService(token: widget.token);
    _communityApi = CommunityApi(api: _api);
    if (widget.token != null && widget.token!.isNotEmpty) {
      RealtimeService.instance.setToken(widget.token);
      _sseSub = RealtimeService.instance.events.listen((event) {
        if (event.type == 'PACKAGE_UPDATED') {
          _loadPackages();
        }
      });
    }
    _loadProfile();
    _loadCondominiums();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.get('/users/me');
      if (mounted && data is Map<String, dynamic>) {
        setState(() => _profile = data);
      }
    } catch (_) {}
  }

  ImageProvider? get _profileAvatarImage =>
      resolveAvatarImageProvider(_profile['profileImage'] as String?);

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          token: widget.token,
          userName: widget.userName,
          userEmail: _profile['email'] as String?,
          provider: 'password',
          onLogout: widget.onLogout,
          onClose: () {
            Navigator.of(context).pop();
            _loadProfile();
          },
          reauthenticateWithGoogle: () async => '',
          refreshWithCredentials: (_, __) async {},
          refreshGoogleSession: () async {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _selectCondominium(Map<String, dynamic>? condominium) {
    _selectedCondominium = condominium;
    final id = (condominium?['id'] as num?)?.toInt();
    _directory = id == null ? null : DirectoryApi(api: _api, condominiumId: id);
  }

  Future<void> _loadCondominiums() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final memberships = await _api.get('/memberships/my');
      final list = memberships is List
          ? memberships.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      final condos = <Map<String, dynamic>>[];
      for (final m in list) {
        final condoId = m['condominiumId'];
        if (condoId != null) {
          try {
            final condo = await _api.get('/condominiums/$condoId');
            if (condo is Map<String, dynamic>) {
              condos.add(condo);
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _condominiums = condos;
          if (_condominiums.isNotEmpty) {
            _selectCondominium(_condominiums.first);
            _loadPackages();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar os condomínios associados.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPackages() async {
    if (_selectedCondominium == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final condoId = _selectedCondominium!['id'];
      final response = await _api.get(
        '/packages?condominiumId=$condoId&page=0&size=100&sort=id,desc',
      );

      List<Map<String, dynamic>> packages = [];
      if (response is Map && response['content'] is List) {
        packages = (response['content'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } else if (response is List) {
        packages = response.whereType<Map<String, dynamic>>().toList();
      }

      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar as encomendas deste condomínio.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePackageStatus(int packageId, String action) async {
    try {
      await _api.send('PATCH', '/packages/$packageId/$action');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status da encomenda atualizado com sucesso!'),
          ),
        );
        _loadPackages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Starts a package registration. When [unit]/[resident] are given (for
  /// instance from the "+" button in the directory) they are pre-filled;
  /// otherwise the doorman first searches the unit and picks the resident.
  Future<void> _registerReceivedPackage({
    Map<String, dynamic>? unit,
    Map<String, dynamic>? resident,
  }) async {
    final directory = _directory;
    if (directory == null) return;

    if (unit == null) {
      final selection = await showUnitResidentPicker(
        context,
        directory: directory,
        title: 'Para qual unidade é a encomenda?',
      );
      if (selection == null || !mounted) return;
      unit = selection.unit;
      resident = selection.resident;
    }

    final descriptionController = TextEditingController();
    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF2F3FB0),
                ),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Registrar nova encomenda')),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.home_work_outlined),
                    title: Text(unitLabel(unit!)),
                    subtitle: Text(
                      resident == null
                          ? 'Sem destinatário específico'
                          : 'Destinatário: ${resident['name']}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Descrição da encomenda *',
                      hintText: 'Ex.: Caixa Mercado Livre / Envelope bancário',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: descriptionController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      descriptionController.text.trim(),
                    ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Registrar na portaria'),
            ),
          ],
        ),
      ),
    );
    descriptionController.dispose();

    if (description == null || !mounted) return;

    try {
      final body = {
        'condominiumId': _selectedCondominium!['id'],
        'description': description,
        'unitId': unit['id'],
        if (resident != null) 'recipientId': resident['userId'],
      };
      await _api.send('POST', '/packages', body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encomenda registrada com sucesso na portaria!'),
          ),
        );
        _tabs.animateTo(0);
      }
      _loadPackages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Sends an announcement to one unit (picked by the doorman when [unit] is null).
  Future<void> _sendAnnouncement({Map<String, dynamic>? unit}) async {
    final directory = _directory;
    if (directory == null) return;
    final sent = await showAnnouncementComposer(
      context,
      api: _api,
      directory: directory,
      allowCondominiumWide: false,
      initialUnit: unit,
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comunicado enviado à unidade!')),
      );
    }
  }

  Future<void> _quickPickupByPin() async {
    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0F766E)),
            SizedBox(width: 10),
            Text('Baixa por PIN ou QR Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digite o código PIN (ou ID) informado pelo morador:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(color: Colors.black26),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Retirada'),
          ),
        ],
      ),
    );
    if (ok == true && pinCtrl.text.trim().isNotEmpty) {
      final raw = pinCtrl.text.trim();
      final parsedId = int.tryParse(raw);
      final matching = _packages.firstWhere(
        (p) => p['id'] == parsedId || p['id']?.toString() == raw || p['trackingCode']?.toString().toUpperCase() == raw.toUpperCase(),
        orElse: () => {},
      );
      final targetId = (matching['id'] as num?)?.toInt() ?? parsedId;
      if (targetId != null) {
        try {
          await _updatePackageStatus(targetId, 'pick-up');
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código PIN não encontrado para as encomendas deste condomínio.')),
          );
        }
      }
    }
  }

  (String, Color, Color) _statusBadge(String? status) => switch (status) {
    'EXPECTED' => (
      'Aguardando chegada',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'RECEIVED' => (
      'Recebida na portaria',
      const Color(0xFFDBEAFE),
      const Color(0xFF1D4ED8),
    ),
    'NOTIFIED' => (
      'Morador avisado',
      const Color(0xFFE0E7FF),
      const Color(0xFF2F3FB0),
    ),
    'PICKED_UP' || 'DELIVERED' => (
      'Entregue ao morador',
      const Color(0xFFDCFCE7),
      const Color(0xFF15803D),
    ),
    'RETURNED' => (
      'Devolvida ao remetente',
      const Color(0xFFFFEDD5),
      const Color(0xFFC2410C),
    ),
    'CANCELLED' => (
      'Cancelada',
      const Color(0xFFFEE2E2),
      const Color(0xFFB91C1C),
    ),
    _ => (
      status ?? 'Em andamento',
      const Color(0xFFF1F5F9),
      const Color(0xFF334155),
    ),
  };

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _buildStatusActions(Map<String, dynamic> pkg) {
    final status = pkg['status'] as String?;
    final id = (pkg['id'] as num).toInt();

    if (status == 'EXPECTED') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _updatePackageStatus(id, 'receive'),
            icon: const Icon(Icons.download_done_rounded, size: 18),
            label: const Text('Confirmar chegada'),
          ),
          OutlinedButton.icon(
            onPressed: () => _updatePackageStatus(id, 'cancel'),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancelar'),
          ),
        ],
      );
    } else if (status == 'RECEIVED') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _updatePackageStatus(id, 'notify'),
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Avisar morador'),
          ),
          FilledButton.icon(
            onPressed: () => _updatePackageStatus(id, 'pickup'),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Registrar entrega'),
          ),
          OutlinedButton.icon(
            onPressed: () => _updatePackageStatus(id, 'return'),
            icon: const Icon(Icons.keyboard_return_rounded, size: 18),
            label: const Text('Devolver'),
          ),
        ],
      );
    } else if (status == 'NOTIFIED') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _updatePackageStatus(id, 'pickup'),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Registrar entrega'),
          ),
          OutlinedButton.icon(
            onPressed: () => _updatePackageStatus(id, 'return'),
            icon: const Icon(Icons.keyboard_return_rounded, size: 18),
            label: const Text('Devolver'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Tab _buildTabItem(String label, IconData icon, bool hasNew) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 7),
          Text(label),
          if (hasNew) ...[
            const SizedBox(width: 5),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visiblePackages = _packages
        .where((item) => recordMatchesQuery(item, _query))
        .toList();

    final hasPendingPackages = _packages.any(
      (p) => p['status'] == 'RECEIVED' || p['status'] == 'WAITING_PICKUP',
    );

    return Scaffold(
      backgroundColor: SaaSColors.background(isDark),
      appBar: AppBar(
        title: const Text('Central da Portaria'),
        backgroundColor: SaaSColors.surface(isDark),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTabItem('Encomendas', Icons.inventory_2_outlined, hasPendingPackages),
            _buildTabItem('Visitantes', Icons.badge_outlined, false),
            _buildTabItem('Consulta de Placas', Icons.directions_car_outlined, false),
            _buildTabItem('Eventos & Convidados', Icons.people_outline_rounded, false),
            _buildTabItem('Unidades & Achados', Icons.apartment_rounded, false),
            _buildTabItem('Reservas & Áreas', Icons.event_available_outlined, false),
            _buildTabItem('Chat Moradores', Icons.chat_bubble_outline_rounded, false),
          ],
        ),
        actions: [
          if (widget.currentRole != null && widget.onSwitchRole != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: RoleSwitcherPill(
                currentRole: widget.currentRole!,
                availableRoles: widget.availableRoles,
                onSwitchRole: widget.onSwitchRole!,
                isLight: !isDark,
              ),
            ),
          // User Avatar Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: InkWell(
              onTap: _openProfile,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  backgroundImage: _profileAvatarImage,
                  child: _profileAvatarImage == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: isDark ? Colors.white70 : SaaSColors.primary,
                        )
                      : null,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Baixa rápida com PIN / QR Code',
            onPressed: _selectedCondominium == null ? null : _quickPickupByPin,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: 'Enviar comunicado a uma unidade',
            onPressed: _selectedCondominium == null ? null : _sendAnnouncement,
            icon: const Icon(Icons.campaign_outlined),
          ),
          IconButton(
            tooltip: 'Notificações e convites',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotificationsPage(
                    api: _api,
                    condominiumId: (_selectedCondominium?['id'] as num?)?.toInt(),
                    onInvitationChanged: _loadCondominiums,
                  ),
                ),
              );
              if (mounted) _loadCondominiums();
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Atualizar encomendas',
            onPressed: _loadPackages,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
            tooltip: 'Sair da conta',
          ),
        ],
      ),
      floatingActionButton: (_selectedCondominium != null && _tabs.index == 0)
          ? FloatingActionButton.extended(
              backgroundColor: SaaSColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _registerReceivedPackage(),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Registrar encomenda'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(
            children: [
              if (_condominiums.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          initialValue: _selectedCondominium,
                          decoration: const InputDecoration(
                            labelText: 'Condomínio em operação',
                            prefixIcon: Icon(Icons.apartment_rounded),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          items: _condominiums.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c['name']?.toString() ?? 'Sem nome'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectCondominium(val));
                            _loadPackages();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _registerReceivedPackage(),
                        icon: const Icon(Icons.add_box_outlined, size: 16),
                        label: const Text('Nova Encomenda'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _quickPickupByPin,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('Baixa (PIN)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : _condominiums.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum condomínio associado no momento. Verifique suas notificações para aceitar convites.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _packagesTab(visiblePackages),
                          DoormanVisitorsView(
                            api: _communityApi,
                            condominiumId: _selectedCondominium!['id'],
                          ),
                          DoormanPlateCheckView(
                            api: _communityApi,
                            condominiumId: _selectedCondominium!['id'],
                          ),
                          DoormanGuestListsView(
                            api: _communityApi,
                            condominiumId: _selectedCondominium!['id'],
                          ),
                          Column(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _directory != null
                                    ? UnitDirectoryView(
                                        key: ValueKey(_directory!.condominiumId),
                                        directory: _directory!,
                                        onRegisterPackage: (unit, resident) =>
                                            _registerReceivedPackage(
                                              unit: unit,
                                              resident: resident,
                                            ),
                                        onAnnounce: (unit) =>
                                            _sendAnnouncement(unit: unit),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                flex: 2,
                                child: DoormanLostFoundView(
                                  api: _communityApi,
                                  condominiumId: _selectedCondominium!['id'],
                                ),
                              ),
                            ],
                          ),
                          DoormanReservationsView(
                            api: _communityApi,
                            condominiumId: _selectedCondominium!['id'],
                          ),
                          DoormanChatView(
                            key: ValueKey('doorman_chat_${_selectedCondominium!['id']}'),
                            api: _communityApi,
                            condominiumId: _selectedCondominium!['id'],
                            isDoormanMode: true,
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

  Widget _packagesTab(List<Map<String, dynamic>> visiblePackages) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: EnterSearchField(
          hintText:
              'Pesquisar encomenda por descrição, unidade ou status (Enter)',
          onSubmitted: (query) => setState(() => _query = query),
        ),
      ),
      Expanded(
        child: visiblePackages.isEmpty
            ? const Center(
                child: Text('Nenhuma encomenda encontrada para este filtro.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 84),
                itemCount: visiblePackages.length,
                itemBuilder: (context, index) =>
                    _packageCard(visiblePackages[index]),
              ),
      ),
    ],
  );

  Widget _packageCard(Map<String, dynamic> pkg) {
    final (statusLabel, statusBg, statusFg) = _statusBadge(
      pkg['status']?.toString(),
    );
    final actions = _buildStatusActions(pkg);
    final unitText = [
      pkg['sectorName'],
      if (pkg['unitIdentifier'] != null) 'Unidade ${pkg['unitIdentifier']}',
    ].where((e) => e != null && e.toString().isNotEmpty).join(' • ');
    final details = [
      if (pkg['recipientName'] != null) 'Para: ${pkg['recipientName']}',
      unitText.isEmpty ? 'Unidade não informada' : unitText,
      if (pkg['receivedAt'] != null) _formatDate(pkg['receivedAt']),
    ].join(' • ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusBg,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: statusFg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg['description']?.toString() ??
                            'Encomenda registrada',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
            if (actions is! SizedBox) ...[const SizedBox(height: 14), actions],
          ],
        ),
      ),
    );
  }
}
