import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class UnitPaymentConfirmationDialog extends StatefulWidget {
  const UnitPaymentConfirmationDialog({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final CommunityApi api;
  final num condominiumId;

  @override
  State<UnitPaymentConfirmationDialog> createState() => _UnitPaymentConfirmationDialogState();
}

class _UnitPaymentConfirmationDialogState extends State<UnitPaymentConfirmationDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];
  final _noteController = TextEditingController();
  num? _selectedUnitId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    try {
      final list = await widget.api.getMyPayments(widget.condominiumId);
      if (!mounted) return;
      setState(() {
        _payments = list;
        if (_payments.isNotEmpty) {
          _selectedUnitId = _payments.first['unitId'];
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRequest(num unitId) async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe uma descrição ou código do comprovante.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.api.requestPaymentConfirmation(
        condoId: widget.condominiumId,
        unitId: unitId,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF15803D),
          content: Text('Solicitação de confirmação de pagamento enviada com sucesso à administração!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar solicitação: $e')),
      );
    }
  }

  (String, Color, Color) _statusInfo(dynamic status) => switch (status) {
        'PAID' => ('Pago / Em dia', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
        'CONFIRMATION_REQUESTED' => ('Confirmação Solicitada', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
        'OVERDUE' => ('Em atraso', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
        _ => ('Pendente', const Color(0xFFF1F5F9), const Color(0xFF334155)),
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFE0E7FF),
            child: Icon(Icons.receipt_long_rounded, color: Color(0xFF2F3FB0)),
          ),
          SizedBox(width: 12),
          Text('Taxa Condominial'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : _payments.isEmpty
                ? const Text('Nenhuma cobrança registrada para a sua unidade.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._payments.map((p) {
                          final status = p['paymentStatus']?.toString();
                          final style = _statusInfo(status);
                          final unitId = p['unitId'] as num;
                          final isPaid = status == 'PAID';
                          final isRequested = status == 'CONFIRMATION_REQUESTED';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Unidade ${p['unitIdentifier'] ?? '—'} • ${p['sectorName'] ?? ''}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: style.$2,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        style.$1,
                                        style: TextStyle(
                                          color: style.$3,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (p['amount'] != null)
                                      Text(
                                        'Valor: R\$ ${p['amount']}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      ),
                                    if (p['dueDate'] != null) ...[
                                      const SizedBox(width: 14),
                                      Text(
                                        'Vencimento: ${p['dueDate']}',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                      ),
                                    ],
                                  ],
                                ),
                                if (p['paymentNote'] != null && p['paymentNote'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Nota informada: ${p['paymentNote']}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                if (!isPaid && !isRequested)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.check_circle_outline, size: 18),
                                      label: const Text('Informar Pagamento Efetuado'),
                                      onPressed: () {
                                        setState(() => _selectedUnitId = unitId);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (_selectedUnitId != null &&
                            _payments.any((p) => p['unitId'] == _selectedUnitId && p['paymentStatus'] != 'PAID' && p['paymentStatus'] != 'CONFIRMATION_REQUESTED')) ...[
                          const Divider(height: 24),
                          const Text(
                            'Envie os dados do pagamento para aprovação do síndico:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Comprovante / Código PIX / Autenticação *',
                              hintText: 'Ex: Pago via PIX pelo Nubank em 30/10. Autenticação #98721',
                              prefixIcon: Icon(Icons.receipt_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : () => _submitRequest(_selectedUnitId!),
                              icon: _submitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: const Text('Solicitar Confirmação de Pagamento'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
