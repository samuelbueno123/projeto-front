import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/design_system/motion_system.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/widgets/enter_search_field.dart';
import '../../../../core/widgets/command_palette.dart';
import '../../../../core/widgets/custom_menus.dart';
import '../../../../core/widgets/emergency_sos_banner.dart';
import '../../../../core/widgets/role_switcher_pill.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/subscription_status_banner.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../announcements/presentation/announcement_composer.dart';
import '../../../auth/presentation/pages/user_profile_page.dart';
import '../../../community/data/community_api.dart';
import '../../../community/presentation/dialogs/emergency_sos_dialog.dart';
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
    this.userEmail,
    this.authProvider = 'password',
    this.reauthenticateWithGoogle,
    this.refreshWithCredentials,
    this.refreshGoogleSession,
    this.currentRole,
    this.availableRoles = const [],
    this.onSwitchRole,
    this.api,
  });

  final String? token;
  final String? userName;
  final String? userEmail;
  final String authProvider;
  final Future<String> Function()? reauthenticateWithGoogle;
  final Future<void> Function(String email, String password)?
  refreshWithCredentials;
  final Future<void> Function()? refreshGoogleSession;
  final Future<void> Function() onLogout;
  final String? currentRole;
  final List<String> availableRoles;
  final ValueChanged<String>? onSwitchRole;
  final HomeService? api;

  @override
  State<DoormanPage> createState() => _DoormanPageState();
}

class _DoormanPageState extends State<DoormanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 8, vsync: this);
  DirectoryApi? _directory;
  late HomeService _api;
  late CommunityApi _communityApi;
  List<Map<String, dynamic>> _condominiums = [];
  Map<String, dynamic>? _selectedCondominium;
  Map<String, dynamic>? _subscription;
  SubscriptionAccessState get _subAccess => SubscriptionAccessState.fromMaps(
    condominium: _selectedCondominium,
    subscription: _subscription,
  );
  bool _hasFeature(String code) => _subAccess.hasFeature(code);
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _shiftLogs = [];
  Map<String, dynamic> _profile = {};
  bool _loadingCondominiums = true;
  bool _loadingPackages = true;
  String? _error;
  String? _packageError;
  String _query = '';
  String _packageStatusFilter = 'ALL'; // ALL, PENDING, DELIVERED
  int _navIndex = 0;
  StreamSubscription<RealtimeEvent>? _sseSub;

  void _subscribeRealtime() {
    _sseSub?.cancel();
    _sseSub = RealtimeService.instance.events.listen((event) {
      final selectedId = (_selectedCondominium?['id'] as num?)?.toInt();
      if (event.condominiumId != null &&
          selectedId != null &&
          event.condominiumId != selectedId) {
        return;
      }
      if (event.type == RealtimeEventTypes.packageUpdated ||
          event.type == RealtimeEventTypes.visitorUpdated ||
          event.type == RealtimeEventTypes.chatMessage ||
          event.type == RealtimeEventTypes.subscriptionUpdated) {
        _loadPackages(silent: true);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!mounted) return;
      setState(() {
        if (_navIndex < 8 || _tabs.indexIsChanging) {
          _navIndex = _tabs.index;
        }
      });
    });
    _api = widget.api ?? HomeService(token: widget.token);
    _communityApi = CommunityApi(api: _api);
    if (widget.token != null && widget.token!.isNotEmpty) {
      RealtimeService.instance.setToken(widget.token);
      _subscribeRealtime();
    }
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant DoormanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.api != widget.api) {
      if (oldWidget.api == null && widget.api == null) {
        _api.dispose();
      }
      _api = widget.api ?? HomeService(token: widget.token);
      _communityApi = CommunityApi(api: _api);
      final selectedId = (_selectedCondominium?['id'] as num?)?.toInt();
      _directory = selectedId == null
          ? null
          : DirectoryApi(api: _api, condominiumId: selectedId);
      RealtimeService.instance.setToken(widget.token);
      if (widget.token != null && widget.token!.isNotEmpty) {
        _subscribeRealtime();
      }
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>([_loadProfile(), _loadCondominiums()]);
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.get('/users/me');
      if (mounted && data is Map<String, dynamic>) {
        setState(() => _profile = data);
      }
    } catch (_) {}
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          token: widget.token,
          userName: widget.userName,
          userEmail: _profile['email'] as String? ?? widget.userEmail,
          provider: widget.authProvider,
          onLogout: widget.onLogout,
          onClose: () {
            Navigator.of(context).pop();
            _loadProfile();
          },
          reauthenticateWithGoogle:
              widget.reauthenticateWithGoogle ?? () async => '',
          refreshWithCredentials:
              widget.refreshWithCredentials ?? (_, __) async {},
          refreshGoogleSession: widget.refreshGoogleSession ?? () async {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _tabs.dispose();
    if (widget.api == null) {
      _api.dispose();
    }
    super.dispose();
  }

  void _selectCondominium(Map<String, dynamic>? condominium) {
    _selectedCondominium = condominium;
    final id = (condominium?['id'] as num?)?.toInt();
    _directory = id == null ? null : DirectoryApi(api: _api, condominiumId: id);
  }

  Future<void> _toggleTheme() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextPreference = isDark ? 'LIGHT' : 'DARK';
    AppTheme.setThemePreference(nextPreference);
    try {
      await _communityApi.updateThemePreference(nextPreference);
    } catch (error) {
      if (!mounted) return;
      AppTheme.setThemePreference(isDark ? 'DARK' : 'LIGHT');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o tema: $error')),
      );
    }
  }

  Future<void> _loadCondominiums() async {
    if (!mounted) return;
    setState(() {
      _loadingCondominiums = true;
      _error = null;
    });
    try {
      final memberships = await _api.get('/memberships/my');
      final list = memberships is List
          ? memberships.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      final seenCondoIds = <String>{};
      final doormanMemberships = list.where((m) {
        final cid = m['condominiumId']?.toString();
        if (cid == null || cid.isEmpty) return false;
        final auth = (m['authority'] ?? m['role'] ?? '').toString();
        if (auth.isNotEmpty && auth != 'ROLE_DOORMAN') return false;
        return seenCondoIds.add(cid);
      }).toList();

      final condos = await Future.wait<Map<String, dynamic>?>(
        doormanMemberships.map((membership) async {
          try {
            final condo = await _api.get(
              '/condominiums/${membership['condominiumId']}',
            );
            return condo is Map<String, dynamic> ? condo : null;
          } catch (_) {
            return null;
          }
        }),
      );

      if (mounted) {
        setState(() {
          _condominiums = condos.whereType<Map<String, dynamic>>().toList();
          _loadingCondominiums = false;
          if (_condominiums.isNotEmpty) {
            _selectCondominium(_condominiums.first);
          }
        });
        if (_condominiums.isNotEmpty) {
          _loadPackages();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar os condomínios associados.';
          _loadingCondominiums = false;
        });
      }
    }
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await _api.get(path);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map && raw['content'] is List) {
      return (raw['content'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<void> _loadPackages({bool silent = false}) async {
    if (!mounted) return;
    if (_selectedCondominium == null) {
      if (mounted) {
        setState(() {
          _loadingPackages = false;
          _packages = [];
          _visitors = [];
          _conversations = [];
          _shiftLogs = [];
        });
      }
      return;
    }
    if (!silent) {
      setState(() {
        _loadingPackages = true;
        _packageError = null;
      });
    }
    try {
      final condoId = _selectedCondominium!['id'];
      final responses = await Future.wait([
        _safeGet('/packages?condominiumId=$condoId&page=0&size=100&sort=id,desc'),
        _safeGet('/condominiums/$condoId/visitors'),
        _safeGet('/condominiums/$condoId/doorman-chat/conversations'),
        _safeGet('/condominiums/$condoId/shift-logs'),
        _safeGet('/condominiums/$condoId/subscription'),
      ]);

      final packages = _extractList(responses[0]);
      final visitors = _extractList(responses[1]);
      final conversations = _extractList(responses[2]);
      final shiftLogs = _extractList(responses[3]);
      final subMap = responses[4] is Map<String, dynamic>
          ? Map<String, dynamic>.from(responses[4] as Map)
          : null;

      if (mounted) {
        setState(() {
          _packages = packages;
          _visitors = visitors;
          _conversations = conversations;
          _shiftLogs = shiftLogs;
          _subscription = subMap;
          _loadingPackages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _packageError =
              'Não foi possível carregar as encomendas deste condomínio.';
          _loadingPackages = false;
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
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(color: Colors.black26),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Retirada'),
          ),
        ],
      ),
    );
    final raw = pinCtrl.text.trim();
    pinCtrl.dispose();
    if (ok == true && raw.isNotEmpty) {
      final upper = raw.toUpperCase();
      final parsedId = int.tryParse(raw);
      final matching = _packages.firstWhere((p) {
        final status = p['status']?.toString();
        if (status == 'PICKED_UP' ||
            status == 'RETURNED' ||
            status == 'CANCELLED') {
          return false;
        }
        final pPin = p['pickupPin']?.toString().trim().toUpperCase();
        final paddedId = p['id']?.toString().padLeft(6, '0');
        final tracking = p['trackingCode']?.toString().trim().toUpperCase();
        return (pPin != null && pPin.isNotEmpty && pPin == upper) ||
            paddedId == raw ||
            (parsedId != null && p['id'] == parsedId) ||
            p['id']?.toString() == raw ||
            (tracking != null && tracking.isNotEmpty && tracking == upper);
      }, orElse: () => {});
      final targetId = (matching['id'] as num?)?.toInt();
      if (targetId != null) {
        try {
          await _updatePackageStatus(targetId, 'pickup');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erro: $e')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Código PIN não encontrado para as encomendas pendentes deste condomínio.',
              ),
            ),
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
    return formatDateTime(raw, fallback: raw.toString());
  }

  String _tabLabel(int index) => switch (index) {
    0 => 'Encomendas',
    1 => 'Visitantes',
    2 => 'Consulta de Placas',
    3 => 'Eventos & Convidados',
    4 => 'Unidades & Achados',
    5 => 'Reservas & Áreas',
    6 => 'Smart Lockers',
    7 => 'Chat Moradores',
    8 => 'Notificações',
    _ => 'Área',
  };

  IconData _tabIcon(int index) => switch (index) {
    0 => Icons.inventory_2_outlined,
    1 => Icons.badge_outlined,
    2 => Icons.directions_car_outlined,
    3 => Icons.people_outline_rounded,
    4 => Icons.apartment_rounded,
    5 => Icons.event_available_outlined,
    6 => Icons.lock_clock_outlined,
    7 => Icons.chat_bubble_outline_rounded,
    8 => Icons.notifications_outlined,
    _ => Icons.dashboard_outlined,
  };

  String get _shiftLabel {
    if (_shiftLogs.isNotEmpty) {
      final latest = _shiftLogs.first;
      final period = latest['shiftPeriod']?.toString() ?? latest['shiftType']?.toString();
      if (period != null && period.trim().isNotEmpty) {
        return switch (period.toUpperCase()) {
          'DAY' || 'MORNING' || 'DIURNO' => 'Turno Dia',
          'AFTERNOON' || 'TARDE' => 'Turno Tarde',
          'NIGHT' || 'NOTURNO' => 'Turno Noite',
          _ => period,
        };
      }
    }
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 14) return 'Turno Dia';
    if (hour >= 14 && hour < 22) return 'Turno Tarde';
    return 'Turno Noite';
  }

  Future<void> _quickReleaseVisitor() async {
    final condoId = _selectedCondominium?['id'] as num?;
    if (condoId == null) return;
    final codeCtrl = TextEditingController();
    final ok = await showAncoraDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: SaaSColors.primary),
            SizedBox(width: 10),
            Expanded(child: Text('Liberar Visitante / Validar QR')),
          ],
        ),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Código de acesso ou QR Code',
            hintText: 'Ex.: AC-9F2A10 ou payload QR',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              _tabs.animateTo(1);
            },
            child: const Text('Ver fila de visitantes'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.verified_user_outlined, size: 17),
            label: const Text('Liberar Entrada'),
          ),
        ],
      ),
    );
    final raw = codeCtrl.text.trim();
    codeCtrl.dispose();
    if (ok == true && raw.isNotEmpty) {
      try {
        final res = await _communityApi.validateVisitorQr(
          condoId,
          qrCodeOrAccessCode: raw,
          autoCheckIn: true,
        );
        if (!mounted) return;
        SaaSFeedback.showSuccess(
          context,
          'Entrada liberada para ${res['visitorName'] ?? 'visitante'}!',
        );
        _loadPackages();
      } catch (e) {
        if (mounted) {
          SaaSFeedback.showError(context, 'Código inválido ou expirado: $e');
        }
      }
    }
  }

  Future<void> _registerUrgentOccurrence() async {
    final condoId = _selectedCondominium?['id'] as num?;
    if (condoId == null) return;
    await showAncoraDialog<void>(
      context: context,
      builder: (_) => EmergencySOSDialog(
        condominiumId: condoId,
        api: _communityApi,
        onAlertSent: _loadPackages,
      ),
    );
  }

  Widget _doormanHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? const Color(0xFF93C5FD) : SaaSColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = AncoraThemeTokens.of(context);
    final condoName =
        _selectedCondominium?['name']?.toString() ?? 'Central da Portaria';
    final condoImg = _selectedCondominium?['imageUrl']?.toString();
    final condoIdNum = _selectedCondominium?['id'] as num?;
    final firstName = firstNameOf(
      _profile['firstName']?.toString() ?? widget.userName,
      fallback: 'Portaria',
    );
    final visiblePackages = _packages
        .where((item) => recordMatchesQuery(item, _query))
        .toList();

    final pendingPackagesCount = _packages
        .where(
          (p) =>
              p['status'] == 'RECEIVED' ||
              p['status'] == 'NOTIFIED' ||
              p['status'] == 'EXPECTED' ||
              p['status'] == 'WAITING_PICKUP',
        )
        .length;

    final commandActions = <AncoraCommandAction>[
      for (var index = 0; index < 9; index++)
        AncoraCommandAction(
          id: 'tab-$index',
          title: 'Abrir ${_tabLabel(index)}',
          icon: _tabIcon(index),
          onExecute: () {
            if (index < 8) {
              _tabs.animateTo(index);
            }
            setState(() => _navIndex = index);
          },
          category: 'Navegação',
        ),
      AncoraCommandAction(
        id: 'pickup',
        title: 'Dar baixa em encomenda por PIN',
        icon: Icons.qr_code_scanner_rounded,
        onExecute: _quickPickupByPin,
        category: 'Ações rápidas',
      ),
      AncoraCommandAction(
        id: 'theme',
        title: 'Alternar tema claro ou escuro',
        icon: Icons.dark_mode_outlined,
        onExecute: _toggleTheme,
        category: 'Preferências',
      ),
      AncoraCommandAction(
        id: 'logout',
        title: 'Sair da conta',
        icon: Icons.logout_rounded,
        onExecute: widget.onLogout,
        category: 'Conta',
      ),
    ];

    final destinations = <AncoraNavDestination>[
      AncoraNavDestination(
        id: 'packages',
        label: 'Encomendas',
        icon: Icons.inventory_2_outlined,
        badgeCount: pendingPackagesCount,
        showInBottomNav: true,
        section: 'Portaria',
      ),
      const AncoraNavDestination(
        id: 'visitors',
        label: 'Visitantes',
        icon: Icons.badge_outlined,
        showInBottomNav: true,
        section: 'Portaria',
      ),
      const AncoraNavDestination(
        id: 'plates',
        label: 'Consulta de Placas',
        icon: Icons.directions_car_outlined,
        section: 'Portaria',
      ),
      const AncoraNavDestination(
        id: 'guests',
        label: 'Eventos & Convidados',
        icon: Icons.people_outline_rounded,
        section: 'Portaria',
      ),
      const AncoraNavDestination(
        id: 'units',
        label: 'Unidades & Achados',
        icon: Icons.apartment_rounded,
        section: 'Condomínio',
      ),
      const AncoraNavDestination(
        id: 'reservations',
        label: 'Reservas & Áreas',
        icon: Icons.event_available_outlined,
        section: 'Condomínio',
      ),
      const AncoraNavDestination(
        id: 'lockers',
        label: 'Smart Lockers',
        icon: Icons.lock_clock_outlined,
        section: 'Condomínio',
      ),
      const AncoraNavDestination(
        id: 'chat',
        label: 'Chat Moradores',
        icon: Icons.chat_bubble_outline_rounded,
        showInBottomNav: true,
        section: 'Comunicação',
      ),
      const AncoraNavDestination(
        id: 'notifications',
        label: 'Notificações',
        icon: Icons.notifications_outlined,
        showInBottomNav: true,
        section: 'Comunicação',
      ),
    ];

    final Widget mainContent;
    if (_loadingCondominiums) {
      mainContent = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: SaaSLoadingState(message: 'Carregando painel da portaria...'),
        ),
      );
    } else if (_error != null) {
      mainContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SaaSErrorState(message: _error!, onRetry: _loadCondominiums),
        ),
      );
    } else if (_condominiums.isEmpty) {
      mainContent = const SaaSEmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'Nenhum condomínio associado',
        subtitle:
            'Nenhum condomínio associado no momento. Verifique suas notificações para aceitar convites de portaria.',
      );
    } else if (_navIndex == 8) {
      mainContent = NotificationsPage(
        api: _api,
        condominiumId: condoIdNum?.toInt(),
        onInvitationChanged: _loadCondominiums,
        isEmbedded: true,
      );
    } else {
      Widget gateTab(String featureCode, String label, Widget child) {
        if (_hasFeature(featureCode)) return child;
        return FeatureLockedPlaceholder(
          featureLabel: label,
          planName: _subAccess.planName,
          isSuspended: _subAccess.isSuspendedOrCancelled,
        );
      }

      mainContent = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SubscriptionStatusBanner(access: _subAccess),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                gateTab('PACKAGES', 'Encomendas', _packagesTab(visiblePackages)),
                gateTab(
                  'VISITORS',
                  'Visitantes',
                  DoormanVisitorsView(
                    key: ValueKey('visitors_${_selectedCondominium!['id']}'),
                    api: _communityApi,
                    condominiumId: _selectedCondominium!['id'],
                  ),
                ),
                gateTab(
                  'CONCIERGE_OPERATIONS',
                  'Consulta de Placas',
                  DoormanPlateCheckView(
                    key: ValueKey('plate_${_selectedCondominium!['id']}'),
                    api: _communityApi,
                    condominiumId: _selectedCondominium!['id'],
                  ),
                ),
                gateTab(
                  'VISITORS',
                  'Eventos & Convidados',
                  DoormanGuestListsView(
                    key: ValueKey('guests_${_selectedCondominium!['id']}'),
                    api: _communityApi,
                    condominiumId: _selectedCondominium!['id'],
                  ),
                ),
                Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _directory != null
                          ? UnitDirectoryView(
                              key: ValueKey(_directory!.condominiumId),
                              directory: _directory!,
                              onRegisterPackage: (unit, resident) {
                                if (!_hasFeature('PACKAGES')) {
                                  SaaSFeedback.showWarning(
                                    context,
                                    'Módulo de encomendas bloqueado no plano atual ou assinatura inativa.',
                                  );
                                  return;
                                }
                                _registerReceivedPackage(
                                  unit: unit,
                                  resident: resident,
                                );
                              },
                              onAnnounce: (unit) => _sendAnnouncement(unit: unit),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      flex: 2,
                      child: gateTab(
                        'CONCIERGE_OPERATIONS',
                        'Achados e Perdidos',
                        DoormanLostFoundView(
                          key: ValueKey('lost_found_${_selectedCondominium!['id']}'),
                          api: _communityApi,
                          condominiumId: _selectedCondominium!['id'],
                        ),
                      ),
                    ),
                  ],
                ),
                gateTab(
                  'RESERVATIONS',
                  'Reservas & Áreas',
                  DoormanReservationsView(
                    key: ValueKey('reservations_${_selectedCondominium!['id']}'),
                    api: _communityApi,
                    condominiumId: _selectedCondominium!['id'],
                  ),
                ),
                gateTab(
                  'SMART_LOCKERS',
                  'Smart Lockers',
                  DoormanSmartLockersView(
                    key: ValueKey('lockers_${_selectedCondominium!['id']}'),
                    api: _communityApi,
                    condominiumId: _selectedCondominium!['id'],
                  ),
                ),
                gateTab(
                  'DOORMAN_CHAT',
                  'Chat Moradores',
                  DoormanChatView(
                    key: ValueKey('doorman_chat_${_selectedCondominium!['id']}'),
                    api: _communityApi,
                    condominiumId: _selectedCondominium!['id'],
                    isDoormanMode: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return AncoraCommandShortcutWrapper(
      actions: commandActions,
      child: AncoraNavigationShell(
        title: 'Âncora Gestão',
        subtitle: 'Portaria • $condoName',
        topBarTitleOverride: '$condoName • $_shiftLabel',
        brandIcon: Icons.shield_outlined,
        destinations: destinations,
        selectedIndex: _navIndex,
        onSelect: (idx) {
          if (idx < 8) {
            _tabs.animateTo(idx);
          }
          setState(() => _navIndex = idx);
        },
        onOpenCommandPalette: () =>
            AncoraCommandShortcutWrapper.open(context, commandActions),
        banner: condoIdNum != null && _hasFeature('EMERGENCY_SOS')
            ? EmergencySosBanner(api: _api, condominiumId: condoIdNum)
            : null,
        floatingActionButton: (_selectedCondominium != null &&
                _navIndex == 0 &&
                _hasFeature('PACKAGES') &&
                MediaQuery.sizeOf(context).width < 960)
            ? FloatingActionButton.extended(
                backgroundColor: SaaSColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _registerReceivedPackage(),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Registrar encomenda'),
              )
            : null,
        sidebarHeaderExtra: _condominiums.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: SmartImage(
                            source: condoImg,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            placeholderIcon: Icons.apartment_rounded,
                            fallbackAsset: AppAssets.condoCoverDefault,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              condoName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                            Text(
                              'Portaria Central • $_shiftLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_condominiums.length > 1) ...[
                    const SizedBox(height: 10),
                    AncoraDropdown<Map<String, dynamic>>(
                      value: _selectedCondominium,
                      compact: true,
                      prefixIcon: Icons.apartment_rounded,
                      items: _condominiums
                          .map(
                            (c) => AncoraMenuOption<Map<String, dynamic>>(
                              value: c,
                              label: c['name']?.toString() ?? 'Sem nome',
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectCondominium(value));
                        _loadPackages();
                      },
                    ),
                  ],
                ],
              ),
        sidebarFooterExtra: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentRole != null && widget.onSwitchRole != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RoleSwitcherPill(
                  currentRole: widget.currentRole!,
                  availableRoles: widget.availableRoles,
                  onSwitchRole: widget.onSwitchRole!,
                  isLight: !isDark,
                ),
              ),
            Row(
              children: [
                UserAvatar(
                  imageSource: _profile['profileImage']?.toString(),
                  name: _profile['firstName']?.toString() ?? widget.userName,
                  radius: 17,
                  onTap: _openProfile,
                  tooltip: 'Meu Perfil',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, $firstName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          _shiftLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isDark ? 'Modo Claro' : 'Modo Noturno',
                  onPressed: _toggleTheme,
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                ),
                IconButton(
                  tooltip: 'Sair',
                  onPressed: widget.onLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: SaaSColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
        headerActions: MediaQuery.sizeOf(context).width < 960
            ? [
                IconButton(
                  tooltip: 'Notificações e convites',
                  onPressed: () => setState(() => _navIndex = 8),
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: _navIndex == 8
                        ? tokens.accent
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    size: 20,
                  ),
                ),
                AncoraContextMenu<String>(
                  tooltip: 'Ações da portaria',
                  onSelected: (action) {
                    if (action == 'pin' && _selectedCondominium != null) {
                      _quickPickupByPin();
                    } else if (action == 'announcement' &&
                        _selectedCondominium != null) {
                      _sendAnnouncement();
                    } else if (action == 'refresh') {
                      _loadPackages();
                    } else if (action == 'theme') {
                      _toggleTheme();
                    }
                  },
                  options: [
                    const AncoraMenuOption(
                      value: 'pin',
                      label: 'Baixa por PIN',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                    const AncoraMenuOption(
                      value: 'announcement',
                      label: 'Novo Comunicado',
                      icon: Icons.campaign_outlined,
                    ),
                    const AncoraMenuOption(
                      value: 'refresh',
                      label: 'Atualizar encomendas',
                      icon: Icons.refresh_rounded,
                    ),
                    AncoraMenuOption(
                      value: 'theme',
                      label: isDark ? 'Modo Claro' : 'Modo Noturno',
                      icon: isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                    ),
                  ],
                ),
              ]
            : [
                _doormanHeaderAction(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Baixa (PIN)',
                  onTap: _selectedCondominium == null
                      ? null
                      : _quickPickupByPin,
                  isDark: isDark,
                ),
                _doormanHeaderAction(
                  icon: Icons.campaign_outlined,
                  label: 'Comunicado',
                  onTap: _selectedCondominium == null
                      ? null
                      : _sendAnnouncement,
                  isDark: isDark,
                ),
                if (widget.currentRole != null && widget.onSwitchRole != null)
                  RoleSwitcherPill(
                    currentRole: widget.currentRole!,
                    availableRoles: widget.availableRoles,
                    onSwitchRole: widget.onSwitchRole!,
                    isLight: !isDark,
                  ),
                IconButton(
                  tooltip: isDark ? 'Modo Claro' : 'Modo Noturno',
                  onPressed: _toggleTheme,
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'Notificações e convites',
                  onPressed: () => setState(() => _navIndex = 8),
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: _navIndex == 8
                        ? tokens.accent
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar encomendas',
                  onPressed: _loadPackages,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    size: 20,
                  ),
                ),
              ],
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: mainContent,
          ),
        ),
      ),
    );
  }

  Widget _packagesTab(List<Map<String, dynamic>> visiblePackages) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final pendingPackagesCount = _packages.where((p) {
      final st = p['status']?.toString();
      return st == 'RECEIVED' ||
          st == 'NOTIFIED' ||
          st == 'EXPECTED' ||
          st == 'WAITING_PICKUP';
    }).length;

    final deliveredTodayCount = _packages.where((p) {
      final st = p['status']?.toString();
      if (st != 'PICKED_UP' && st != 'DELIVERED') return false;
      final dt = parseUtcToLocal(p['pickedUpAt']);
      return dt != null &&
          dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
    }).length;

    final activeVisitorsCount = _visitors
        .where((v) => v['status'] == 'CHECKED_IN')
        .length;

    final activeProvidersCount = _visitors.where((v) {
      final type = (v['visitorType']?.toString() ?? '').toUpperCase();
      final isProvider =
          type == 'SERVICE_PROVIDER' ||
          type == 'PRESTADOR' ||
          type == 'DELIVERY';
      final st = v['status']?.toString();
      return isProvider && (st == 'CHECKED_IN' || st == 'AUTHORIZED');
    }).length;

    final filteredByStatus = visiblePackages.where((p) {
      final st = p['status']?.toString();
      if (_packageStatusFilter == 'PENDING') {
        return st == 'RECEIVED' ||
            st == 'NOTIFIED' ||
            st == 'EXPECTED' ||
            st == 'WAITING_PICKUP';
      }
      if (_packageStatusFilter == 'DELIVERED') {
        return st == 'PICKED_UP' || st == 'DELIVERED';
      }
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1040;
        final quickActionButtons = [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: SaaSColors.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
            ),
            onPressed: _selectedCondominium == null
                ? null
                : () => _registerReceivedPackage(),
            icon: const Icon(Icons.add_box_rounded, size: 16),
            label: const Text('+ Registrar Encomenda'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: SaaSColors.success,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
            ),
            onPressed: _selectedCondominium == null
                ? null
                : _quickReleaseVisitor,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: const Text('+ Liberar Visitante'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
            ),
            onPressed: _selectedCondominium == null ? null : _sendAnnouncement,
            icon: const Icon(Icons.campaign_outlined, size: 16),
            label: const Text('+ Novo Comunicado'),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: SaaSColors.error.withValues(alpha: 0.14),
              foregroundColor: SaaSColors.error,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
            ),
            onPressed: _selectedCondominium == null
                ? null
                : _registerUrgentOccurrence,
            icon: const Icon(Icons.emergency_rounded, size: 16),
            label: const Text('Ocorrência Urgente'),
          ),
        ];

        final quickActionsBar = Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          child: SaaSGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            borderRadius: 14,
            child: isWide
                ? Wrap(spacing: 8, runSpacing: 6, children: quickActionButtons)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < quickActionButtons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          quickActionButtons[i],
                        ],
                      ],
                    ),
                  ),
          ),
        );

        final metricsGrid = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SaaSMetricGrid(
            items: [
              SaaSMetricCard(
                title: 'Encomendas Pendentes',
                value: '$pendingPackagesCount',
                icon: Icons.inventory_2_outlined,
                iconColor: pendingPackagesCount > 0
                    ? SaaSColors.warning
                    : SaaSColors.success,
                subtitle: 'Aguardando retirada',
                onTap: () => setState(() => _packageStatusFilter = 'PENDING'),
              ),
              SaaSMetricCard(
                title: 'Entregues Hoje',
                value: '$deliveredTodayCount',
                icon: Icons.check_circle_outline_rounded,
                iconColor: SaaSColors.success,
                subtitle: 'Baixas realizadas hoje',
                onTap: () => setState(() => _packageStatusFilter = 'DELIVERED'),
              ),
              SaaSMetricCard(
                title: 'Visitantes Ativos',
                value: '$activeVisitorsCount',
                icon: Icons.badge_outlined,
                iconColor: SaaSColors.primary,
                subtitle: 'Com entrada ativa (Check-in)',
                onTap: () => _tabs.animateTo(1),
              ),
              SaaSMetricCard(
                title: 'Prestadores de Serviço',
                value: '$activeProvidersCount',
                icon: Icons.engineering_outlined,
                iconColor: SaaSColors.purple,
                subtitle: 'Autorizados ou no local',
                onTap: () => _tabs.animateTo(1),
              ),
            ],
          ),
        );

        final searchAndFilters = Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 240, maxWidth: 520),
                child: EnterSearchField(
                  hintText:
                      'Filtrar por Unidade, Nome, Descrição ou Transportadora (Enter)',
                  onSubmitted: (query) => setState(() => _query = query),
                ),
              ),
              ChoiceChip(
                label: Text('Todas (${visiblePackages.length})'),
                selected: _packageStatusFilter == 'ALL',
                onSelected: (_) =>
                    setState(() => _packageStatusFilter = 'ALL'),
              ),
              ChoiceChip(
                label: Text('Pendentes ($pendingPackagesCount)'),
                selected: _packageStatusFilter == 'PENDING',
                onSelected: (_) =>
                    setState(() => _packageStatusFilter = 'PENDING'),
              ),
              ChoiceChip(
                label: const Text('Entregues'),
                selected: _packageStatusFilter == 'DELIVERED',
                onSelected: (_) =>
                    setState(() => _packageStatusFilter = 'DELIVERED'),
              ),
            ],
          ),
        );

        Widget buildPackagesBody({required bool shrinkWrap}) {
          if (_loadingPackages) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SaaSLoadingState(message: 'Atualizando encomendas...'),
              ),
            );
          }
          if (_packageError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SaaSErrorState(
                  message: _packageError!,
                  onRetry: _loadPackages,
                ),
              ),
            );
          }
          if (filteredByStatus.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: SaaSEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Nenhuma encomenda encontrada',
                subtitle: 'Não há encomendas correspondentes ao filtro atual.',
              ),
            );
          }
          return ListView.builder(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 84),
            itemCount: filteredByStatus.length,
            itemBuilder: (context, index) =>
                _packageCard(filteredByStatus[index]),
          );
        }

        if (!isWide) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 84),
            children: [
              quickActionsBar,
              metricsGrid,
              searchAndFilters,
              buildPackagesBody(shrinkWrap: true),
              _buildDoormanSidePanel(isDark, shrinkWrap: true),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 8,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  quickActionsBar,
                  metricsGrid,
                  searchAndFilters,
                  buildPackagesBody(shrinkWrap: true),
                ],
              ),
            ),
            Container(
              width: 360,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: _buildDoormanSidePanel(isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDoormanSidePanel(bool isDark, {bool shrinkWrap = false}) {
    final liveVisitors = _visitors
        .where(
          (v) =>
              v['status'] == 'CHECKED_IN' ||
              v['status'] == 'AUTHORIZED' ||
              v['status'] == 'INSIDE',
        )
        .toList();

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(16),
      children: [
        SaaSGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SaaSSectionHeader(
                title: 'Fluxo de Visitantes',
                badge: SaaSBadge(
                  label: '${liveVisitors.length}',
                  variant: SaaSBadgeVariant.primary,
                ),
                action: TextButton(
                  onPressed: () => _tabs.animateTo(1),
                  child: const Text('Gerenciar'),
                ),
              ),
              if (liveVisitors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SaaSEmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Sem fluxo ativo',
                    subtitle: 'Nenhum visitante autorizado ou em visita agora.',
                  ),
                )
              else
                ...liveVisitors.take(4).map((v) {
                  final isIn = v['status'] == 'CHECKED_IN';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SaaSColors.surfaceSubtle(isDark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : SaaSColors.border(isDark),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v['visitorName']?.toString() ?? 'Visitante',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${v['unitLabel'] ?? 'Unidade'} • ${v['visitorType'] ?? 'VISITANTE'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SaaSColors.textSecondary(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (v['id'] is num)
                          FilledButton.tonal(
                            onPressed: () async {
                              if (isIn) {
                                await _communityApi.checkOutVisitor(
                                  v['id'] as num,
                                );
                              } else {
                                await _communityApi.checkInVisitor(
                                  v['id'] as num,
                                );
                              }
                              _loadPackages();
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            child: Text(
                              isIn ? 'Check-out' : 'Check-in',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SaaSGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SaaSSectionHeader(
                title: 'Intercom / Chat',
                badge: SaaSBadge(
                  label: '${_conversations.length}',
                  variant: _conversations.isNotEmpty
                      ? SaaSBadgeVariant.success
                      : SaaSBadgeVariant.neutral,
                ),
                action: TextButton(
                  onPressed: () => _tabs.animateTo(7),
                  child: const Text('Abrir Chat'),
                ),
              ),
              if (_conversations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SaaSEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Sem conversas ativas',
                    subtitle: 'Mensagens de moradores aparecerão aqui.',
                  ),
                )
              else
                ..._conversations.take(4).map((c) {
                  final unread = (c['unreadCount'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: SaaSColors.primary.withValues(alpha: 0.16),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: SaaSColors.primary,
                      ),
                    ),
                    title: Text(
                      c['userName']?.toString() ?? 'Morador',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      c['lastMessage']?.toString() ??
                          c['unitLabel']?.toString() ??
                          'Conversar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: unread > 0
                        ? SaaSBadge(
                            label: '$unread',
                            variant: SaaSBadgeVariant.error,
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => _tabs.animateTo(7),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _packageCard(Map<String, dynamic> pkg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = pkg['status']?.toString();
    final (statusLabel, statusBg, statusFg) = _statusBadge(status);
    final carrier = CarrierVisual.fromDescription(pkg['description']?.toString());
    final badgeVariant = switch (status) {
      'PICKED_UP' || 'DELIVERED' => SaaSBadgeVariant.success,
      'RECEIVED' || 'NOTIFIED' || 'EXPECTED' || 'WAITING_PICKUP' =>
        SaaSBadgeVariant.warning,
      'CANCELLED' || 'RETURNED' => SaaSBadgeVariant.error,
      _ => SaaSBadgeVariant.neutral,
    };

    final unitBadgeText = [
      if (pkg['sectorName'] != null && pkg['sectorName'].toString().isNotEmpty)
        pkg['sectorName'].toString(),
      if (pkg['unitIdentifier'] != null &&
          pkg['unitIdentifier'].toString().isNotEmpty)
        'AP ${pkg['unitIdentifier']}',
    ].join(' • ');

    final id = (pkg['id'] as num?)?.toInt();
    final isPending =
        status == 'RECEIVED' ||
        status == 'NOTIFIED' ||
        status == 'WAITING_PICKUP';

    return SaaSGlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: carrier.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(carrier.icon, color: carrier.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (unitBadgeText.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: SaaSColors.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              unitBadgeText.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : SaaSColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            carrier.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: SaaSColors.textSecondary(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      pkg['description']?.toString() ?? 'Encomenda registrada',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (pkg['recipientName'] != null)
                          'Para: ${pkg['recipientName']}',
                        if (pkg['receivedAt'] != null)
                          'Recebida: ${_formatDate(pkg['receivedAt'])}',
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: SaaSColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SaaSBadge(label: statusLabel, variant: badgeVariant),
            ],
          ),
          if (id != null && (isPending || status == 'EXPECTED')) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPending)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SaaSColors.success,
                    ),
                    onPressed: () => _updatePackageStatus(id, 'pickup'),
                    icon: const Icon(Icons.pin_outlined, size: 17),
                    label: const Text('Dar Baixa (PIN)'),
                  ),
                if (status == 'RECEIVED')
                  FilledButton.tonalIcon(
                    onPressed: () => _updatePackageStatus(id, 'notify'),
                    icon: const Icon(Icons.notifications_active_outlined, size: 17),
                    label: const Text('Notificar Morador'),
                  ),
                if (status == 'EXPECTED') ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _updatePackageStatus(id, 'receive'),
                    icon: const Icon(Icons.download_done_rounded, size: 17),
                    label: const Text('Confirmar chegada'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _updatePackageStatus(id, 'cancel'),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Cancelar'),
                  ),
                ] else if (isPending)
                  OutlinedButton.icon(
                    onPressed: () => _updatePackageStatus(id, 'return'),
                    icon: const Icon(Icons.keyboard_return_rounded, size: 17),
                    label: const Text('Devolver'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
