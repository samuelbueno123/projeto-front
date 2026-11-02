import 'dart:async';
import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _timer;

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
    _loadMessages();
    // Real-time polling every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  Future<void> _pollMessages() async {
    try {
      final list = await widget.api.getChatMessages(
        widget.condominiumId,
        targetUserId: widget.targetUserId,
      );
      if (!mounted) return;
      if (list.length != _messages.length) {
        setState(() => _messages = list);
        _scrollToBottom();
      }
      // Marca como lido
      await widget.api.markChatAsRead(widget.condominiumId);
    } catch (e) {
      if (_loading && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                      widget.isDoormanMode
                          ? (widget.targetUserName ?? 'Conversa com Morador')
                          : 'Portaria & Guarita',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isDoormanMode && widget.targetUnitLabel != null
                              ? widget.targetUnitLabel!
                              : 'Conectado em tempo real',
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
                onPressed: _pollMessages,
              ),
            ],
          ),
        ),

        // Message area
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('Erro: $_error'))
              : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 48, color: theme.disabledColor),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhuma mensagem ainda.\nEnvie uma mensagem para a portaria!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final msg = _messages[i];
                    final isMe = widget.isDoormanMode
                        ? (msg['senderRole'] == 'DOORMAN' || msg['senderRole'] == 'MANAGER')
                        : msg['senderRole'] == 'RESIDENT';
                    final senderName = msg['senderName']?.toString() ?? '';
                    final text = msg['message']?.toString() ?? '';
                    final sentAt = msg['sentAt']?.toString() ?? '';
                    final timeStr = sentAt.contains('T')
                        ? sentAt.split('T').last.substring(0, 5)
                        : '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E3A8A),
                                ),
                              ),
                            Text(
                              text,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : (isDark ? Colors.white60 : Colors.black45),
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
                        ? 'Responder ao morador...'
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
    setState(() => _sending = true);
    try {
      await widget.api.sendChatMessage(
        widget.condominiumId,
        message: text,
        recipientId: widget.targetUserId,
      );
      _msgCtrl.clear();
      await _pollMessages();
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
