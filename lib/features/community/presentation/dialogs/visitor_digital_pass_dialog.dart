import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/community_api.dart';

class VisitorDigitalPassDialog extends StatefulWidget {
  const VisitorDigitalPassDialog({
    super.key,
    required this.visitorId,
    required this.api,
  });

  final num visitorId;
  final CommunityApi api;

  @override
  State<VisitorDigitalPassDialog> createState() => _VisitorDigitalPassDialogState();
}

class _VisitorDigitalPassDialogState extends State<VisitorDigitalPassDialog> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _pass;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadPass();
  }

  Future<void> _loadPass() async {
    try {
      final data = await widget.api.getVisitorDigitalPass(widget.visitorId);
      if (mounted) {
        setState(() {
          _pass = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao gerar convite digital: $e';
          _loading = false;
        });
      }
    }
  }

  void _copyMessage() {
    final msg = _pass?['whatsappMessageText']?.toString() ?? '';
    if (msg.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: msg));
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.share_rounded, color: Color(0xFF15803D), size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Convite Digital de Acesso',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                  ),
                                  Text(
                                    'Envie as orientações ao visitante via WhatsApp',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                        const SizedBox(height: 20),

                        // Code card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _pass?['visitorName']?.toString() ?? 'Visitante',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_pass?['unitLabel'] ?? ''} • ${_pass?['condominiumName'] ?? ''}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF93C5FD)),
                                ),
                                child: Text(
                                  _pass?['accessCode']?.toString() ?? '------',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text('Código de liberação rápida na portaria', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Actions
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _copyMessage,
                          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 20),
                          label: Text(_copied ? 'Copiado para a área de transferência!' : 'Copiar Texto para WhatsApp'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
