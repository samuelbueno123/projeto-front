import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_system/saas_design_system.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/enter_search_field.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/role_switcher_pill.dart';
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

class ManagerPage extends StatefulWidget {
  const ManagerPage({
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
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  late final HomeService _api = HomeService(token: widget.token);
  late final CommunityApi _communityApi = CommunityApi(api: _api);
  List<Map<String, dynamic>> _condos = [];
  Map<String, dynamic> _profile = {};
  Map<String, dynamic>? _condoDetails;
  int? _selected;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _init();
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

      await _api.send('PATCH', '/condominiums/$_selected/image', body: {
        'imageUrl': dataUri,
      });

      if (mounted) {
        setState(() {
          if (_condoDetails != null) {
            _condoDetails!['imageUrl'] = dataUri;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto do condomínio atualizada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar foto: $e')),
        );
      }
    }
  }

  Future<void> _init() async {
    try {
      final result = await _api.get('/memberships/my');
      final memberships = result is List
          ? result.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final managed = memberships
          .where((membership) => membership['authority'] == 'ROLE_MANAGER')
          .toList();
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

  Future<void> _load() async {
    if (_selected == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.get('/manager/dashboard?condominiumId=$_selected'),
        _api.get('/condominiums/$_selected'),
      ]);
      final result = results[0];
      final condoData = results[1] is Map<String, dynamic> ? results[1] as Map<String, dynamic> : null;

      if (mounted) {
        setState(() {
          _dashboard = result as Map<String, dynamic>;
          _condoDetails = condoData;
          _loading = false;
        });

        if (condoData != null && condoData['planSelected'] != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => PlanSelectionDialog(
                condominiumId: _selected!,
                condominiumName: condoData['name']?.toString() ?? 'Seu Condomínio',
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
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openGallery() async {
    final condoId = _selected;
    if (condoId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Galeria de Fotos do Condomínio')),
          body: CondominiumGalleryView(
            condominiumId: condoId,
            api: _communityApi,
            canManage: true,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _generateBoleto() async {
    final condoId = _selected;
    if (condoId == null) return;
    final units = (_dashboard?['units'] is List)
        ? (_dashboard!['units'] as List).whereType<Map<String, dynamic>>().toList()
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
                ? const Center(child: Text('Nenhum comunicado publicado neste condomínio.'))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, idx) {
                      final a = list[idx];
                      final readCount = a['readCount'] ?? 0;
                      final targetDesc = a['targetDescription']?.toString() ?? 'Todo o condomínio';
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFEF3C7),
                          child: Icon(Icons.campaign_outlined, color: Color(0xFFD97706)),
                        ),
                        title: Text(a['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Público: $targetDesc\nLeituras confirmadas: $readCount'),
                        isThreeLine: true,
                        trailing: OutlinedButton.icon(
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: Text('Ver leitores ($readCount)'),
                          onPressed: () async {
                            try {
                              final readers = await _communityApi.getAnnouncementReaders(a['id'] as num);
                              if (!ctx.mounted) return;
                              await showDialog<void>(
                                context: ctx,
                                builder: (rCtx) => AlertDialog(
                                  title: Text('Leituras: ${a['title'] ?? ''}'),
                                  content: SizedBox(
                                    width: 440,
                                    height: 320,
                                    child: readers.isEmpty
                                        ? const Center(child: Text('Nenhum usuário confirmou a leitura ainda.'))
                                        : ListView.builder(
                                            itemCount: readers.length,
                                            itemBuilder: (_, rIdx) {
                                              final r = readers[rIdx];
                                              return ListTile(
                                                dense: true,
                                                leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF15803D)),
                                                title: Text(r['userName']?.toString() ?? 'Morador'),
                                                subtitle: Text('${r['userEmail'] ?? ''} • ${r['readAt'] ?? ''}'),
                                              );
                                            },
                                          ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(rCtx), child: const Text('Fechar')),
                                  ],
                                ),
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _openMemberships() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MembershipManagementPage(api: _api, condominiumId: condominiumId),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openCommunityHub({int initialIndex = 0}) async {
    final condoId = _selected;
    if (condoId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Serviços da Comunidade & Operacional')),
          body: CommunityHubView(
            api: _communityApi,
            condominiumId: condoId,
            canManage: true,
            initialCategoryIndex: initialIndex,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openCondoAssistant() async {
    final condoId = _selected;
    if (condoId == null) return;
    final questionCtrl = TextEditingController();
    Map<String, dynamic>? assistantResponse;
    bool asking = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 650),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assistente do Condomínio (IA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          Text('Respostas sobre regimento, leis e minutas', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: questionCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Qual a regra para barulho? Ou redigir aviso de obra...',
                          isDense: true,
                        ),
                        onSubmitted: (q) async {
                          if (q.trim().isEmpty) return;
                          setModalState(() => asking = true);
                          try {
                            final res = await _communityApi.askAssistant(condoId, q.trim());
                            setModalState(() { assistantResponse = res; asking = false; });
                          } catch (e) {
                            setModalState(() => asking = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      onPressed: asking ? null : () async {
                        final q = questionCtrl.text.trim();
                        if (q.isEmpty) return;
                        setModalState(() => asking = true);
                        try {
                          final res = await _communityApi.askAssistant(condoId, q);
                          setModalState(() { assistantResponse = res; asking = false; });
                        } catch (e) {
                          setModalState(() => asking = false);
                        }
                      },
                      child: asking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Perguntar'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (assistantResponse != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology_outlined, size: 18, color: Color(0xFF2563EB)),
                                SizedBox(width: 6),
                                Text('Orientação Especializada:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              assistantResponse!['answer'] ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF1E293B)),
                            ),
                            if (assistantResponse!['legalBasis'] != null) ...[
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.gavel_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Fundamento: ${assistantResponse!['legalBasis']}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (assistantResponse!['suggestedFollowUps'] is List) ...[
                              const SizedBox(height: 12),
                              const Text('Perguntas relacionadas:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (assistantResponse!['suggestedFollowUps'] as List).map((f) => ActionChip(
                                  label: Text(f.toString(), style: const TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    questionCtrl.text = f.toString();
                                  },
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.volume_off_outlined, size: 16),
                        label: const Text('Horário de Silêncio'),
                        onPressed: () => questionCtrl.text = 'Quais os horários de silêncio e multas por barulho?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                        label: const Text('Regras de Mudança'),
                        onPressed: () => questionCtrl.text = 'Quais os horários permitidos e regras para mudanças?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.pets_outlined, size: 16),
                        label: const Text('Regras para Pets'),
                        onPressed: () => questionCtrl.text = 'Quais as regras e direitos para animais de estimação?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.construction_outlined, size: 16),
                        label: const Text('Reformas & ART'),
                        onPressed: () => questionCtrl.text = 'O que é exigido para reformas nos apartamentos?',
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.campaign_outlined, size: 16),
                        label: const Text('Redigir Comunicado'),
                        onPressed: () => questionCtrl.text = 'Redigir minuta de comunicado sobre manutenção preventiva na caixa d\'água',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUnitsMenu() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    final units = (_dashboard?['units'] is List)
        ? (_dashboard!['units'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _ManagerUnitsMenuPage(units: units, onEditPayment: _editPayment),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openReservationsMenu() async {
    final condominiumId = _selected;
    if (condominiumId == null) return;
    final reservations = (_dashboard?['reservations'] is List)
        ? (_dashboard!['reservations'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _ManagerReservationsMenuPage(api: _api, reservations: reservations),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _editPayment(Map<String, dynamic> unit) async {
    var status = unit['paymentStatus'] == 'NOT_RECORDED'
        ? 'PENDING'
        : unit['paymentStatus'] as String;
    final amount = TextEditingController(
      text: unit['amount']?.toString() ?? '',
    );
    final dueDate = TextEditingController(
      text: unit['dueDate']?.toString() ?? '',
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
                TextField(
                  controller: dueDate,
                  decoration: const InputDecoration(
                    labelText: 'Data de vencimento (AAAA-MM-DD)',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
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
    if (save != true) return;
    try {
      await _api.send(
        'PUT',
        '/manager/condominiums/$_selected/units/${unit['id']}/payment-status',
        body: {
          'status': status,
          'amount': amount.text.trim().isEmpty
              ? null
              : double.tryParse(amount.text.replaceAll(',', '.')),
          'dueDate': dueDate.text.trim().isEmpty ? null : dueDate.text.trim(),
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Situação financeira atualizada!')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
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
      final report = await _api.get('/condominiums/$_selected/reports/dashboard');
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      final packages = report is Map ? report['packages'] : null;
      final reservations = report is Map ? report['reservations'] : null;
      final announcements = report is Map ? report['activeAnnouncements'] ?? 0 : 0;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  Text('Resumo — ${_selectedCondoName()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _reportRow('📦 Encomendas Registradas', '${packages is Map ? packages['total'] ?? 0 : 0}'),
                  _reportRow('📬 Encomendas Aguardando', '${packages is Map ? packages['pending'] ?? 0 : 0}'),
                  _reportRow('✅ Encomendas Entregues', '${packages is Map ? packages['delivered'] ?? 0 : 0}'),
                  const Divider(height: 20),
                  _reportRow('📅 Total de Reservas', '${reservations is Map ? reservations['total'] ?? 0 : 0}'),
                  _reportRow('⏳ Reservas Aguardando', '${reservations is Map ? reservations['pending'] ?? 0 : 0}'),
                  _reportRow('🎉 Reservas Confirmadas', '${reservations is Map ? reservations['confirmed'] ?? 0 : 0}'),
                  const Divider(height: 20),
                  _reportRow('📢 Comunicados Ativos', '$announcements'),
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
                final text = '''
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

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      backgroundColor: SaaSColors.background(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildManagerHeader(isDesktop, isDark),
            Expanded(
              child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 44),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _condos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Sua conta ainda não está vinculada como síndico a nenhum condomínio.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 980) {
                          return _buildDesktopManagerLayout(isDark);
                        }
                        return _buildMobileManagerLayout(isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCondominiumCoverBanner(bool isDark) {
    final condoName = _selectedCondoName();
    final rawImageUrl = _condoDetails?['imageUrl'] as String?;
    final imageProvider = resolveAvatarImageProvider(rawImageUrl);

    if (imageProvider != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.75),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condoName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Condomínio em gestão • Imagem de fachada ativa',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (rawImageUrl != null)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => showFullScreenImage(
                        context,
                        imageSource: rawImageUrl,
                        title: condoName,
                      ),
                      icon: const Icon(Icons.fullscreen, size: 16),
                      label: const Text('Ampliar', style: TextStyle(fontSize: 12.5)),
                    ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SaaSColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _changeCondominiumImage,
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Alterar Foto', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SaaSColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.apartment_rounded, color: SaaSColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  condoName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Personalize a identidade do condomínio adicionando uma foto da fachada.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _changeCondominiumImage,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
            label: const Text('Adicionar foto'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (Multi-Panel, Zero Scroll)
  // ==========================================
  Widget _buildDesktopManagerLayout(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
      child: Column(
        children: [
          // Condominium Cover Banner
          _buildCondominiumCoverBanner(isDark),

          // Top bar: Condominium selector + Action pills
          Row(
            children: [
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<int>(
                  initialValue: _selected,
                  decoration: const InputDecoration(
                    labelText: 'Condomínio em gestão',
                    prefixIcon: Icon(Icons.apartment_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: _condos
                      .map(
                        (membership) => DropdownMenuItem<int>(
                          value: (membership['condominiumId'] as num).toInt(),
                          child: Text(
                            membership['condominiumName']?.toString().trim().isNotEmpty == true
                                ? '${membership['condominiumName']}'
                                : 'Condomínio vinculado',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selected = value);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 8,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: SaaSColors.primary),
                        onPressed: _openMemberships,
                        icon: const Icon(Icons.group_add_outlined, size: 16),
                        label: const Text('Convidar / Vínculos'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _sendAnnouncement,
                        icon: const Icon(Icons.campaign_outlined, size: 16),
                        label: const Text('Comunicado'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _openAnnouncementsReceiptsDialog,
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mural & Leituras'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _generateBoleto,
                        icon: const Icon(Icons.receipt_long_outlined, size: 16),
                        label: const Text('Gerar Boleto'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _openCommunityHub,
                        icon: const Icon(Icons.diversity_3_outlined, size: 16),
                        label: const Text('Hub Geral'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openCommunityHub(initialIndex: 11),
                        icon: const Icon(Icons.build_circle_outlined, size: 16),
                        label: const Text('Manutenções'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openCommunityHub(initialIndex: 12),
                        icon: const Icon(Icons.groups_outlined, size: 16),
                        label: const Text('Assembleias'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openCommunityHub(initialIndex: 13),
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                        label: const Text('Financeiro'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _openGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Galeria'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Metric cards
          Row(
            children: [
              Expanded(
                child: SaaSMetricCard(
                  title: 'Unidades Cadastradas',
                  value: '${_dashboard?['totalUnits'] ?? 0}',
                  icon: Icons.home_work_outlined,
                  iconColor: SaaSColors.primary,
                  subtitle: 'Total registrado',
                  onTap: _openUnitsMenu,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SaaSMetricCard(
                  title: 'Pessoas Vinculadas',
                  value: '${_dashboard?['totalUsers'] ?? 0}',
                  icon: Icons.groups_outlined,
                  iconColor: const Color(0xFF10B981),
                  subtitle: 'Moradores e porteiros',
                  onTap: _openMemberships,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SaaSMetricCard(
                  title: 'Reservas Registradas',
                  value: '${_dashboard?['totalReservations'] ?? 0}',
                  icon: Icons.event_available_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  subtitle: 'Áreas comuns',
                  onTap: _openReservationsMenu,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SaaSMetricCard(
                  title: 'Assistente IA Síndico',
                  value: 'Ativo',
                  icon: Icons.auto_awesome,
                  iconColor: const Color(0xFF8B5CF6),
                  subtitle: 'Análise de dados do condomínio',
                  onTap: _openCondoAssistant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2-Column Split Workspace (Zero Page Scroll)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Situação Financeira das Unidades
                Expanded(
                  flex: 6,
                  child: SaaSCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SaaSSectionHeader(
                          title: 'Situação Financeira das Unidades',
                          action: FilledButton.icon(
                            onPressed: _generateBoleto,
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('Novo Boleto'),
                            style: FilledButton.styleFrom(
                              backgroundColor: SaaSColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                        ),
                        EnterSearchField(
                          hintText: 'Pesquisar unidades ou moradores (Enter)',
                          onSubmitted: (query) => setState(() => _query = query),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _dashboardRecords('units').isEmpty
                              ? const SaaSEmptyState(
                                  icon: Icons.home_work_outlined,
                                  title: 'Nenhuma unidade encontrada',
                                  description: 'Verifique a busca ou cadastre novas unidades.',
                                )
                              : ListView.separated(
                                  itemCount: _dashboardRecords('units').length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final unit = _dashboardRecords('units')[index];
                                    final (label, bg, fg) = _statusStyle(unit['paymentStatus']);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: SaaSColors.surfaceSubtle(isDark),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: SaaSColors.border(isDark)),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: bg,
                                            child: Icon(Icons.home_outlined, color: fg, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${unit['sector']} • Unidade ${unit['identifier']}',
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Status: $label${unit['dueDate'] == null ? '' : ' • Venc: ${_formatDate(unit['dueDate'])}'}${unit['amount'] == null ? '' : ' • R\$ ${unit['amount']}'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: SaaSColors.textSecondary(isDark),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () => _editPayment(unit),
                                            icon: const Icon(Icons.edit_outlined, size: 15),
                                            label: const Text('Atualizar'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Right Panel: Agendamentos de Áreas Comuns
                Expanded(
                  flex: 6,
                  child: SaaSCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SaaSSectionHeader(
                          title: 'Agendamentos de Áreas Comuns',
                          badge: SaaSBadge(
                            label: '${_dashboardRecords('reservations').length}',
                            variant: SaaSBadgeVariant.warning,
                          ),
                          action: OutlinedButton.icon(
                            onPressed: _openReservationsMenu,
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('Ver todas'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _dashboardRecords('reservations').isEmpty
                              ? const SaaSEmptyState(
                                  icon: Icons.event_available_outlined,
                                  title: 'Nenhum agendamento pendente',
                                  description: 'Não há solicitações de áreas comuns registradas no momento.',
                                )
                              : ListView.separated(
                                  itemCount: _dashboardRecords('reservations').length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final reservation = _dashboardRecords('reservations')[index];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: SaaSColors.surfaceSubtle(isDark),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: SaaSColors.border(isDark)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.event_available_outlined, color: SaaSColors.primary, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${reservation['commonArea']} • ${reservation['residentName']}',
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${_formatDateTime(reservation['startAt'])} até ${_formatDateTime(reservation['endAt'])}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: SaaSColors.textSecondary(isDark),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${reservation['residentEmail']}${reservation['contactPhone'] != null && reservation['contactPhone'].toString().isNotEmpty ? ' • ${formatPhone(reservation['contactPhone']?.toString())}' : ''} • ${_translateStatus(reservation['status'])}',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: SaaSColors.textSecondary(isDark),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCondominiumCoverBanner(isDark),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, ${firstNameOf(widget.userName, fallback: 'síndico')}! 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gerencie moradores, porteiros, reservas e pagamentos.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1E3A8A),
                            ),
                            onPressed: _openMemberships,
                            icon: const Icon(Icons.group_add_outlined, size: 16),
                            label: const Text('Vínculos'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF3C7),
                              foregroundColor: const Color(0xFFB45309),
                            ),
                            onPressed: _sendAnnouncement,
                            icon: const Icon(Icons.campaign_outlined, size: 16),
                            label: const Text('Comunicado'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF9C3),
                              foregroundColor: const Color(0xFF854D0E),
                            ),
                            onPressed: _openAnnouncementsReceiptsDialog,
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('Leituras'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDCFCE7),
                              foregroundColor: const Color(0xFF15803D),
                            ),
                            onPressed: _openCommunityHub,
                            icon: const Icon(Icons.diversity_3_outlined, size: 16),
                            label: const Text('Hub Geral'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE0E7FF),
                              foregroundColor: const Color(0xFF1D4ED8),
                            ),
                            onPressed: () => _openCommunityHub(initialIndex: 11),
                            icon: const Icon(Icons.build_circle_outlined, size: 16),
                            label: const Text('Manutenções'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF3E8FF),
                              foregroundColor: const Color(0xFF6D28D9),
                            ),
                            onPressed: () => _openCommunityHub(initialIndex: 12),
                            icon: const Icon(Icons.groups_outlined, size: 16),
                            label: const Text('Assembleias'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selected,
                decoration: const InputDecoration(
                  labelText: 'Condomínio em gestão',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: _condos
                    .map(
                      (membership) => DropdownMenuItem<int>(
                        value: (membership['condominiumId'] as num).toInt(),
                        child: Text(
                          membership['condominiumName']?.toString().trim().isNotEmpty == true
                              ? '${membership['condominiumName']}'
                              : 'Condomínio vinculado',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selected = value);
                  _load();
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric(
                    'Unidades cadastradas',
                    _dashboard?['totalUnits'],
                    Icons.home_work_outlined,
                    accentBg: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0E7FF),
                    accentFg: SaaSColors.primary,
                    onTap: _openUnitsMenu,
                  ),
                  _metric(
                    'Pessoas vinculadas',
                    _dashboard?['totalUsers'],
                    Icons.groups_outlined,
                    accentBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFCCFBF1),
                    accentFg: const Color(0xFF0F766E),
                    onTap: _openMemberships,
                  ),
                  _metric(
                    'Reservas registradas',
                    _dashboard?['totalReservations'],
                    Icons.event_available_outlined,
                    accentBg: isDark ? const Color(0xFF78350F) : const Color(0xFFDCFCE7),
                    accentFg: const Color(0xFF15803D),
                    onTap: _openReservationsMenu,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              EnterSearchField(
                hintText: 'Pesquisar unidades ou reservas (Enter)',
                onSubmitted: (query) => setState(() => _query = query),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Situação financeira das unidades',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: SaaSColors.textPrimary(isDark),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _generateBoleto,
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Gerar Boleto'),
                    style: FilledButton.styleFrom(backgroundColor: SaaSColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_dashboardRecords('units').isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nenhuma unidade encontrada.'),
                  ),
                )
              else
                ..._dashboardRecords('units').map((unit) {
                  final (label, bg, fg) = _statusStyle(unit['paymentStatus']);
                  return SaaSCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: bg,
                          child: Icon(Icons.home_outlined, color: fg, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${unit['sector']} • Unidade ${unit['identifier']}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Status: $label${unit['dueDate'] == null ? '' : ' • Vencimento: ${_formatDate(unit['dueDate'])}'}${unit['amount'] == null ? '' : ' • R\$ ${unit['amount']}'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SaaSColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _editPayment(unit),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 20),
              Text(
                'Agendamentos de áreas comuns',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SaaSColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 10),
              if (_dashboardRecords('reservations').isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nenhum agendamento encontrado.'),
                  ),
                )
              else
                ..._dashboardRecords('reservations').map((reservation) {
                  return SaaSCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_available_outlined, color: SaaSColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${reservation['commonArea']} • ${reservation['residentName']}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatDateTime(reservation['startAt'])} até ${_formatDateTime(reservation['endAt'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SaaSColors.textSecondary(isDark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${reservation['residentEmail']}${reservation['contactPhone'] != null && reservation['contactPhone'].toString().isNotEmpty ? ' • ${formatPhone(reservation['contactPhone']?.toString())}' : ''} • ${_translateStatus(reservation['status'])}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: SaaSColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
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
    'PAID' => ('Pago (em dia)', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    'CONFIRMATION_REQUESTED' => (
      'Comprovante enviado / Aguardando confirmação',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'PENDING' => ('Pendente', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    'OVERDUE' => ('Atrasado', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    _ => ('Sem lançamento', const Color(0xFFF1F5F9), const Color(0xFF475569)),
  };

  Widget _metric(
    String label,
    dynamic value,
    IconData icon, {
    required VoidCallback onTap,
    Color accentBg = const Color(0xFFE8ECFF),
    Color accentFg = const Color(0xFF2F3FB0),
  }) => SizedBox(
    width: 260,
    child: Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accentFg.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accentBg,
                child: Icon(icon, color: accentFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${value ?? 0}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildManagerHeader(bool isDesktop, bool isDark) {
    final condoName = _selectedCondoName();
    final condoImg = _condoDetails?['imageUrl'] as String?;

    if (isDesktop) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                alignment: Alignment.center,
                child: (condoImg != null && condoImg.isNotEmpty)
                    ? (condoImg.startsWith('data:')
                        ? Image.memory(
                            base64Decode(condoImg.split(',').last),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.apartment_rounded, color: SaaSColors.primary, size: 22),
                          )
                        : Image.network(
                            condoImg,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.apartment_rounded, color: SaaSColors.primary, size: 22),
                          ))
                    : const Icon(Icons.apartment_rounded, color: SaaSColors.primary, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  condoName,
                  style: TextStyle(
                    color: SaaSColors.textPrimary(isDark),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Painel do Síndico • Olá, ${firstNameOf(widget.userName, fallback: 'Síndico')}!',
                  style: TextStyle(
                    color: SaaSColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),

            _managerHeaderTab(
              icon: Icons.photo_library_outlined,
              label: 'Fotos Principais',
              onTap: _openMainPhotosManagerDialog,
              isDark: isDark,
            ),
            _managerHeaderTab(
              icon: Icons.campaign_outlined,
              label: 'Comunicado',
              onTap: _selected == null ? null : _sendAnnouncement,
              isDark: isDark,
            ),
            _managerHeaderTab(
              icon: Icons.assessment_outlined,
              label: 'Relatórios',
              onTap: _selected == null ? null : _openReportsMenu,
              isDark: isDark,
            ),

            const Spacer(),

            if (widget.currentRole != null && widget.onSwitchRole != null) ...[
              RoleSwitcherPill(
                currentRole: widget.currentRole!,
                availableRoles: widget.availableRoles,
                onSwitchRole: widget.onSwitchRole!,
                isLight: !isDark,
              ),
              const SizedBox(width: 8),
            ],

            IconButton(
              tooltip: isDark ? 'Modo Claro' : 'Modo Noturno',
              onPressed: () {
                final nextPref = isDark ? 'LIGHT' : 'DARK';
                AppTheme.setThemePreference(nextPref);
                _communityApi.updateThemePreference(nextPref);
              },
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                size: 20,
              ),
            ),

            IconButton(
              tooltip: 'Central de Notificações',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotificationsPage(api: _api, condominiumId: _selected),
                ),
              ),
              icon: Icon(
                Icons.notifications_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                size: 20,
              ),
            ),

            IconButton(
              tooltip: 'Atualizar Painel',
              onPressed: _load,
              icon: Icon(
                Icons.refresh_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                size: 20,
              ),
            ),

            const SizedBox(width: 8),

            UserAvatar(
              imageSource: _profile['profileImage']?.toString(),
              name: _profile['firstName']?.toString() ?? widget.userName,
              radius: 18,
              onTap: _openProfile,
              tooltip: 'Meu Perfil',
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet Header
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1D4ED8),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.white24,
                  alignment: Alignment.center,
                  child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condoName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Painel do Síndico • Olá, ${firstNameOf(widget.userName, fallback: 'Síndico')}!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.currentRole != null && widget.onSwitchRole != null)
                RoleSwitcherPill(
                  currentRole: widget.currentRole!,
                  availableRoles: widget.availableRoles,
                  onSwitchRole: widget.onSwitchRole!,
                ),
              const SizedBox(width: 4),
              UserAvatar(
                imageSource: _profile['profileImage']?.toString(),
                name: _profile['firstName']?.toString() ?? widget.userName,
                radius: 16,
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                borderColor: Colors.white38,
                onTap: _openProfile,
                tooltip: 'Meu Perfil',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _managerMobileActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Fotos Principais',
                  onTap: _openMainPhotosManagerDialog,
                ),
                const SizedBox(width: 8),
                _managerMobileActionButton(
                  icon: Icons.campaign_outlined,
                  label: 'Comunicado',
                  onTap: _selected == null ? null : _sendAnnouncement,
                ),
                const SizedBox(width: 8),
                _managerMobileActionButton(
                  icon: Icons.assessment_outlined,
                  label: 'Relatórios',
                  onTap: _selected == null ? null : _openReportsMenu,
                ),
                const SizedBox(width: 8),
                _managerMobileActionButton(
                  icon: Icons.notifications_outlined,
                  label: 'Notificações',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotificationsPage(api: _api, condominiumId: _selected),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _managerMobileActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Atualizar',
                  onTap: _load,
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _managerHeaderTab({
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
              Icon(icon, size: 16, color: isDark ? const Color(0xFF93C5FD) : SaaSColors.primary),
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

  Widget _managerMobileActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDestructive ? const Color(0xFFEF4444).withValues(alpha: 0.25) : Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDestructive ? const Color(0xFFEF4444) : Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerUnitsMenuPage extends StatefulWidget {
  const _ManagerUnitsMenuPage({
    required this.units,
    required this.onEditPayment,
  });

  final List<Map<String, dynamic>> units;
  final Future<void> Function(Map<String, dynamic> unit) onEditPayment;

  @override
  State<_ManagerUnitsMenuPage> createState() => _ManagerUnitsMenuPageState();
}

class _ManagerUnitsMenuPageState extends State<_ManagerUnitsMenuPage> {
  String _query = '';

  (String, Color, Color) _statusStyle(dynamic status) => switch (status) {
    'PAID' => ('Pago (em dia)', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    'CONFIRMATION_REQUESTED' => (
      'Comprovante enviado / Aguardando confirmação',
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    'PENDING' => ('Pendente', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    'OVERDUE' => ('Atrasado', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    _ => ('Sem lançamento', const Color(0xFFF1F5F9), const Color(0xFF475569)),
  };

  @override
  Widget build(BuildContext context) {
    final filtered = widget.units
        .where((item) => recordMatchesQuery(item, _query))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Unidades cadastradas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
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
                  final (label, bg, fg) = _statusStyle(unit['paymentStatus']);
                  return Card(
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
                      trailing: unit['paymentStatus'] == 'CONFIRMATION_REQUESTED'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF15803D),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await widget.onEditPayment({
                                      ...unit,
                                      'paymentStatus': 'PAID',
                                    });
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Confirmar Pagamento'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await widget.onEditPayment(unit);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Editar'),
                                ),
                              ],
                            )
                          : OutlinedButton.icon(
                              onPressed: () async {
                                await widget.onEditPayment(unit);
                                if (context.mounted) Navigator.pop(context);
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
      ),
    );
  }
}

class _ManagerReservationsMenuPage extends StatefulWidget {
  const _ManagerReservationsMenuPage({
    required this.api,
    required this.reservations,
  });

  final HomeService api;
  final List<Map<String, dynamic>> reservations;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Reservas registradas')),
      body: Center(
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
                      avatar: const Icon(Icons.calendar_month_outlined, size: 16),
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
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                          child: (reservation['imageUrl'] != null && reservation['imageUrl'].toString().isNotEmpty)
                              ? (reservation['imageUrl'].toString().startsWith('data:')
                                  ? Image.memory(
                                      base64Decode(reservation['imageUrl'].toString().split(',').last),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => CircleAvatar(
                                        backgroundColor: isItemCancelled
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFE0E7FF),
                                        child: Icon(
                                          isItemCancelled
                                              ? Icons.cancel_outlined
                                              : Icons.event_available_outlined,
                                          color: isItemCancelled
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF2F3FB0),
                                        ),
                                      ),
                                    )
                                  : Image.network(
                                      reservation['imageUrl'].toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => CircleAvatar(
                                        backgroundColor: isItemCancelled
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFE0E7FF),
                                        child: Icon(
                                          isItemCancelled
                                              ? Icons.cancel_outlined
                                              : Icons.event_available_outlined,
                                          color: isItemCancelled
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF2F3FB0),
                                        ),
                                      ),
                                    ))
                              : CircleAvatar(
                                  backgroundColor: isItemCancelled
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFE0E7FF),
                                  child: Icon(
                                    isItemCancelled
                                        ? Icons.cancel_outlined
                                        : Icons.event_available_outlined,
                                    color: isItemCancelled
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF2F3FB0),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        '${reservation['commonArea']} • ${reservation['residentName']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isItemCancelled ? const Color(0xFFB91C1C) : null,
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
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          if (isItemCancelled) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF87171)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFDC2626)),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: () async {
                                      await widget.api.send('PATCH', '/reservations/${reservation['id']}/approve');
                                      if (context.mounted) Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Aprovar'),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFFEF3C7),
                                      foregroundColor: const Color(0xFFB45309),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: () async {
                                      final communityApi = CommunityApi(api: widget.api);
                                      await showDialog<void>(
                                        context: context,
                                        builder: (ctx) => CounterProposalDialog(
                                          reservation: reservation,
                                          api: communityApi,
                                          onSubmitted: () {
                                            if (context.mounted) Navigator.pop(context);
                                          },
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                    label: const Text('Contraproposta'),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFDC2626),
                                      side: const BorderSide(color: Color(0xFFFECACA)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: () async {
                                      final reasonCtrl = TextEditingController();
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Recusar Solicitação de Reserva'),
                                          content: TextField(
                                            controller: reasonCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Motivo da recusa (opcional)',
                                              hintText: 'Ex: Espaço em manutenção no período.',
                                            ),
                                            maxLines: 2,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Voltar'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Confirmar Recusa'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await widget.api.send(
                                          'PATCH',
                                          '/reservations/${reservation['id']}/reject',
                                          body: reasonCtrl.text.trim().isNotEmpty
                                              ? {'reason': reasonCtrl.text.trim()}
                                              : null,
                                        );
                                        if (context.mounted) Navigator.pop(context);
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      ),
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
  State<_MainPhotosManagerDialog> createState() => _MainPhotosManagerDialogState();
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
      final res = await widget.api.get('/condominiums/${widget.condominiumId}/common-areas/all');
      if (mounted) {
        setState(() {
          _commonAreas = res is List ? res.whereType<Map<String, dynamic>>().toList() : [];
          _loadingAreas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  Future<void> _fetchSectors() async {
    try {
      final res = await widget.api.get('/sectors?condominiumId=${widget.condominiumId}');
      if (mounted) {
        setState(() {
          _sectors = res is List ? res.whereType<Map<String, dynamic>>().toList() : [];
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
      await widget.api.send('PATCH', '/condominiums/${widget.condominiumId}/image', body: {
        'imageUrl': dataUri,
      });
      if (mounted) {
        setState(() => _condoImg = dataUri);
        widget.onCondoImageUpdated(dataUri);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto da fachada do condomínio atualizada!'), backgroundColor: Color(0xFF15803D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _changeAreaImage(Map<String, dynamic> area) async {
    final dataUri = await _pickBase64Image();
    if (dataUri == null) return;
    try {
      await widget.api.send('PATCH', '/common-areas/${area['id']}/image', body: {
        'imageUrl': dataUri,
      });
      if (mounted) {
        setState(() {
          area['imageUrl'] = dataUri;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto de "${area['name']}" atualizada com sucesso!'), backgroundColor: const Color(0xFF15803D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _changeSectorImage(Map<String, dynamic> sector) async {
    final dataUri = await _pickBase64Image();
    if (dataUri == null) return;
    try {
      await widget.api.send('PATCH', '/sectors/${sector['id']}/image', body: {
        'imageUrl': dataUri,
      });
      if (mounted) {
        setState(() {
          sector['imageUrl'] = dataUri;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto de "${sector['name']}" atualizada com sucesso!'), backgroundColor: const Color(0xFF15803D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Widget _buildPhotoThumbnail(String? url, IconData fallbackIcon) {
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:')) {
        try {
          return Image.memory(
            base64Decode(url.split(',').last),
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: SaaSColors.primary, size: 26),
          );
        } catch (_) {}
      } else {
        return Image.network(
          url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: SaaSColors.primary, size: 26),
        );
      }
    }
    return Icon(fallbackIcon, color: SaaSColors.primary, size: 26);
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
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library_outlined, color: SaaSColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fotos Principais do Condomínio',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          Text(
                            'Personalize as imagens reais de fachada, áreas de lazer e blocos',
                            style: TextStyle(fontSize: 12, color: SaaSColors.textSecondary(isDark)),
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
                  Tab(icon: Icon(Icons.apartment_rounded, size: 18), text: 'Condomínio'),
                  Tab(icon: Icon(Icons.deck_rounded, size: 18), text: 'Áreas Comuns'),
                  Tab(icon: Icon(Icons.business_outlined, size: 18), text: 'Setores / Blocos'),
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Esta foto aparece no topo do menu de todos os moradores e na apresentação do condomínio.',
                            style: TextStyle(fontSize: 12.5, color: SaaSColors.textSecondary(isDark)),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                alignment: Alignment.center,
                                child: _condoImg != null && _condoImg!.isNotEmpty
                                    ? (_condoImg!.startsWith('data:')
                                        ? Image.memory(
                                            base64Decode(_condoImg!.split(',').last),
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            _condoImg!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          ))
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: SaaSColors.textSecondary(isDark)),
                                          const SizedBox(height: 8),
                                          Text('Nenhuma foto de fachada definida', style: TextStyle(color: SaaSColors.textSecondary(isDark), fontSize: 13)),
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
                              label: Text(_condoImg == null ? 'Definir Foto da Fachada' : 'Alterar Foto da Fachada'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: Áreas Comuns
                    _loadingAreas
                        ? const Center(child: CircularProgressIndicator())
                        : _commonAreas.isEmpty
                            ? const Center(child: Text('Nenhuma área comum cadastrada no condomínio.'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _commonAreas.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final area = _commonAreas[idx];
                                  final img = area['imageUrl']?.toString();
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                              alignment: Alignment.center,
                                              child: _buildPhotoThumbnail(img, Icons.deck_rounded),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  area['name'] ?? 'Área Comum',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Capacidade: ${area['capacity'] ?? 'Livre'} pessoas • ${img != null && img.isNotEmpty ? 'Foto definida' : 'Sem foto cadastrada'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: img != null && img.isNotEmpty ? const Color(0xFF15803D) : SaaSColors.textSecondary(isDark),
                                                    fontWeight: img != null && img.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            onPressed: () => _changeAreaImage(area),
                                            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                                            label: Text(img == null ? 'Definir Foto' : 'Alterar'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                    // Tab 3: Setores / Blocos
                    _loadingSectors
                        ? const Center(child: CircularProgressIndicator())
                        : _sectors.isEmpty
                            ? const Center(child: Text('Nenhum setor ou bloco cadastrado.'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _sectors.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final sector = _sectors[idx];
                                  final img = sector['imageUrl']?.toString();
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                              alignment: Alignment.center,
                                              child: _buildPhotoThumbnail(img, Icons.apartment_rounded),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sector['name'] ?? 'Setor',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Tipo: ${sector['structuralType'] ?? 'BLOCO'} • ${img != null && img.isNotEmpty ? 'Foto definida' : 'Sem foto cadastrada'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: img != null && img.isNotEmpty ? const Color(0xFF15803D) : SaaSColors.textSecondary(isDark),
                                                    fontWeight: img != null && img.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            onPressed: () => _changeSectorImage(sector),
                                            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                                            label: Text(img == null ? 'Definir Foto' : 'Alterar'),
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
