import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/widgets/enter_search_field.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import '../../data/home_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.api,
    this.condominiumId,
    this.onInvitationChanged,
  });
  final HomeService api;
  final int? condominiumId;
  final Future<void> Function()? onInvitationChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _query = '';
  String _originFilter = 'ALL';
  StreamSubscription<RealtimeEvent>? _sseSub;
  late Future<
    ({
      List<Map<String, dynamic>> notices,
      List<Map<String, dynamic>> announcements,
    })
  >
  _load = _fetch();

  @override
  void initState() {
    super.initState();
    _sseSub = RealtimeService.instance.events.listen((event) {
      if (event.type == 'NOTIFICATION' || event.type == 'SYSTEM_ANNOUNCEMENT') {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    try {
      await widget.api.send('PATCH', '/notifications/read-all');
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas as notificações foram marcadas como lidas.'),
          ),
        );
      }
    } catch (_) {}
  }

  Future<
    ({
      List<Map<String, dynamic>> notices,
      List<Map<String, dynamic>> announcements,
    })
  >
  _fetch() async {
    final noticeResult = await widget.api.get('/notifications/my');
    dynamic announcementResult;
    if (widget.condominiumId != null) {
      try {
        announcementResult = await widget.api.get(
          '/condominiums/${widget.condominiumId}/announcements',
        );
      } catch (_) {}
    }
    final notices = noticeResult is List
        ? noticeResult.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final announcements = announcementResult is List
        ? announcementResult.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    return (notices: notices, announcements: announcements);
  }

  Future<void> _refresh() async => setState(() => _load = _fetch());

  Future<void> _respondToInvitation(
    Map<String, dynamic> notification, {
    required bool accept,
  }) async {
    final invitationId = notification['invitationId'];
    if (invitationId == null) return;
    try {
      await widget.api.send(
        'POST',
        '/membership-invitations/$invitationId/${accept ? 'accept' : 'decline'}',
      );
      if (notification['id'] != null && notification['read'] != true) {
        try {
          await widget.api.send(
            'PATCH',
            '/notifications/${notification['id']}/read',
          );
        } catch (_) {}
      }
      await _refresh();
      await widget.onInvitationChanged?.call();
      if (mounted) {
        final role = notification['authority']?.toString();
        final needsNewSession =
            accept && (role == 'ROLE_DOORMAN' || role == 'ROLE_MANAGER');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? needsNewSession
                        ? 'Convite aceito com sucesso! Caso seu painel de função não atualize sozinho, saia e entre novamente.'
                        : 'Convite aceito! Seu acesso ao condomínio já está liberado.'
                  : 'Convite recusado.',
            ),
          ),
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

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat("dd/MM/yyyy 'às' HH:mm").format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  String _roleLabel(String? authority) => switch (authority) {
    'ROLE_MANAGER' => 'Síndico',
    'ROLE_DOORMAN' => 'Porteiro',
    'ROLE_RESIDENT' => 'Morador',
    _ => 'Membro',
  };

  String _originOf(Map<String, dynamic> item, {bool announcement = false}) {
    if (announcement) return 'CONDOMINIUM';
    final origin = item['origin']?.toString();
    if (origin != null && origin.isNotEmpty) return origin;
    return switch (item['type']) {
      'SYSTEM_ANNOUNCEMENT' => 'ADMIN',
      'ANNOUNCEMENT' => 'CONDOMINIUM',
      _ => 'SYSTEM',
    };
  }

  static const _originLabels = <String, String>{
    'ALL': 'Todas',
    'SYSTEM': 'Sistema',
    'ADMIN': 'Administrador',
    'CONDOMINIUM': 'Condomínio',
  };

  (IconData, Color, Color) _originStyle(String origin) => switch (origin) {
    'ADMIN' => (
      Icons.admin_panel_settings_outlined,
      const Color(0xFFEDE9FE),
      const Color(0xFF6D28D9),
    ),
    'CONDOMINIUM' => (
      Icons.apartment_rounded,
      const Color(0xFFFEF3C7),
      const Color(0xFFB45309),
    ),
    _ => (
      Icons.smart_toy_outlined,
      const Color(0xFFE0F2FE),
      const Color(0xFF0369A1),
    ),
  };

  Widget _originTag(String origin, {String? detail}) {
    final (icon, bg, fg) = _originStyle(origin);
    final label = _originLabels[origin] ?? origin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              detail == null || detail.isEmpty ? label : '$label • $detail',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(Map<String, dynamic> item, {bool announcement = false}) =>
      recordMatchesQuery(item, _query) &&
      (_originFilter == 'ALL' ||
          _originOf(item, announcement: announcement) == _originFilter);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: SaaSColors.background(isDark),
      appBar: AppBar(
        title: const Text('Central de Notificações'),
        backgroundColor: SaaSColors.surface(isDark),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como lidas',
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Atualizar notificações',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<
        ({
          List<Map<String, dynamic>> notices,
          List<Map<String, dynamic>> announcements,
        })
      >(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SaaSLoadingState(
                  message: 'Carregando notificações e avisos...',
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível carregar as notificações.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SaaSColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ShadButton.outline(
                      onPressed: _refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final filteredAnnouncements = data.announcements
              .where((item) => _matches(item, announcement: true))
              .toList();
          final filteredNotices = data.notices
              .where((item) => _matches(item))
              .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  // Search & Filter header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    decoration: BoxDecoration(
                      color: SaaSColors.surface(isDark),
                      border: Border(
                        bottom: BorderSide(color: SaaSColors.border(isDark)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EnterSearchField(
                          hintText: 'Pesquisar avisos e notificações (Enter)',
                          onSubmitted: (value) => setState(() => _query = value),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _originLabels.entries.map((entry) {
                              final isSelected = _originFilter == entry.key;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(entry.value),
                                  selected: isSelected,
                                  onSelected: (_) => setState(
                                    () => _originFilter = entry.key,
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : SaaSColors.textSecondary(isDark),
                                  ),
                                  selectedColor: SaaSColors.primary,
                                  backgroundColor: SaaSColors.surfaceSubtle(isDark),
                                  side: BorderSide(
                                    color: isSelected
                                        ? SaaSColors.primary
                                        : SaaSColors.border(isDark),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Notifications & Announcements Stream
                  Expanded(
                    child: (filteredAnnouncements.isEmpty && filteredNotices.isEmpty)
                        ? const SaaSEmptyState(
                            icon: Icons.notifications_off_outlined,
                            title: 'Nenhuma notificação encontrada',
                            description:
                                'Você está em dia com todos os avisos e comunicados do seu condomínio.',
                          )
                        : ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              if (filteredAnnouncements.isNotEmpty) ...[
                                SaaSSectionHeader(
                                  title: 'Comunicados do Condomínio',
                                  badge: SaaSBadge(
                                    label: '${filteredAnnouncements.length}',
                                    variant: SaaSBadgeVariant.warning,
                                  ),
                                ),
                                ...filteredAnnouncements.map(
                                  (item) => _buildAnnouncementCard(item, isDark),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (filteredNotices.isNotEmpty) ...[
                                SaaSSectionHeader(
                                  title: 'Notificações Pessoais & Sistema',
                                  badge: SaaSBadge(
                                    label: '${filteredNotices.length}',
                                    variant: SaaSBadgeVariant.primary,
                                  ),
                                ),
                                ...filteredNotices.map(
                                  (item) => _buildNoticeCard(item, isDark),
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
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item, bool isDark) {
    final title = item['title']?.toString() ?? 'Comunicado';
    final content = item['content']?.toString() ?? '';
    final createdAt = _formatDate(item['createdAt']);
    final imageUrl = item['imageUrl']?.toString();

    return SaaSCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _originTag('CONDOMINIUM'),
              const Spacer(),
              Text(
                createdAt,
                style: TextStyle(
                  fontSize: 11.5,
                  color: SaaSColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SaaSColors.textPrimary(isDark),
              letterSpacing: -0.2,
            ),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                color: SaaSColors.textSecondary(isDark),
                height: 1.4,
              ),
            ),
          ],
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClickableImagePreview(
              imageSource: imageUrl,
              title: title,
              height: 180,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> item, bool isDark) {
    final origin = _originOf(item);
    final title = item['title']?.toString() ?? 'Notificação';
    final body = item['body']?.toString() ?? item['message']?.toString() ?? '';
    final createdAt = _formatDate(item['createdAt']);
    final isRead = item['read'] == true;
    final isInvitation = item['type'] == 'MEMBERSHIP_INVITATION';

    return SaaSCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: isRead ? null : SaaSColors.primary.withValues(alpha: 0.4),
      backgroundColor: isRead
          ? null
          : (isDark
              ? SaaSColors.primary.withValues(alpha: 0.08)
              : const Color(0xFFF0F7FF)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _originTag(origin),
              if (!isRead) ...[
                const SizedBox(width: 8),
                const SaaSBadge(
                  label: 'Nova',
                  variant: SaaSBadgeVariant.primary,
                ),
              ],
              if (isInvitation && item['authority'] != null) ...[
                const SizedBox(width: 8),
                SaaSBadge(
                  label: _roleLabel(item['authority']?.toString()),
                  variant: SaaSBadgeVariant.neutral,
                ),
              ],
              const Spacer(),
              Text(
                createdAt,
                style: TextStyle(
                  fontSize: 11.5,
                  color: SaaSColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
              color: SaaSColors.textPrimary(isDark),
              letterSpacing: -0.2,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              body,
              style: TextStyle(
                fontSize: 13,
                color: SaaSColors.textSecondary(isDark),
                height: 1.4,
              ),
            ),
          ],
          if (isInvitation) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _respondToInvitation(item, accept: false),
                  child: const Text('Recusar'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _respondToInvitation(item, accept: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: SaaSColors.success,
                  ),
                  child: const Text('Aceitar Convite'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
