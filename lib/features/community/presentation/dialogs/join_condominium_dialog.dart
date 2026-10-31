import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class JoinCondominiumDialog extends StatefulWidget {
  const JoinCondominiumDialog({
    super.key,
    required this.api,
  });

  final CommunityApi api;

  @override
  State<JoinCondominiumDialog> createState() => _JoinCondominiumDialogState();
}

class _JoinCondominiumDialogState extends State<JoinCondominiumDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _condos = [];
  Map<String, dynamic>? _selectedCondo;

  bool _loadingUnits = false;
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _selectedUnit;

  String _residentType = 'OWNER';
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCondos();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCondos() async {
    try {
      final list = await widget.api.getAvailableCondominiums();
      if (!mounted) return;
      setState(() {
        _condos = list;
        if (_condos.isNotEmpty) {
          _selectedCondo = _condos.first;
        }
        _loading = false;
      });
      if (_selectedCondo != null) {
        _loadUnits(_selectedCondo!['id']);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnits(num condoId) async {
    setState(() {
      _loadingUnits = true;
      _units = [];
      _selectedUnit = null;
    });
    try {
      final list = await widget.api.getAvailableUnits(condoId);
      if (!mounted) return;
      setState(() {
        _units = list;
        if (_units.isNotEmpty) {
          _selectedUnit = _units.first;
        }
        _loadingUnits = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUnits = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedCondo == null) return;
    setState(() => _submitting = true);

    try {
      await widget.api.createMembershipRequest(
        condoId: _selectedCondo!['id'],
        authority: 'ROLE_RESIDENT',
        unitId: _selectedUnit?['id'],
        residentType: _residentType,
        message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF15803D),
          content: Text('Solicitação enviada ao síndico! Você será notificado assim que aprovada.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar solicitação: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFE0E7FF),
            child: Icon(Icons.add_home_work_rounded, color: Color(0xFF2F3FB0)),
          ),
          SizedBox(width: 12),
          Text('Entrar em um Condomínio'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : _condos.isEmpty
                ? const Text('Nenhum condomínio aberto para solicitações de novos moradores no momento.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Envie uma solicitação para a administração do condomínio para liberar seu acesso às áreas, portaria e comunicados.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 16),

                        // Seleção do condomínio
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedCondo,
                          decoration: const InputDecoration(
                            labelText: 'Selecione o Condomínio',
                            prefixIcon: Icon(Icons.apartment_rounded),
                          ),
                          items: _condos.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c['name']?.toString() ?? 'Condomínio', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCondo = val);
                              _loadUnits(val['id']);
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Seleção da unidade
                        if (_loadingUnits)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Buscando unidades cadastradas...', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          )
                        else if (_units.isNotEmpty)
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: _selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Sua Unidade / Apartamento',
                              prefixIcon: Icon(Icons.home_outlined),
                            ),
                            items: _units.map((u) {
                              final sector = u['sector']?['name'] ?? u['sectorName'] ?? '';
                              return DropdownMenuItem(
                                value: u,
                                child: Text('Unidade ${u['identifier']} ${sector.isNotEmpty ? "($sector)" : ""}'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedUnit = val),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Não há unidades disponíveis para auto-seleção. O síndico poderá alocar sua unidade na aprovação.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ),
                        const SizedBox(height: 14),

                        // Tipo de vínculo (Proprietário ou Inquilino)
                        DropdownButtonFormField<String>(
                          value: _residentType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Residência',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'OWNER', child: Text('Proprietário')),
                            DropdownMenuItem(value: 'TENANT', child: Text('Inquilino / Locatário')),
                          ],
                          onChanged: (val) => setState(() => _residentType = val ?? 'OWNER'),
                        ),
                        const SizedBox(height: 14),

                        // Mensagem de apresentação
                        TextField(
                          controller: _messageController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Mensagem para o síndico (opcional)',
                            hintText: 'Ex: Olá, aluguei recentemente a unidade 101 Bloco A.',
                            prefixIcon: Icon(Icons.message_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (_selectedCondo != null && !_submitting) ? _submit : null,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
          label: const Text('Enviar Solicitação'),
        ),
      ],
    );
  }
}
