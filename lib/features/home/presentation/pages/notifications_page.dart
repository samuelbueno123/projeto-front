import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  late Future<
    ({
      List<Map<String, dynamic>> notices,
      List<Map<String, dynamic>> announcements,
    })
  >
  _load = _fetch();

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

  /// Origin of an item: SYSTEM (automatic), ADMIN (system-wide announcement
  /// from the platform administrator) or CONDOMINIUM (condominium announcement).
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Central de notificações'),
      actions: [
        IconButton(
          tooltip: 'Atualizar notificações',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body:
        FutureBuilder<
          ({
            List<Map<String, dynamic>> notices,
            List<Map<String, dynamic>> announcements,
          })
        >(
          future: _load,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final items = data.notices.where(_matches).toList();
            final announcements = data.announcements
                .where((e) => _matches(e, announcement: true))
                .toList();

            Widget buildCard(
              Map<String, dynamic> item, {
              bool announcement = false,
            }) {
              final image = item['imageUrl'] as String?;
              final invitationStatus = item['invitationStatus']?.toString();
              final isMembershipInvitation =
                  !announcement &&
                  item['type'] == 'MEMBERSHIP_INVITATION' &&
                  item['invitationId'] != null;
              final isPendingInvitation =
                  isMembershipInvitation &&
                  (invitationStatus == null || invitationStatus == 'PENDING');
              final isUnread = !announcement && item['read'] != true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isPendingInvitation
                        ? const Color(0xFF2F3FB0)
                        : isUnread
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFFE2E8F0),
                    width: isPendingInvitation ? 1.8 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: isUnread
                      ? () async {
                          await widget.api.send(
                            'PATCH',
                            '/notifications/${item['id']}/read',
                          );
                          _refresh();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isPendingInvitation
                                  ? const Color(0xFFE0E7FF)
                                  : announcement
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFEFF6FF),
                              child: Icon(
                                isPendingInvitation
                                    ? Icons.mark_email_unread_outlined
                                    : announcement
                                    ? Icons.campaign_outlined
                                    : Icons.notifications_active_outlined,
                                color: isPendingInvitation
                                    ? const Color(0xFF2F3FB0)
                                    : announcement
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF1D4ED8),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _originTag(
                                    _originOf(item, announcement: announcement),
                                    detail:
                                        _originOf(
                                              item,
                                              announcement: announcement,
                                            ) ==
                                            'CONDOMINIUM'
                                        ? item['condominiumName']?.toString()
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${item['title'] ?? (announcement ? 'Comunicado do condomínio' : 'Notificação')}',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(item['createdAt']),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (isUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Nova',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (isMembershipInvitation &&
                            item['condominiumName'] != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Condomínio: ${item['condominiumName']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2F3FB0),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Função: ${_roleLabel(item['authority']?.toString())}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          '${item[announcement ? 'content' : 'message'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF334155),
                            height: 1.45,
                          ),
                        ),
                        if (image != null && image.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClickableImagePreview(
                            imageSource: image,
                            title: item['title']?.toString(),
                            height: 190,
                          ),
                        ],
                        if (isPendingInvitation) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _respondToInvitation(item, accept: true),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Aceitar convite'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _respondToInvitation(item, accept: false),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Recusar'),
                              ),
                            ],
                          ),
                        ] else if (isMembershipInvitation &&
                            invitationStatus != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  invitationStatus == 'ACTIVE' ||
                                      invitationStatus == 'ACCEPTED'
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  invitationStatus == 'ACTIVE' ||
                                          invitationStatus == 'ACCEPTED'
                                      ? Icons.verified_rounded
                                      : Icons.cancel_outlined,
                                  size: 16,
                                  color:
                                      invitationStatus == 'ACTIVE' ||
                                          invitationStatus == 'ACCEPTED'
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB91C1C),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  invitationStatus == 'ACTIVE' ||
                                          invitationStatus == 'ACCEPTED'
                                      ? 'Convite aceito'
                                      : 'Convite recusado',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        invitationStatus == 'ACTIVE' ||
                                            invitationStatus == 'ACCEPTED'
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      EnterSearchField(
                        hintText:
                            'Pesquisar notificações e comunicados (Enter)',
                        onSubmitted: (query) => setState(() => _query = query),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final entry in _originLabels.entries) ...[
                              ChoiceChip(
                                avatar: entry.key == 'ALL'
                                    ? null
                                    : Icon(
                                        _originStyle(entry.key).$1,
                                        size: 16,
                                        color: _originStyle(entry.key).$3,
                                      ),
                                label: Text(entry.value),
                                selected: _originFilter == entry.key,
                                onSelected: (_) =>
                                    setState(() => _originFilter = entry.key),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (items.isEmpty && announcements.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Color(0xFFE8ECFF),
                                  child: Icon(
                                    Icons.notifications_none_rounded,
                                    size: 30,
                                    color: Color(0xFF2F3FB0),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Tudo em dia por aqui!',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Você não tem notificações ou comunicados no momento.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (items.isNotEmpty) ...[
                        Text(
                          'Suas notificações',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        ...items.map(buildCard),
                      ],
                      if (announcements.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Comunicados do condomínio',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        ...announcements.map(
                          (e) => buildCard(e, announcement: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
  );
}
