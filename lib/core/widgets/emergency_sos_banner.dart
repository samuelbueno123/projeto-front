import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/community/data/community_api.dart';
import '../../features/home/data/home_service.dart';
import '../design_system/motion_system.dart';
import '../design_system/saas_design_system.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Banner persistente de alta prioridade exibido na Portaria e no Painel do Síndico
/// quando há alertas SOS ativos no condomínio.
class EmergencySosBanner extends StatefulWidget {
  const EmergencySosBanner({
    super.key,
    required this.api,
    required this.condominiumId,
  });

  final HomeService api;
  final num? condominiumId;

  @override
  State<EmergencySosBanner> createState() => _EmergencySosBannerState();
}

class _EmergencySosBannerState extends State<EmergencySosBanner> {
  StreamSubscription<RealtimeEvent>? _sub;
  List<Map<String, dynamic>> _activeAlerts = [];
  bool _loading = false;
  bool _acting = false;

  CommunityApi get _communityApi => CommunityApi(api: widget.api);

  @override
  void initState() {
    super.initState();
    _loadActiveAlerts();
    _sub = RealtimeService.instance.events.listen((event) {
      if (!mounted) return;
      if (event.type == 'EMERGENCY_ALERT' &&
          (widget.condominiumId == null ||
              event.condominiumId == null ||
              event.condominiumId == widget.condominiumId!.toInt())) {
        _loadActiveAlerts();
      }
    });
  }

  @override
  void didUpdateWidget(covariant EmergencySosBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condominiumId != widget.condominiumId) {
      _activeAlerts = [];
      _loading = false;
      _loadActiveAlerts();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveAlerts() async {
    final condoId = widget.condominiumId;
    if (condoId == null || _loading) return;
    _loading = true;
    try {
      final list = await _communityApi.getEmergencyAlerts(
        condoId,
        status: 'ACTIVE',
      );
      if (!mounted) return;
      setState(() => _activeAlerts = list);
    } catch (_) {
      // Silently ignore if user does not have staff permission or feature is off
    } finally {
      _loading = false;
    }
  }

  Future<void> _attendAlert(Map<String, dynamic> alert) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _communityApi.attendEmergencyAlert(alert['id'] as num);
      if (!mounted) return;
      SaaSFeedback.showInfo(
        context,
        'Ocorrência SOS marcada como em atendimento pela equipe.',
      );
      await _loadActiveAlerts();
    } catch (e) {
      if (!mounted) return;
      SaaSFeedback.showError(context, 'Falha ao atender alerta: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _resolveAlert(Map<String, dynamic> alert) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _communityApi.resolveEmergencyAlert(
        alert['id'] as num,
        resolutionNotes: 'Ocorrência verificada e finalizada via painel.',
      );
      if (!mounted) return;
      SaaSFeedback.showSuccess(context, 'Alerta SOS encerrado com sucesso.');
      await _loadActiveAlerts();
    } catch (e) {
      if (!mounted) return;
      SaaSFeedback.showError(context, 'Falha ao finalizar alerta: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeAlerts.isEmpty) return const SizedBox.shrink();
    final tokens = AncoraThemeTokens.of(context);
    final alert = _activeAlerts.first;
    final typeLabel = switch (alert['emergencyType']
        ?.toString()
        .toUpperCase()) {
      'FIRE' => 'Incêndio / Fumaça',
      'SECURITY' => 'Ocorrência de Segurança',
      'MEDICAL' => 'Emergência Médica',
      'ELEVATOR' => 'Elevador Parado',
      'GAS_LEAK' => 'Vazamento de Gás',
      _ => alert['emergencyType']?.toString() ?? 'Emergência',
    };
    final resident = alert['residentName']?.toString() ?? 'Morador';
    final unit = alert['unitLabel']?.toString() ?? 'Unidade não informada';
    final details = alert['details']?.toString() ?? '';
    final phone = alert['contactPhone']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.isDark
            ? const Color(0xFF7F1D1D)
            : const Color(0xFFFEF2F2),
        border: Border(
          bottom: BorderSide(color: tokens.danger.withValues(alpha: 0.45)),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AncoraLiveDot(color: tokens.danger, size: 10),
              const SizedBox(width: 10),
              Icon(Icons.emergency_rounded, color: tokens.danger, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ALERTA SOS ATIVO (${_activeAlerts.length}): $typeLabel',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: tokens.isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                    Text(
                      '$resident • $unit'
                      '${phone.isNotEmpty ? " • Tel: ${formatPhone(phone)}" : ""}'
                      '${details.isNotEmpty ? " — $details" : ""}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tokens.isDark
                            ? const Color(0xFFFECACA)
                            : const Color(0xFF7F1D1D),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _acting ? null : () => _attendAlert(alert),
                icon: const Icon(Icons.support_agent_rounded, size: 16),
                label: const Text('Assumir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.isDark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF991B1B),
                  side: BorderSide(color: tokens.danger.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _acting ? null : () => _resolveAlert(alert),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Encerrar'),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
