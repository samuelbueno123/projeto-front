import 'package:flutter/material.dart';

import '../../../../core/widgets/enter_search_field.dart';
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
                        ? 'Convite aceito. Saia e entre novamente para atualizar seus acessos.'
                        : 'Convite aceito.'
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

  bool _matches(Map<String, dynamic> item) => recordMatchesQuery(item, _query);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notificações'),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
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
            final announcements = data.announcements.where(_matches).toList();
            Widget card(
              Map<String, dynamic> item, {
              bool announcement = false,
            }) {
              final image = item['imageUrl'] as String?;
              final isMembershipInvitation =
                  !announcement &&
                  item['type'] == 'MEMBERSHIP_INVITATION' &&
                  item['invitationId'] != null;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: !announcement && item['read'] != true
                      ? () async {
                          await widget.api.send(
                            'PATCH',
                            '/notifications/${item['id']}/read',
                          );
                          _refresh();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['title'] ?? (announcement ? 'Comunicado do condomínio' : 'Notificação')}',
                          style: TextStyle(
                            fontWeight: item['read'] == true
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item[announcement ? 'content' : 'message'] ?? ''}',
                        ),
                        if (image != null &&
                            image.startsWith('data:image/')) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              UriData.parse(image).contentAsBytes(),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${item['createdAt'] ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (isMembershipInvitation) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: () =>
                                    _respondToInvitation(item, accept: true),
                                child: const Text('Aceitar convite'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _respondToInvitation(item, accept: false),
                                child: const Text('Recusar'),
                              ),
                            ],
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  EnterSearchField(
                    hintText: 'Pesquisar notificações e comunicados',
                    onSubmitted: (query) => setState(() => _query = query),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty && announcements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Você não tem notificações ou comunicados.'),
                    ),
                  if (items.isNotEmpty) ...[
                    Text(
                      'Notificações',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...items.map(card),
                  ],
                  if (announcements.isNotEmpty) ...[
                    Text(
                      'Comunicados do condomínio',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...announcements.map((e) => card(e, announcement: true)),
                  ],
                ],
              ),
            );
          },
        ),
  );
}
