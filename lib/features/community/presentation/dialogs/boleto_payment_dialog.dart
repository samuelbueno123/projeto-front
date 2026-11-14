import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/community_api.dart';
import 'unit_payment_confirmation_dialog.dart';

class BoletoPaymentDialog extends StatefulWidget {
  const BoletoPaymentDialog({
    super.key,
    required this.condominiumId,
    required this.unitId,
    required this.unitLabel,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.digitableLine,
    required this.status,
    required this.api,
    required this.onPaid,
  });

  final num condominiumId;
  final num unitId;
  final String unitLabel;
  final String title;
  final double amount;
  final String dueDate;
  final String digitableLine;
  final String status;
  final CommunityApi api;
  final VoidCallback onPaid;

  @override
  State<BoletoPaymentDialog> createState() => _BoletoPaymentDialogState();
}

class _BoletoPaymentDialogState extends State<BoletoPaymentDialog> {
  int _paymentMethod = 0; // 0: PIX, 1: Boleto Bancário
  bool _processing = false;
  bool _copied = false;
  String? _error;

  String get _pixPayload {
    final amt = widget.amount.toStringAsFixed(2);
    return '00020126580014br.gov.bcb.pix0136ancora-${widget.condominiumId}-u${widget.unitId}5204000053039865405$amt'
        '5802BR5915CONDOMINIO ANCORA6009RIO DE JANEIRO62070503***6304';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPaid = widget.status.toUpperCase() == 'PAID' || widget.status.toUpperCase() == 'UP_TO_DATE';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isPaid ? Icons.check_circle_rounded : Icons.payments_rounded,
                        color: isPaid ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.unitLabel,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 13,
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
                const SizedBox(height: 18),

                // Valor & Vencimento
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Valor Total',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'R\$ ${widget.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Vencimento',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.dueDate,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPaid ? 'Pago' : 'Em aberto',
                              style: TextStyle(
                                color: isPaid ? const Color(0xFF15803D) : const Color(0xFFBE123C),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!isPaid) ...[
                  // Alternador PIX / Boleto
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _paymentMethod = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _paymentMethod == 0
                                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _paymentMethod == 0
                                    ? [const BoxShadow(color: Color(0x11000000), blurRadius: 4)]
                                    : null,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 16,
                                      color: _paymentMethod == 0 ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'PIX Instantâneo',
                                      style: TextStyle(
                                        fontWeight: _paymentMethod == 0 ? FontWeight.bold : FontWeight.w500,
                                        color: _paymentMethod == 0 ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _paymentMethod = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _paymentMethod == 1
                                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _paymentMethod == 1
                                    ? [const BoxShadow(color: Color(0x11000000), blurRadius: 4)]
                                    : null,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 16,
                                      color: _paymentMethod == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Boleto Bancário',
                                      style: TextStyle(
                                        fontWeight: _paymentMethod == 1 ? FontWeight.bold : FontWeight.w500,
                                        color: _paymentMethod == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conteúdo do Método Selecionado
                  if (_paymentMethod == 0) ...[
                    // PIX Section
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      crossAxisSpacing: 3,
                                      mainAxisSpacing: 3,
                                    ),
                                    itemCount: 49,
                                    itemBuilder: (context, idx) {
                                      final isCorner = (idx < 3 || (idx % 7 < 3 && idx < 21)) ||
                                          (idx % 7 > 3 && idx < 3) ||
                                          (idx >= 42 && idx % 7 < 3);
                                      final isPattern = idx % 2 == 0 || idx % 3 == 0 || isCorner;
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: isPattern ? const Color(0xFF0F172A) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.qr_code_2_rounded, size: 28, color: Color(0xFF0D9488)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Escaneie o QR Code no app do seu banco',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pix Copia e Cola
                    const Text('Pix Copia e Cola', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _pixPayload,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copiar código PIX',
                            icon: Icon(
                              _copied ? Icons.check_rounded : Icons.copy_rounded,
                              size: 18,
                              color: _copied ? const Color(0xFF15803D) : const Color(0xFF0D9488),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _pixPayload));
                              setState(() => _copied = true);
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) setState(() => _copied = false);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Boleto Section
                    const Text('Linha Digitável / Código de Barras',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.digitableLine.trim().isNotEmpty
                                  ? widget.digitableLine
                                  : 'Linha digitável indisponível',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copiar código de barras',
                            icon: Icon(
                              _copied ? Icons.check_rounded : Icons.copy_rounded,
                              size: 18,
                              color: widget.digitableLine.trim().isEmpty
                                  ? Colors.grey
                                  : (_copied ? const Color(0xFF15803D) : const Color(0xFF2563EB)),
                            ),
                            onPressed: widget.digitableLine.trim().isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(ClipboardData(text: widget.digitableLine));
                                    setState(() => _copied = true);
                                    Future.delayed(const Duration(seconds: 2), () {
                                      if (mounted) setState(() => _copied = false);
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                  ],

                  const SizedBox(height: 18),

                  // Botões de Ação
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => UnitPaymentConfirmationDialog(
                                api: widget.api,
                                condominiumId: widget.condominiumId,
                              ),
                            );
                            widget.onPaid();
                          },
                          icon: const Icon(Icons.upload_file_outlined, size: 18),
                          label: const Text('Enviar Comprovante'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _paymentMethod == 0 ? const Color(0xFF0D9488) : const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _processing ? null : _payNow,
                          icon: _processing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(_processing ? 'Processando...' : 'Pagar agora / Simular Pagamento'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Cota Condominial Liquidada',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _payNow() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await widget.api.payBoleto(widget.condominiumId, widget.unitId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pagamento confirmado com sucesso! Cota baixada no sistema.'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
      Navigator.of(context).pop();
      widget.onPaid();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Erro ao processar pagamento: $e';
      });
    }
  }
}
