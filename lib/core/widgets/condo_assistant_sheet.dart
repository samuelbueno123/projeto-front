import 'package:flutter/material.dart';

import '../../features/community/data/community_api.dart';
import '../../features/home/data/home_service.dart';
import '../theme/app_theme.dart';

/// Painel interativo do Assistente do Condomínio integrado ao endpoint real
/// `/condominiums/{id}/assistant/query`.
class CondoAssistantSheet extends StatefulWidget {
  const CondoAssistantSheet({
    super.key,
    required this.api,
    required this.condominiumId,
    this.condominiumName = 'Condomínio',
  });

  final HomeService api;
  final num condominiumId;
  final String condominiumName;

  static Future<void> show(
    BuildContext context, {
    required HomeService api,
    required num condominiumId,
    String condominiumName = 'Condomínio',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CondoAssistantSheet(
        api: api,
        condominiumId: condominiumId,
        condominiumName: condominiumName,
      ),
    );
  }

  @override
  State<CondoAssistantSheet> createState() => _CondoAssistantSheetState();
}

class _CondoAssistantSheetState extends State<CondoAssistantSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final List<_AssistantMsg> _messages = [];
  bool _sending = false;

  static const _suggestions = [
    'Tenho encomendas pendentes?',
    'Qual o status das minhas reservas?',
    'Há boletos em aberto?',
    'Quais os contatos de emergência?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _AssistantMsg(
        fromUser: false,
        text:
            'Olá! Sou o assistente inteligente de ${widget.condominiumName}. '
            'Pergunte sobre suas encomendas, reservas, comunicados, boletos ou regras.',
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_AssistantMsg(fromUser: true, text: text));
      _sending = true;
    });
    try {
      final res = await CommunityApi(
        api: widget.api,
      ).askAssistant(widget.condominiumId, text);
      if (!mounted) return;
      final answer =
          res['answer']?.toString() ??
          res['response']?.toString() ??
          res['message']?.toString() ??
          'Não encontrei informações adicionais para essa pergunta.';
      setState(() {
        _messages.add(_AssistantMsg(fromUser: false, text: answer));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AssistantMsg(
            fromUser: false,
            text: 'Não consegui consultar o assistente agora: $e',
          ),
        );
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: tokens.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assistente do Condomínio',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          widget.condominiumName,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: const BoxConstraints(maxWidth: 440),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: msg.fromUser
                            ? tokens.accent
                            : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: msg.fromUser
                            ? null
                            : Border.all(color: tokens.border),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: msg.fromUser
                              ? Colors.white
                              : tokens.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: _suggestions.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      onPressed: _sending ? null : () => _ask(s),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(top: BorderSide(color: tokens.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _ask(),
                      decoration: const InputDecoration(
                        hintText: 'Faça sua pergunta ao assistente...',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending ? null : () => _ask(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantMsg {
  const _AssistantMsg({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}
