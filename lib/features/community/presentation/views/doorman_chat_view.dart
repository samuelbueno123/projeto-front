import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/community_api.dart';

class DoormanChatView extends StatefulWidget {
  const DoormanChatView({
    super.key,
    required this.condominiumId,
    required this.api,
    this.isDoormanMode = false,
    this.targetUserId,
    this.targetUserName,
    this.targetUnitLabel,
  });

  final num condominiumId;
  final CommunityApi api;
  final bool isDoormanMode;
  final num? targetUserId;
  final String? targetUserName;
  final String? targetUnitLabel;

  @override
  State<DoormanChatView> createState() => _DoormanChatViewState();
}

class _DoormanChatViewState extends State<DoormanChatView> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _timer;
  StreamSubscription<RealtimeEvent>? _sseSub;

  // Conversations list for Doorman mode
  List<Map<String, dynamic>> _conversations = [];
  bool _loadingConversations = false;
  String _searchQuery = '';
  Map<String, dynamic>? _selectedResident;
  num? _currentUserId;

  static const _residentPresets = [
    'Minha encomenda já chegou?',
    'Vou descer para receber a entrega.',
    'Visitante liberado para subir.',
    'Preciso de auxílio na portaria.',
  ];

  static const _doormanPresets = [
    'Sua encomenda chegou na portaria.',
    'Seu visitante acabou de se identificar.',
    'Favor retirar seu pacote na portaria.',
    'Portão de pedestres liberado.',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();

    if (widget.isDoormanMode) {
      if (widget.targetUserId != null) {
        _selectedResident = {
          'userId': widget.targetUserId,
          'userName': widget.targetUserName ?? 'Morador',
          'unitLabel': widget.targetUnitLabel ?? 'Unidade',
        };
        _loadMessages();
      }
      _loadConversations();
    } else {
      _loadMessages();
    }

    // Sincronização em tempo real via Server-Sent Events (SSE)
    _sseSub = RealtimeService.instance.events.listen((event) {
      if (event.type == 'CHAT_MESSAGE') {
        if (event.condominiumId == null || event.condominiumId == widget.condominiumId) {
          _handleIncomingChatMessage(event.data);
          if (widget.isDoormanMode) {
            _loadConversations(silent: true);
          }
        }
      }
    });

    // Fallback de polling a cada 20 segundos
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (!widget.isDoormanMode || _selectedResident != null) {
        _pollMessages(silent: true);
      }
      if (widget.isDoormanMode) {
        _loadConversations(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  num? get _activeTargetUserId {
    if (!widget.isDoormanMode) return null;
    return _selectedResident?['userId'] as num? ?? widget.targetUserId;
  }

  String get _activeTargetUserName {
    if (!widget.isDoormanMode) return 'Portaria & Guarita';
    return _selectedResident?['userName']?.toString() ?? widget.targetUserName ?? 'Conversa com Morador';
  }

  String? get _activeTargetUnitLabel {
    if (!widget.isDoormanMode) return null;
    return _selectedResident?['unitLabel']?.toString() ?? widget.targetUnitLabel;
  }

  Future<void> _loadCurrentUser() async {
    try {
      final res = await widget.api.api.get('/users/me');
      if (res is Map && mounted) {
        setState(() {
          _currentUserId = res['id'] as num?;
        });
      }
    } catch (_) {}
  }

  void _handleIncomingChatMessage(dynamic data) {
    if (!mounted || data == null) return;
    final Map<String, dynamic> msg =
        data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (msg.isEmpty) return;

    if (widget.isDoormanMode) {
      final targetId = _activeTargetUserId;
      if (targetId == null) return;
      final senderId = msg['senderId'];
      final recipientId = msg['recipientId'];
      if (senderId != targetId && recipientId != targetId) {
        return;
      }
    } else {
      // RESIDENT MODE: only accept messages between this resident and portaria
      final myId = _currentUserId;
      if (myId != null) {
        final senderId = msg['senderId'];
        final recipientId = msg['recipientId'];
        if (senderId != myId && recipientId != myId) {
          return;
        }
      }
    }

    final id = msg['id'];
    if (id != null && _messages.any((m) => m['id'] == id)) {
      return;
    }

    setState(() {
      _messages.add(msg);
    });
    _scrollToBottom();
    widget.api.markChatAsRead(widget.condominiumId).catchError((_) {});
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!widget.isDoormanMode) return;
    if (!silent) setState(() => _loadingConversations = true);
    try {
      final list = await widget.api.getChatConversations(widget.condominiumId);
      if (mounted) {
        setState(() {
          _conversations = list;
          _loadingConversations = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _loadingConversations = false);
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _pollMessages();
    if (!mounted) return;
    setState(() => _loading = false);
    _scrollToBottom();
  }

  Future<void> _pollMessages({bool silent = false}) async {
    final targetId = _activeTargetUserId;
    if (widget.isDoormanMode && targetId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final list = await widget.api.getChatMessages(
        widget.condominiumId,
        targetUserId: targetId,
      );
      if (!mounted) return;
      if (list.length != _messages.length || _messages.isEmpty) {
        setState(() => _messages = list);
        _scrollToBottom();
        await widget.api.markChatAsRead(widget.condominiumId);
      }
    } catch (e) {
      if (!silent && _loading && mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectResident(Map<String, dynamic> resident) {
    setState(() {
      _selectedResident = resident;
      _messages = [];
    });
    _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    // If Doorman mode on Desktop: 2-column view (residents list on left, chat on right)
    if (widget.isDoormanMode && isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Conversations list
          SizedBox(
            width: 320,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: _buildConversationsList(isDark),
            ),
          ),

          // Right: Active Chat Area
          Expanded(
            child: _selectedResident != null
                ? _buildChatConversationView(isDark, theme, showBack: false)
                : _buildNoConversationSelectedPlaceholder(isDark),
          ),
        ],
      );
    }

    // Doorman mode on Mobile/Tablet:
    if (widget.isDoormanMode) {
      if (_selectedResident == null) {
        return _buildConversationsList(isDark);
      }
      return _buildChatConversationView(isDark, theme, showBack: true);
    }

    // Resident Mode (Direct Chat with Portaria)
    return _buildChatConversationView(isDark, theme, showBack: false);
  }

  Widget _buildConversationsList(bool isDark) {
    final filtered = _conversations.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (c['userName'] ?? '').toString().toLowerCase();
      final unit = (c['unitLabel'] ?? '').toString().toLowerCase();
      final last = (c['lastMessage'] ?? '').toString().toLowerCase();
      return name.contains(q) || unit.contains(q) || last.contains(q);
    }).toList();

    return Column(
      children: [
        // Header & Search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Text(
                    'Conversas com Moradores',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Atualizar lista de moradores',
                    onPressed: () => _loadConversations(silent: false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Buscar morador ou unidade...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loadingConversations
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: SaaSLoadingState(
                      message: 'Carregando conversas...',
                    ),
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Nenhum morador cadastrado neste condomínio.'
                                  : 'Nenhum morador encontrado para "$_searchQuery".',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = _selectedResident != null &&
                            _selectedResident!['userId'] == item['userId'];
                        final unread = (item['unreadCount'] as num?)?.toInt() ?? 0;
                        final lastMsg = item['lastMessage']?.toString();
                        final name = item['userName']?.toString() ?? 'Morador';
                        final unit = item['unitLabel']?.toString() ?? '';

                        return InkWell(
                          onTap: () => _selectResident(item),
                          child: Container(
                            color: isSelected
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                                : null,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isSelected
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                fontSize: 13.5,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          if (unread > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$unread',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      if (unit.isNotEmpty)
                                        Text(
                                          unit,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (lastMsg != null && lastMsg.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          lastMsg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
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
        ),
      ],
    );
  }

  Widget _buildNoConversationSelectedPlaceholder(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Atendimento Privado da Portaria',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecione um morador na lista ao lado para abrir o chat privado individual com ele.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatConversationView(bool isDark, ThemeData theme, {required bool showBack}) {
    return Column(
      children: [
        // Top chat bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
          ),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Voltar às conversas',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => _selectedResident = null),
                ),
              CircleAvatar(
                radius: 20,
                backgroundColor: widget.isDoormanMode
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFDCFCE7),
                child: Icon(
                  widget.isDoormanMode ? Icons.person_rounded : Icons.security_rounded,
                  color: widget.isDoormanMode ? const Color(0xFF2563EB) : const Color(0xFF15803D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeTargetUserName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        StreamBuilder<RealtimeConnectionState>(
                          stream: RealtimeService.instance.connectionState,
                          initialData: RealtimeService.instance.state,
                          builder: (context, snapshot) {
                            final connected = snapshot.data == RealtimeConnectionState.connected;
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: connected ? const Color(0xFF22C55E) : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _activeTargetUnitLabel ?? 'Conectado em tempo real',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atualizar mensagens',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => _pollMessages(silent: false),
              ),
            ],
          ),
        ),

        // Message list
        Expanded(
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: SaaSLoadingState(
                      message: 'Carregando mensagens do chat...',
                    ),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SaaSErrorState(
                          message: 'Erro ao carregar mensagens: $_error',
                          onRetry: _loadMessages,
                        ),
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 52,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Nenhuma mensagem trocada ainda.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isDoormanMode
                                    ? 'Inicie uma conversa privada com o morador abaixo.'
                                    : 'Envie um aviso ou tire dúvidas direto com os porteiros de plantão.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final m = _messages[i];
                            final role = m['senderRole']?.toString() ?? 'RESIDENT';
                            final isMe = widget.isDoormanMode
                                ? (role == 'DOORMAN' || role == 'MANAGER')
                                : (role == 'RESIDENT');

                            final sender = m['senderName']?.toString() ?? (isMe ? 'Eu' : 'Portaria');
                            final text = m['message']?.toString() ?? '';
                            final timeRaw = m['sentAt']?.toString() ?? '';
                            final time = timeRaw.isNotEmpty ? formatTime(timeRaw) : '';

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF2563EB)
                                      : isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          sender,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe
                                            ? Colors.white
                                            : isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isMe
                                            ? Colors.white.withValues(alpha: 0.7)
                                            : isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),

        // Respostas Rápidas
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                ...(widget.isDoormanMode ? _doormanPresets : _residentPresets).map(
                  (preset) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 11.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      onPressed: () {
                        _msgCtrl.text = preset;
                        _send();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: widget.isDoormanMode
                        ? 'Enviar mensagem privada para $_activeTargetUserName...'
                        : 'Escreva uma mensagem para a portaria...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFF2563EB),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _sending ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final targetId = _activeTargetUserId;
    if (widget.isDoormanMode && targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um morador para conversar.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.api.sendChatMessage(
        widget.condominiumId,
        message: text,
        recipientId: targetId,
        unitId: _selectedResident?['unitId'] as num?,
      );
      _msgCtrl.clear();
      await _pollMessages(silent: true);
      if (widget.isDoormanMode) {
        _loadConversations(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
