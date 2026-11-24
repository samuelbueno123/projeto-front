import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/motion_system.dart';
import '../../../../core/design_system/saas_design_system.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_menus.dart';
import '../../../../core/widgets/saas_dashboard_widgets.dart';
import '../../data/admin_telemetry_service.dart';

/// Barra global de controle da telemetria em tempo real do Administrador.
class AdminLiveToolbar extends StatelessWidget {
  const AdminLiveToolbar({
    super.key,
    required this.telemetry,
    this.onOpenAlerts,
    this.showWindowSelector = true,
  });

  final AdminTelemetryService telemetry;
  final VoidCallback? onOpenAlerts;
  final bool showWindowSelector;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return ListenableBuilder(
      listenable: telemetry,
      builder: (context, _) {
        final (String statusLabel, Color statusColor, IconData statusIcon) =
            switch (telemetry.linkState) {
              AdminTelemetryLinkState.liveSse => (
                  'Ao vivo (SSE)',
                  tokens.success,
                  Icons.sensors_rounded,
                ),
              AdminTelemetryLinkState.polling => (
                  'Polling (${telemetry.refreshIntervalSeconds}s)',
                  tokens.info,
                  Icons.sync_rounded,
                ),
              AdminTelemetryLinkState.reconnecting => (
                  'Reconectando SSE...',
                  tokens.warning,
                  Icons.wifi_tethering_error_rounded,
                ),
              AdminTelemetryLinkState.paused => (
                  'Pausado',
                  tokens.textMuted,
                  Icons.pause_circle_outline_rounded,
                ),
              AdminTelemetryLinkState.error => (
                  'Falha de conexão',
                  tokens.danger,
                  Icons.cloud_off_rounded,
                ),
            };

        final activeAlerts = telemetry.activeAlertsCount;
        final criticalAlerts = telemetry.criticalAlertsCount;
        final lastUpdateStr = telemetry.lastUpdatedAt != null
            ? DateFormat('HH:mm:ss').format(telemetry.lastUpdatedAt!)
            : '--:--:--';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (telemetry.linkState == AdminTelemetryLinkState.reconnecting ||
                telemetry.linkState == AdminTelemetryLinkState.error)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        telemetry.linkState ==
                                AdminTelemetryLinkState.reconnecting
                            ? 'Conexão SSE interrompida. Tentando reconectar automaticamente enquanto o polling mantém os dados atualizados.'
                            : 'Não foi possível atualizar a telemetria. Verifique a conexão com a API e tente novamente.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => telemetry.refreshSnapshot(),
                      child: const Text('Tentar agora'),
                    ),
                  ],
                ),
              ),
            SaaSGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 12,
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AncoraLiveDot(
                              color: statusColor,
                              size: 7,
                              animate:
                                  telemetry.linkState ==
                                      AdminTelemetryLinkState.liveSse ||
                                  telemetry.linkState ==
                                      AdminTelemetryLinkState.polling,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Atualizado: $lastUpdateStr',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (onOpenAlerts != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onOpenAlerts,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: activeAlerts > 0
                                  ? (criticalAlerts > 0
                                          ? tokens.danger
                                          : tokens.warning)
                                      .withValues(alpha: 0.12)
                                  : tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: activeAlerts > 0
                                    ? (criticalAlerts > 0
                                            ? tokens.danger
                                            : tokens.warning)
                                        .withValues(alpha: 0.35)
                                    : tokens.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  activeAlerts > 0
                                      ? Icons.notifications_active_outlined
                                      : Icons.verified_user_outlined,
                                  size: 13,
                                  color: activeAlerts > 0
                                      ? (criticalAlerts > 0
                                            ? tokens.danger
                                            : tokens.warning)
                                      : tokens.success,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  activeAlerts > 0
                                      ? '$activeAlerts alerta(s) ativo(s)'
                                      : '0 alertas ativos',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: activeAlerts > 0
                                        ? (criticalAlerts > 0
                                              ? tokens.danger
                                              : tokens.warning)
                                        : tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showWindowSelector)
                        AncoraFilterPills<String>(
                          selected: telemetry.timeWindow,
                          onSelected: telemetry.setTimeWindow,
                          options: const [
                            (value: '15m', label: '15m'),
                            (value: '1h', label: '1h'),
                            (value: '6h', label: '6h'),
                            (value: '24h', label: '24h'),
                          ],
                        ),
                      AncoraContextMenu<int>(
                        tooltip: 'Frequência de atualização',
                        onSelected: telemetry.setRefreshInterval,
                        options: const [
                          AncoraMenuOption(
                            value: 5,
                            label: 'A cada 5 segundos',
                            icon: Icons.bolt_rounded,
                            shortcut: '5s',
                          ),
                          AncoraMenuOption(
                            value: 10,
                            label: 'A cada 10 segundos',
                            icon: Icons.timer_outlined,
                            shortcut: '10s',
                          ),
                          AncoraMenuOption(
                            value: 15,
                            label: 'A cada 15 segundos',
                            icon: Icons.timer_outlined,
                            shortcut: '15s',
                          ),
                          AncoraMenuOption(
                            value: 30,
                            label: 'A cada 30 segundos',
                            icon: Icons.schedule_rounded,
                            shortcut: '30s',
                          ),
                          AncoraMenuOption(
                            value: 60,
                            label: 'A cada 60 segundos',
                            icon: Icons.hourglass_bottom_rounded,
                            shortcut: '60s',
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: tokens.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: tokens.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${telemetry.refreshIntervalSeconds}s',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: tokens.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: telemetry.isPaused
                            ? telemetry.resume
                            : telemetry.pause,
                        icon: Icon(
                          telemetry.isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 16,
                        ),
                        label: Text(
                          telemetry.isPaused ? 'Retomar' : 'Pausar',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: telemetry.isLoadingSnapshot
                            ? null
                            : () => telemetry.refreshSnapshot(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Atualizar',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
