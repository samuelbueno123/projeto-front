import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_system/motion_system.dart';
import '../../../core/design_system/saas_design_system.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/enter_search_field.dart';
import '../../../core/widgets/command_palette.dart';
import '../../../core/widgets/condo_assistant_sheet.dart';
import '../../../core/widgets/custom_menus.dart';
import '../../../core/widgets/emergency_sos_banner.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/role_switcher_pill.dart';
import '../../../core/widgets/saas_dashboard_widgets.dart';
import '../../../core/widgets/smart_image.dart';
import '../../../core/widgets/subscription_status_banner.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/pages/user_profile_page.dart';
import '../../community/data/community_api.dart';
import '../../community/presentation/dialogs/counter_proposal_dialog.dart';
import '../../community/presentation/dialogs/generate_boleto_dialog.dart';
import '../../community/presentation/dialogs/plan_selection_dialog.dart';
import '../../community/presentation/views/community_hub_view.dart';
import '../../community/presentation/views/condominium_gallery_view.dart';
import '../../announcements/presentation/announcement_composer.dart';
import '../../directory/presentation/unit_directory.dart';
import '../../home/data/home_service.dart';
import '../../home/presentation/pages/notifications_page.dart';
import 'membership_management_page.dart';

part 'manager_dashboard_panels_part.dart';
part 'manager_secondary_views_part.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({
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
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  late HomeService _api = widget.api ?? HomeService(token: widget.token);
  late CommunityApi _communityApi = CommunityApi(api: _api);
  List<Map<String, dynamic>> _condos = [];
  Map<String, dynamic> _profile = {};
  Map<String, dynamic>? _condoDetails;
  Map<String, dynamic>? _subscription;
  SubscriptionAccessState get _subAccess => SubscriptionAccessState.fromMaps(
    condominium: _condoDetails,
    subscription: _subscription,
  );
  bool _hasFeature(String code) => _subAccess.hasFeature(code);
  int? _selected;
  int _navIndex = 0;
  int _communityTabIndex = 0;
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _maintenanceOrders = [];
  Map<String, dynamic> _financialSummary = {};
  bool _loading = true;
  String? _error;
  String _query = '';
  StreamSubscription<RealtimeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    RealtimeService.instance.setToken(widget.token);
    _realtimeSub = RealtimeService.instance.events.listen((event) {
      const relevantEvents = {
        RealtimeEventTypes.packageUpdated,
        RealtimeEventTypes.reservationUpdated,
        RealtimeEventTypes.announcementCreated,
        RealtimeEventTypes.announcement,
        RealtimeEventTypes.invoiceUpdated,
        RealtimeEventTypes.membershipUpdated,
        RealtimeEventTypes.maintenanceUpdated,
        RealtimeEventTypes.sosAlertCreated,
        RealtimeEventTypes.emergencyAlert,
        RealtimeEventTypes.subscriptionUpdated,
      };
      if (relevantEvents.contains(event.type) &&
          (event.condominiumId == null || event.condominiumId == _selected) &&
          mounted) {
        _load(silent: true);
      }
    });
    _loadProfile();
    _init();
  }

  @override
  void didUpdateWidget(covariant ManagerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.api != widget.api) {
      RealtimeService.instance.setToken(widget.token);
      if (oldWidget.api == null && widget.api == null) {
        _api.dispose();
      }
      _api = widget.api ?? HomeService(token: widget.token);
      _communityApi = CommunityApi(api: _api);
      _loadProfile();
      _init();
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    if (widget.api == null) {
      _api.dispose();
    }
    super.dispose();
  }

  void _mutate(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _toggleTheme() async {
    final wasDark = Theme.of(context).brightness == Brightness.dark;
    final preference = wasDark ? 'LIGHT' : 'DARK';
    AppTheme.setThemePreference(preference);
    try {
      await _communityApi.updateThemePreference(preference);
    } catch (error) {
      if (!mounted) return;
      AppTheme.setThemePreference(wasDark ? 'DARK' : 'LIGHT');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o tema: $error')),
      );
    }
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

  Future<void> _openMainPhotosManagerDialog() async {
    if (_selected == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _MainPhotosManagerDialog(
        api: _api,
        condominiumId: _selected!,
        condominiumName: _selectedCondoName(),
        currentCondoImage: _condoDetails?['imageUrl'] as String?,
        onCondoImageUpdated: (newUri) {
          setState(() {
            if (_condoDetails != null) {
              _condoDetails!['imageUrl'] = newUri;
            }
          });
        },
      ),
    );
  }

  Future<void> _changeCondominiumImage() async {
    if (_selected == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

      await _api.send(
        'PATCH',
        '/condominiums/$_selected/image',
        body: {'imageUrl': dataUri},
      );

      if (mounted) {
        setState(() {
          if (_condoDetails != null) {
            _condoDetails!['imageUrl'] = dataUri;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto do condomínio atualizada com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar foto: $e')));
      }
    }
  }

  Future<void> _init() async {
    try {
      final result = await _api.get('/memberships/my');
      final memberships = result is List
          ? result.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final seenCondoIds = <int>{};
      final managed = memberships.where((membership) {
        if (membership['authority'] != 'ROLE_MANAGER') return false;
        final cid = (membership['condominiumId'] as num?)?.toInt();
        return cid != null && seenCondoIds.add(cid);
      }).toList();
      if (!mounted) return;
      setState(() => _condos = managed);
      if (managed.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      _selected = (managed.first['condominiumId'] as num).toInt();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
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

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> _load({bool silent = false}) async {
    if (_selected == null || !mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _api.get('/manager/dashboard?condominiumId=$_selected'),
        _api.get('/condominiums/$_selected'),
        _safeGet('/condominiums/$_selected/tickets?mine=false'),
        _safeGet('/condominiums/$_selected/maintenance/orders'),
        _safeGet('/condominiums/$_selected/financial/summary'),
        _safeGet('/condominiums/$_selected/subscription'),
      ]);
      final result = results[0];
      final condoData = results[1] is Map<String, dynamic>
          ? results[1] as Map<String, dynamic>
          : null;
      final tickets = _asMapList(results[2]);
      final maintenanceOrders = _asMapList(results[3]);
      final financialSummary = results[4] is Map<String, dynamic>
          ? Map<String, dynamic>.from(results[4] as Map<String, dynamic>)
          : <String, dynamic>{};
      final subscriptionData = results[5] is Map<String, dynamic>
          ? Map<String, dynamic>.from(results[5] as Map)
          : null;

      if (mounted) {
        setState(() {
          _dashboard = result as Map<String, dynamic>;
          _condoDetails = condoData;
          _subscription = subscriptionData;
          _tickets = tickets;
          _maintenanceOrders = maintenanceOrders;
          _financialSummary = financialSummary;
          if (!silent) _loading = false;
        });

        if (condoData != null && condoData['planSelected'] != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => PlanSelectionDialog(
                condominiumId: _selected!,
                condominiumName:
                    condoData['name']?.toString() ?? 'Seu Condomínio',
                api: _communityApi,
                onPlanSelected: () {
                  _load();
                },
              ),
            );
          });
        }
      }
    } catch (error) {
      if (mounted) {
        if (!silent) {
          setState(() {
            _error = error.toString();
            _loading = false;
          });
        }
      }
    }
  }

  Future<void> _generateBoleto() async {
    final condoId = _selected;
    if (condoId == null) return;
    final units = (_dashboard?['units'] is List)
        ? (_dashboard!['units'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
        : <Map<String, dynamic>>[];
    await showDialog<void>(
      context: context,
      builder: (ctx) => GenerateBoletoDialog(
        condominiumId: condoId,
        units: units,
        api: _communityApi,
        onGenerated: () {
          _load();
        },
      ),
    );
  }

  List<Map<String, dynamic>> _dashboardRecords(String key) {
    final values = _dashboard?[key];
    if (values is! List) return [];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
  }

  Future<void> _sendAnnouncement() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    final sent = await showAnnouncementComposer(
      context,
      api: _api,
      directory: DirectoryApi(api: _api, condominiumId: condominiumId),
      allowCondominiumWide: true,
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comunicado publicado com sucesso!')),
      );
    }
  }

  Future<void> _openAnnouncementsReceiptsDialog() async {
    final condoId = _selected;
    if (condoId == null) return;
    try {
      final res = await _api.get('/condominiums/$condoId/announcements');
      final list = res is List
          ? res.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Comunicados & Confirmações de Leitura'),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Comunicado'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _sendAnnouncement();
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            height: 440,
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum comunicado publicado neste condomínio.',
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, idx) {
                      final a = list[idx];
                      final readCount = a['readCount'] ?? 0;
                      final targetDesc =
                          a['targetDescription']?.toString() ??
                          'Todo o condomínio';
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFEF3C7),
                          child: Icon(
                            Icons.campaign_outlined,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        title: Text(
                          a['title']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Público: $targetDesc\nLeituras confirmadas: $readCount',
                        ),
                        isThreeLine: true,
                        trailing: OutlinedButton.icon(
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: Text('Ver leitores ($readCount)'),
                          onPressed: () async {
                            try {
                              final readers = await _communityApi
                                  .getAnnouncementReaders(a['id'] as num);
                              if (!ctx.mounted) return;
                              await showDialog<void>(
                                context: ctx,
                                builder: (rCtx) => AlertDialog(
                                  title: Text('Leituras: ${a['title'] ?? ''}'),
                                  content: SizedBox(
                                    width: 440,
                                    height: 320,
                                    child: readers.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'Nenhum usuário confirmou a leitura ainda.',
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: readers.length,
                                            itemBuilder: (_, rIdx) {
                                              final r = readers[rIdx];
                                              return ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                  Icons.verified_user_outlined,
                                                  color: Color(0xFF15803D),
                                                ),
                                                title: Text(
                                                  r['userName']?.toString() ??
                                                      'Morador',
                                                ),
                                                subtitle: Text(
                                                  '${r['userEmail'] ?? ''} • ${r['readAt'] ?? ''}',
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(rCtx),
                                      child: const Text('Fechar'),
                                    ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _openMemberships() async {
    if (_selected == null) return;
    setState(() => _navIndex = 5);
  }

  Future<void> _openCommunityHub({int initialIndex = 0}) async {
    if (_selected == null) return;
    setState(() {
      _communityTabIndex = initialIndex;
      _navIndex = 3;
    });
  }

  Future<void> _openCondoAssistant() async {
    final condoId = _selected;
    if (condoId == null) return;
    if (!_hasFeature('AI_ASSISTANT')) {
      SaaSFeedback.showWarning(
        context,
        'O Assistente IA requer o plano Enterprise ou assinatura ativa.',
      );
      return;
    }
    await CondoAssistantSheet.show(
      context,
      api: _api,
      condominiumId: condoId,
      condominiumName: _selectedCondoName(),
    );
  }

  Future<void> _openPlanManagerDialog() async {
    final condoId = _selected;
    if (condoId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => PlanSelectionDialog(
        condominiumId: condoId,
        condominiumName: _selectedCondoName(),
        api: _communityApi,
        isInitialSetup: false,
        currentPlanId: _subAccess.billingPlanId,
        currentPlanName: _subAccess.planName,
        subscriptionStatus: _subAccess.status,
        initialBillingCycle: _subAccess.billingCycle ?? 'MONTHLY',
        onPlanSelected: () => _load(),
      ),
    );
  }

  Future<void> _openUnitsMenu() async {
    if (_selected == null) return;
    setState(() => _navIndex = 1);
  }

  Future<void> _openReservationsMenu() async {
    if (_selected == null) return;
    setState(() => _navIndex = 2);
  }

  Future<void> _selectNavigation(int index) async {
    if (index < 0 || index > 6) return;
    setState(() {
      if (index == 3 && _navIndex != 3) {
        _communityTabIndex = 0;
      }
      _navIndex = index;
    });
    if (index == 0 && _selected != null) {
      await _load(silent: true);
    }
  }

  Future<bool> _editPayment(Map<String, dynamic> unit) async {
    const allowedStatuses = {
      'PAID',
      'PENDING',
      'OVERDUE',
      'CONFIRMATION_REQUESTED',
    };
    final rawStatus = unit['paymentStatus']?.toString();
    var status = (rawStatus != null && allowedStatuses.contains(rawStatus))
        ? rawStatus
        : 'PENDING';
    final amount = TextEditingController(
      text: unit['amount']?.toString() ?? '',
    );
    final dueDate = TextEditingController(
      text: unit['dueDate']?.toString() ?? '',
    );
    final paymentNote = TextEditingController(
      text: unit['paymentNote']?.toString() ?? '',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Unidade ${unit['identifier']} • ${unit['sector']}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Situação do pagamento',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'PAID',
                      child: Text('Pago (em dia)'),
                    ),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pendente')),
                    DropdownMenuItem(
                      value: 'OVERDUE',
                      child: Text('Em atraso'),
                    ),
                    DropdownMenuItem(
                      value: 'CONFIRMATION_REQUESTED',
                      child: Text('Confirmação solicitada'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor da cota (R\$ - opcional)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    dueDate.text.isEmpty
                        ? 'Data de vencimento não informada'
                        : 'Vencimento: ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(dueDate.text) ?? DateTime.now())}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final initial =
                          DateTime.tryParse(dueDate.text) ?? DateTime.now();
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(
                          const Duration(days: 1825),
                        ),
                        locale: const Locale('pt', 'BR'),
                      );
                      if (selected != null) {
                        setDialogState(() {
                          dueDate.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(selected);
                        });
                      }
                    },
                    child: const Text('Alterar'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paymentNote,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observações do pagamento',
                    hintText: 'Complemento ou orientação para a unidade',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar lançamento'),
            ),
          ],
        ),
      ),
    );
    final amountText = amount.text.trim();
    final amountValue = amountText.isEmpty ? null : parseBrlDouble(amountText);
    final dueDateValue = dueDate.text.trim();
    final paymentNoteValue = paymentNote.text.trim();
    amount.dispose();
    dueDate.dispose();
    paymentNote.dispose();
    if (save != true) return false;
    if (amountText.isNotEmpty && amountValue == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe um valor válido para a cota.')),
        );
      }
      return false;
    }
    try {
      await _api.send(
        'PUT',
        '/manager/condominiums/$_selected/units/${unit['id']}/payment-status',
        body: {
          'status': status,
          'amount': amountValue,
          'dueDate': dueDateValue.isEmpty ? null : dueDateValue,
          if (paymentNoteValue.isNotEmpty) 'paymentNote': paymentNoteValue,
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Situação financeira atualizada!')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return false;
    }
  }

  String _selectedCondoName() {
    final condo = _condos.firstWhere(
      (c) => c['condominiumId'] == _selected,
      orElse: () => {},
    );
    return condo['condominiumName']?.toString() ?? 'Condomínio';
  }

  Future<void> _openReportsMenu() async {
    if (_selected == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final report = await _api.get(
        '/condominiums/$_selected/reports/dashboard',
      );
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      final packages = report is Map ? report['packages'] : null;
      final reservations = report is Map ? report['reservations'] : null;
      final announcements = report is Map
          ? report['activeAnnouncements'] ?? 0
          : 0;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.assessment_outlined, color: Color(0xFF2F3FB0)),
              SizedBox(width: 10),
              Text('Relatório de Gestão'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo — ${_selectedCondoName()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _reportRow(
                    'Encomendas Registradas',
                    '${packages is Map ? packages['total'] ?? 0 : 0}',
                    icon: Icons.inventory_2_outlined,
                    iconColor: SaaSColors.primary,
                  ),
                  _reportRow(
                    'Encomendas Aguardando',
                    '${packages is Map ? packages['pending'] ?? 0 : 0}',
                    icon: Icons.mark_email_unread_outlined,
                    iconColor: SaaSColors.warning,
                  ),
                  _reportRow(
                    'Encomendas Entregues',
                    '${packages is Map ? packages['delivered'] ?? 0 : 0}',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: SaaSColors.success,
                  ),
                  const Divider(height: 20),
                  _reportRow(
                    'Total de Reservas',
                    '${reservations is Map ? reservations['total'] ?? 0 : 0}',
                    icon: Icons.calendar_month_outlined,
                    iconColor: SaaSColors.primary,
                  ),
                  _reportRow(
                    'Reservas Aguardando',
                    '${reservations is Map ? reservations['pending'] ?? 0 : 0}',
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: SaaSColors.warning,
                  ),
                  _reportRow(
                    'Reservas Confirmadas',
                    '${reservations is Map ? reservations['confirmed'] ?? 0 : 0}',
                    icon: Icons.celebration_outlined,
                    iconColor: SaaSColors.success,
                  ),
                  const Divider(height: 20),
                  _reportRow(
                    'Comunicados Ativos',
                    '$announcements',
                    icon: Icons.campaign_outlined,
                    iconColor: SaaSColors.purple,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final text =
                    '''
====================================
RELATÓRIO DE GESTÃO CONDOMINIAL
Condomínio: ${_selectedCondoName()}
Data de Emissão: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}
====================================
ENCOMENDAS:
- Total: ${packages is Map ? packages['total'] ?? 0 : 0}
- Aguardando retirada: ${packages is Map ? packages['pending'] ?? 0 : 0}
- Entregues: ${packages is Map ? packages['delivered'] ?? 0 : 0}

RESERVAS:
- Total: ${reservations is Map ? reservations['total'] ?? 0 : 0}
- Aguardando aprovação: ${reservations is Map ? reservations['pending'] ?? 0 : 0}
- Confirmadas: ${reservations is Map ? reservations['confirmed'] ?? 0 : 0}

COMUNICADOS ATIVOS: $announcements
====================================
Emitido via Âncora Gestão
''';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Relatório copiado com sucesso!'),
                    backgroundColor: Color(0xFF15803D),
                  ),
                );
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar Relatório'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível carregar o relatório: $e')),
        );
      }
    }
  }

  Widget _reportRow(
    String label,
    String value, {
    IconData icon = Icons.analytics_outlined,
    Color iconColor = SaaSColors.primary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13.5)),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commandActions = <AncoraCommandAction>[
      AncoraCommandAction(
        id: 'units',
        title: 'Abrir unidades e pagamentos',
        icon: Icons.home_work_outlined,
        onExecute: () => _selectNavigation(1),
      ),
      AncoraCommandAction(
        id: 'reservations',
        title: 'Revisar reservas',
        icon: Icons.event_available_outlined,
        onExecute: () => _selectNavigation(2),
      ),
      AncoraCommandAction(
        id: 'community',
        title: 'Abrir hub da comunidade',
        icon: Icons.diversity_3_outlined,
        onExecute: () => _selectNavigation(3),
      ),
      AncoraCommandAction(
        id: 'gallery',
        title: 'Abrir galeria do condomínio',
        icon: Icons.photo_library_outlined,
        onExecute: () => _selectNavigation(4),
      ),
      AncoraCommandAction(
        id: 'memberships',
        title: 'Gerenciar vínculos e moradores',
        icon: Icons.groups_outlined,
        onExecute: () => _selectNavigation(5),
        category: 'Condomínio',
      ),
      AncoraCommandAction(
        id: 'announcement',
        title: 'Publicar comunicado',
        icon: Icons.campaign_outlined,
        onExecute: _sendAnnouncement,
      ),
      AncoraCommandAction(
        id: 'main_photos',
        title: 'Gerenciar fotos principais',
        icon: Icons.photo_library_outlined,
        onExecute: _openMainPhotosManagerDialog,
        category: 'Condomínio',
      ),
      AncoraCommandAction(
        id: 'reports',
        title: 'Abrir relatórios do condomínio',
        icon: Icons.assessment_outlined,
        onExecute: _openReportsMenu,
        category: 'Condomínio',
      ),
      AncoraCommandAction(
        id: 'refresh',
        title: 'Atualizar painel',
        icon: Icons.refresh_rounded,
        onExecute: () => _load(),
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

    final units = _dashboardRecords('units');
    final reservations = _dashboardRecords('reservations');

    Widget buildInlineWorkspace() {
      switch (_navIndex) {
        case 1:
          return _ManagerUnitsMenuPage(
            key: ValueKey('mgr_units_$_selected'),
            units: units,
            onEditPayment: _editPayment,
            isEmbedded: true,
          );
        case 2:
          return _ManagerReservationsMenuPage(
            key: ValueKey('mgr_res_$_selected'),
            api: _api,
            reservations: reservations,
            isEmbedded: true,
            onChanged: () => _load(silent: true),
          );
        case 3:
          return CommunityHubView(
            key: ValueKey('mgr_hub_${_selected}_$_communityTabIndex'),
            api: _communityApi,
            condominiumId: _selected!,
            canManage: true,
            enabledFeatures: _subAccess.enabledFeatures.toList(),
            initialCategoryIndex: _communityTabIndex,
          );
        case 4:
          return CondominiumGalleryView(
            key: ValueKey('mgr_gallery_$_selected'),
            condominiumId: _selected!,
            api: _communityApi,
            canManage: true,
          );
        case 5:
          return MembershipManagementPage(
            key: ValueKey('mgr_members_$_selected'),
            api: _api,
            condominiumId: _selected!,
            isEmbedded: true,
          );
        case 6:
          return NotificationsPage(
            key: ValueKey('mgr_notif_$_selected'),
            api: _api,
            condominiumId: _selected,
            isEmbedded: true,
          );
        default:
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 980) {
                return _buildDesktopManagerLayout(isDark);
              }
              return _buildMobileManagerLayout(isDark);
            },
          );
      }
    }

    final dashboardContent = _loading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: SaaSLoadingState(
                message: 'Carregando painel de gestão do síndico...',
              ),
            ),
          )
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SaaSErrorState(message: _error!, onRetry: _load),
            ),
          )
        : _condos.isEmpty
        ? const SaaSEmptyState(
            icon: Icons.domain_disabled_rounded,
            title: 'Nenhum condomínio vinculado',
            subtitle:
                'Sua conta ainda não está vinculada como síndico a nenhum condomínio.',
          )
        : buildInlineWorkspace();

    return AncoraCommandShortcutWrapper(
      actions: commandActions,
      child: AncoraNavigationShell(
        title: 'Âncora Gestão',
        subtitle: _selectedCondoName(),
        destinations: const [
          AncoraNavDestination(
            id: 'dashboard',
            label: 'Painel',
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            section: 'Gestão',
            showInBottomNav: true,
          ),
          AncoraNavDestination(
            id: 'units',
            label: 'Unidades e pagamentos',
            icon: Icons.home_work_outlined,
            section: 'Gestão',
            showInBottomNav: true,
          ),
          AncoraNavDestination(
            id: 'reservations',
            label: 'Reservas',
            icon: Icons.event_available_outlined,
            section: 'Gestão',
            showInBottomNav: true,
          ),
          AncoraNavDestination(
            id: 'community',
            label: 'Comunidade',
            icon: Icons.diversity_3_outlined,
            section: 'Condomínio',
            showInBottomNav: true,
          ),
          AncoraNavDestination(
            id: 'gallery',
            label: 'Galeria',
            icon: Icons.photo_library_outlined,
            section: 'Condomínio',
          ),
          AncoraNavDestination(
            id: 'memberships',
            label: 'Vínculos e moradores',
            icon: Icons.groups_outlined,
            section: 'Condomínio',
          ),
          AncoraNavDestination(
            id: 'notifications',
            label: 'Notificações',
            icon: Icons.notifications_outlined,
            section: 'Condomínio',
          ),
        ],
        selectedIndex: _navIndex,
        onSelect: _selectNavigation,
        onOpenCommandPalette: () =>
            AncoraCommandShortcutWrapper.open(context, commandActions),
        banner: (_selected == null || !_hasFeature('EMERGENCY_SOS'))
            ? null
            : EmergencySosBanner(api: _api, condominiumId: _selected!),
        headerActions: [
          IconButton(
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
            onPressed: _toggleTheme,
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode),
          ),
          UserAvatar(
            imageSource: _profile['profileImage']?.toString(),
            name: _profile['firstName']?.toString() ?? widget.userName,
            radius: 17,
            onTap: _openProfile,
            tooltip: 'Meu perfil',
          ),
        ],
        sidebarFooterExtra: Column(
          mainAxisSize: MainAxisSize.min,
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
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(
                  tooltip: 'Notificações',
                  onPressed: () => _selectNavigation(6),
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  tooltip: 'Atualizar painel',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Sair da conta',
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(top: false, child: dashboardContent),
      ),
    );
  }

  Map<String, dynamic> get _summaryMap {
    final raw = _dashboard?['summary'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  int _intStat(String key, [int fallback = 0]) {
    final val = _summaryMap[key];
    return val is num ? val.toInt() : fallback;
  }

  double _doubleStat(String key, [double fallback = 0.0]) {
    final val = _summaryMap[key];
    return val is num ? val.toDouble() : fallback;
  }

  String _buildAiMonitorSummary() {
    final overdueMaint = _intStat('overdueMaintenanceCount');
    final openMaint = _intStat(
      'openMaintenanceCount',
      _maintenanceOrders
          .where((o) => o['status'] == 'OPEN' || o['status'] == 'IN_PROGRESS')
          .length,
    );
    final pendingAssemblies = _intStat('pendingAssembliesCount');
    final openTickets = _intStat(
      'openTicketsCount',
      _tickets
          .where((t) => t['status'] == 'OPEN' || t['status'] == 'IN_PROGRESS')
          .length,
    );
    final parts = <String>[];
    if (overdueMaint > 0) {
      parts.add(
        '$overdueMaint ${overdueMaint == 1 ? 'manutenção atrasada' : 'manutenções atrasadas'}',
      );
    } else if (openMaint > 0) {
      parts.add(
        '$openMaint ${openMaint == 1 ? 'manutenção aberta' : 'manutenções abertas'}',
      );
    }
    if (pendingAssemblies > 0) {
      parts.add(
        '$pendingAssemblies ${pendingAssemblies == 1 ? 'assembleia pendente' : 'assembleias pendentes'}',
      );
    }
    if (openTickets > 0) {
      parts.add(
        '$openTickets ${openTickets == 1 ? 'chamado aberto' : 'chamados abertos'}',
      );
    }
    if (parts.isEmpty) {
      return 'Operação regular • Nenhuma pendência crítica';
    }
    return parts.join(' • ');
  }

  Future<void> _openNewMaintenanceDialog() async {
    final condoId = _selected;
    if (condoId == null) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'ELEVATOR';
    String priority = 'MEDIUM';
    bool saving = false;

    final created = await showAncoraDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.build_circle_outlined, color: SaaSColors.primary),
              SizedBox(width: 10),
              Expanded(child: Text('Nova Ordem de Manutenção')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Título da manutenção *',
                      hintText: 'Ex.: Revisão preventiva do elevador',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'ELEVATOR', child: Text('Elevadores')),
                      DropdownMenuItem(value: 'ELECTRICAL', child: Text('Elétrica')),
                      DropdownMenuItem(value: 'PLUMBING', child: Text('Hidráulica')),
                      DropdownMenuItem(value: 'SECURITY', child: Text('Segurança / CFTV')),
                      DropdownMenuItem(value: 'CLEANING', child: Text('Limpeza / Conservação')),
                      DropdownMenuItem(value: 'GENERAL', child: Text('Manutenção Geral')),
                    ],
                    onChanged: (v) => setDlgState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Prioridade'),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('Baixa')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Média')),
                      DropdownMenuItem(value: 'HIGH', child: Text('Alta')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgente')),
                    ],
                    onChanged: (v) => setDlgState(() => priority = v ?? priority),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição detalhada *',
                      hintText: 'Descreva o problema ou serviço preventivo',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty ||
                          descCtrl.text.trim().isEmpty) {
                        SaaSFeedback.showWarning(
                          context,
                          'Informe título e descrição.',
                        );
                        return;
                      }
                      setDlgState(() => saving = true);
                      try {
                        await _communityApi.createMaintenanceOrder(
                          condoId,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          category: category,
                          priority: priority,
                          type: 'CORRECTIVE',
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDlgState(() => saving = false);
                        if (context.mounted) {
                          SaaSFeedback.showError(context, 'Erro ao criar ordem: $e');
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Registrar Manutenção'),
            ),
          ],
        ),
      ),
    );
    titleCtrl.dispose();
    descCtrl.dispose();
    if (created == true && mounted) {
      SaaSFeedback.showSuccess(context, 'Ordem de manutenção registrada!');
      _load();
    }
  }

  Future<void> _quickApproveReservation(num id) async {
    try {
      await _communityApi.approveReservation(id);
      if (!mounted) return;
      SaaSFeedback.showSuccess(context, 'Reserva confirmada com sucesso!');
      _load();
    } catch (e) {
      if (mounted) SaaSFeedback.showError(context, '$e');
    }
  }

  Future<void> _quickRejectReservation(num id) async {
    try {
      await _communityApi.rejectReservation(id, 'Recusada pela administração');
      if (!mounted) return;
      SaaSFeedback.showInfo(context, 'Reserva recusada.');
      _load();
    } catch (e) {
      if (mounted) SaaSFeedback.showError(context, '$e');
    }
  }

  // ==========================================
  // DESKTOP LAYOUT (Multi-Panel, Responsivo)
  // ==========================================
  Widget _buildDesktopManagerLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubscriptionStatusBanner(
            access: _subAccess,
            onManagePlan: _openPlanManagerDialog,
          ),
          _buildCondominiumCoverBanner(isDark),
          _buildManagerMetricsGrid(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 520,
                  child: _hasFeature('FINANCIAL')
                      ? _buildFinancialPanel(isDark)
                      : FeatureLockedPlaceholder(
                          featureLabel: 'Gestão Financeira & Boletos',
                          planName: _subAccess.planName,
                          isSuspended: _subAccess.isSuspendedOrCancelled,
                          onManagePlan: _openPlanManagerDialog,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    SizedBox(
                      height: 252,
                      child: _hasFeature('RESERVATIONS')
                          ? _buildReservationsPanel(isDark)
                          : FeatureLockedPlaceholder(
                              featureLabel: 'Reservas de Áreas Comuns',
                              planName: _subAccess.planName,
                              isSuspended: _subAccess.isSuspendedOrCancelled,
                              onManagePlan: _openPlanManagerDialog,
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 252,
                      child: _buildOperationalFeedPanel(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE LAYOUT (Vertical, Touch-Optimized)
  // ==========================================
  Widget _buildMobileManagerLayout(bool isDark) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SubscriptionStatusBanner(
            access: _subAccess,
            onManagePlan: _openPlanManagerDialog,
          ),
          _buildCondominiumCoverBanner(isDark),
          _buildManagerMetricsGrid(),
          const SizedBox(height: 16),
          _hasFeature('FINANCIAL')
              ? _buildFinancialPanel(isDark, shrinkWrap: true)
              : FeatureLockedPlaceholder(
                  featureLabel: 'Gestão Financeira & Boletos',
                  planName: _subAccess.planName,
                  isSuspended: _subAccess.isSuspendedOrCancelled,
                  onManagePlan: _openPlanManagerDialog,
                ),
          const SizedBox(height: 16),
          _hasFeature('RESERVATIONS')
              ? _buildReservationsPanel(isDark, shrinkWrap: true)
              : FeatureLockedPlaceholder(
                  featureLabel: 'Reservas de Áreas Comuns',
                  planName: _subAccess.planName,
                  isSuspended: _subAccess.isSuspendedOrCancelled,
                  onManagePlan: _openPlanManagerDialog,
                ),
          const SizedBox(height: 16),
          _buildOperationalFeedPanel(isDark, shrinkWrap: true),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return '';
    return formatDate(dateString, fallback: dateString.toString());
  }

  String _formatDateTime(dynamic dateTimeString) {
    if (dateTimeString == null) return '';
    return formatDateTime(dateTimeString, fallback: dateTimeString.toString());
  }

  String _translateStatus(dynamic status) {
    if (status == 'CONFIRMED') return 'Confirmada';
    if (status == 'CANCELLED') return 'Cancelada';
    return status?.toString() ?? '—';
  }

  (String, Color, Color) _statusStyle(dynamic status) => switch (status) {
    'PAID' => (
      'Pago (em dia)',
      const Color(0xFFDCFCE7),
      const Color(0xFF15803D),
    ),
    'CONFIRMATION_REQUESTED' => (
      'Comprovante enviado / Aguardando confirmação',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'PENDING' => ('Pendente', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    'OVERDUE' => ('Atrasado', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    _ => ('Sem lançamento', const Color(0xFFF1F5F9), const Color(0xFF475569)),
  };
}

