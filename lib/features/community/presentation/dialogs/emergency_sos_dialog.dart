import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class EmergencySOSDialog extends StatefulWidget {
  const EmergencySOSDialog({
    super.key,
    required this.condominiumId,
    required this.api,
    this.unitId,
    this.onAlertSent,
  });

  final num condominiumId;
  final CommunityApi api;
  final num? unitId;
  final VoidCallback? onAlertSent;

  @override
  State<EmergencySOSDialog> createState() => _EmergencySOSDialogState();
}

class _EmergencySOSDialogState extends State<EmergencySOSDialog> {
  String _emergencyType = 'MEDICAL';
  final _detailsCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _sentSuccess = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendSOS() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.api.triggerEmergencyAlert(widget.condominiumId, {
        'emergencyType': _emergencyType,
        'details': _detailsCtrl.text.trim(),
        'contactPhone': _phoneCtrl.text.trim(),
        if (widget.unitId != null) 'unitId': widget.unitId,
      });

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sentSuccess = true;
      });
      widget.onAlertSent?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Falha ao acionar emergência: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sentSuccess) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 10),
            Text('Alerta SOS Enviado!'),
          ],
        ),
        content: const Text(
          'A portaria e a administração foram notificadas imediatamente sobre a sua emergência. Permaneça em local seguro enquanto o atendimento é acionado.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Botão de Pânico & Alerta SOS',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFFB91C1C)),
                        ),
                        Text(
                          'Aciona imediatamente a portaria e gestão do condomínio',
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
              const SizedBox(height: 18),

              const Text('Tipo de Emergência *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _emergencyType,
                items: const [
                  DropdownMenuItem(value: 'MEDICAL', child: Text('🚑 Emergência Médica / Ambulância')),
                  DropdownMenuItem(value: 'FIRE', child: Text('🔥 Fogo / Princípio de Incêndio')),
                  DropdownMenuItem(value: 'GAS_LEAK', child: Text('⚠️ Suspeita de Vazamento de Gás')),
                  DropdownMenuItem(value: 'ELEVATOR', child: Text('🛗 Passageiro Preso no Elevador')),
                  DropdownMenuItem(value: 'SECURITY_BREACH', child: Text('🚨 Segurança / Suspeita de Invasão')),
                  DropdownMenuItem(value: 'OTHER', child: Text('❗ Outra Emergência Crítica')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _emergencyType = val);
                },
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
              const SizedBox(height: 14),

              const Text('Telefone de Contato Direto', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '(XX) 9XXXX-XXXX',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              const Text('Detalhes ou Localização Adicional', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _detailsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Ex.: Apartamento 402, cheiro forte de gás perto do aquecedor...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _sendSOS,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.warning_amber_rounded, size: 20),
                  label: Text(_submitting ? 'Acionando socorro...' : 'DISPARAR ALERTA DE EMERGÊNCIA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
