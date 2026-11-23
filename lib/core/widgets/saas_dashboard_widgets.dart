import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../design_system/motion_system.dart';
import '../design_system/saas_design_system.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';

/// Card SaaS com suporte a glassmorphism (`backdrop-blur-md`), fundo `#0F1424`
/// no modo escuro e bordas sutis `border-white/5` ou `#1E293B`.
class SaaSGlassCard extends StatefulWidget {
  const SaaSGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 16,
    this.borderColor,
    this.accentGlowColor,
    this.useBlur = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? accentGlowColor;
  final bool useBlur;
  final VoidCallback? onTap;

  @override
  State<SaaSGlassCard> createState() => _SaaSGlassCardState();
}

class _SaaSGlassCardState extends State<SaaSGlassCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final isInteractive = widget.onTap != null;
    final defaultBorder = tokens.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : tokens.border;
    final highlighted = (_hovered || _focused) && isInteractive;
    final resolvedBorder = highlighted
        ? (widget.accentGlowColor ?? tokens.accent).withValues(
            alpha: _focused ? 0.85 : 0.5,
          )
        : (widget.borderColor ?? defaultBorder);

    final bgColor = tokens.isDark
        ? (widget.useBlur
              ? SaaSColors.cardNavy.withValues(alpha: 0.82)
              : SaaSColors.cardNavy)
        : (widget.useBlur
              ? tokens.surface.withValues(alpha: 0.88)
              : tokens.surface);

    Widget content = AnimatedContainer(
      duration: AncoraMotion.duration(context, AncoraMotion.fast),
      curve: AncoraMotion.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: resolvedBorder,
          width: _focused && isInteractive ? 1.8 : (highlighted ? 1.3 : 1.0),
        ),
        boxShadow: [
          if (widget.accentGlowColor != null && highlighted)
            BoxShadow(
              color: widget.accentGlowColor!.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 6),
            )
          else if (!tokens.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: widget.child,
    );

    if (widget.useBlur && !isRunningTestEnvironment) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      );
    }

    if (isInteractive) {
      content = Semantics(
        button: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): widget.onTap!,
            const SingleActivator(LogicalKeyboardKey.space): widget.onTap!,
          },
          child: Focus(
            onFocusChange: (val) => setState(() => _focused = val),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(onTap: widget.onTap, child: content),
            ),
          ),
        ),
      );
    }

    if (widget.margin != null) {
      return Padding(padding: widget.margin!, child: content);
    }
    return content;
  }
}

/// Pill de data e hora ao vivo para o cabeçalho global.
/// Em ambiente de testes (`FLUTTER_TEST`) não registra timer periódico infinito.
class AncoraLiveClockPill extends StatefulWidget {
  const AncoraLiveClockPill({super.key});

  @override
  State<AncoraLiveClockPill> createState() => _AncoraLiveClockPillState();
}

class _AncoraLiveClockPillState extends State<AncoraLiveClockPill> {
  Timer? _timer;
  late DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (!isRunningTestEnvironment) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTooltipDate(DateTime dt) {
    try {
      return DateFormat('EEEE, dd/MM/yyyy • HH:mm', 'pt_BR').format(dt);
    } catch (_) {
      return DateFormat('dd/MM/yyyy • HH:mm').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final formatted = DateFormat('dd/MM • HH:mm').format(_now);
    return Tooltip(
      message: _formatTooltipDate(_now),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tokens.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : tokens.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 14,
              color: tokens.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              formatted,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de status da conexão em tempo real (SSE) ligado ao [RealtimeService].
class AncoraConnectionStatusPill extends StatelessWidget {
  const AncoraConnectionStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return StreamBuilder<RealtimeConnectionState>(
      stream: RealtimeService.instance.connectionState,
      initialData: RealtimeService.instance.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? RealtimeService.instance.currentState;
        final hasToken = RealtimeService.instance.hasToken;

        final (String label, Color color, String tooltip) = switch (state) {
          RealtimeConnectionState.connected => (
              'Ao vivo',
              SaaSColors.success,
              'Conexão em tempo real ativa (SSE)',
            ),
          RealtimeConnectionState.connecting => (
              'Sincronizando',
              SaaSColors.warning,
              'Estabelecendo canal em tempo real...',
            ),
          RealtimeConnectionState.disconnected => hasToken
              ? (
                  'Reconectando',
                  SaaSColors.error,
                  'Canal em tempo real offline — tentando reconectar',
                )
              : (
                  'Local',
                  tokens.textMuted,
                  'Sessão sem canal SSE ativo',
                ),
        };

        return Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: tokens.isDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AncoraLiveDot(
                  color: color,
                  size: 7,
                  animate: state == RealtimeConnectionState.connected,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.isDark ? color : color.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tile interativo padronizado para Ações Rápidas nos dashboards.
class SaaSQuickActionCard extends StatefulWidget {
  const SaaSQuickActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;
  final String? badge;

  @override
  State<SaaSQuickActionCard> createState() => _SaaSQuickActionCardState();
}

class _SaaSQuickActionCardState extends State<SaaSQuickActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: AncoraMotion.duration(context, AncoraMotion.fast),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: tokens.isDark ? 0.16 : 0.08)
                : tokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.45)
                  : (tokens.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : tokens.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(
                        alpha: tokens.isDark ? 0.2 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  if (widget.badge != null && widget.badge!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.badge!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  color: tokens.textPrimary,
                ),
              ),
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: tokens.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Gráfico comparativo de Arrecadação vs Pendente vs Inadimplência alimentado por valores reais.
class SaaSFinancialMiniChart extends StatelessWidget {
  const SaaSFinancialMiniChart({
    super.key,
    required this.collected,
    required this.pending,
    required this.overdue,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
  });

  final double collected;
  final double pending;
  final double overdue;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final total = collected + pending + overdue;
    final hasValues = total > 0;
    final collectedRatio = hasValues ? (collected / total).clamp(0.0, 1.0) : 0.0;
    final pendingRatio = hasValues ? (pending / total).clamp(0.0, 1.0) : 0.0;
    final overdueRatio = hasValues ? (overdue / total).clamp(0.0, 1.0) : 0.0;

    final brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tokens.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : tokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Arrecadação vs Inadimplência',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasValues
                    ? '${(collectedRatio * 100).toStringAsFixed(0)}% arrecadado'
                    : 'Sem lançamentos',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: hasValues ? SaaSColors.success : tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: hasValues
                  ? Row(
                      children: [
                        if (collectedRatio > 0)
                          Expanded(
                            flex: (collectedRatio * 1000).round().clamp(1, 1000),
                            child: Container(color: SaaSColors.success),
                          ),
                        if (pendingRatio > 0)
                          Expanded(
                            flex: (pendingRatio * 1000).round().clamp(1, 1000),
                            child: Container(color: SaaSColors.warning),
                          ),
                        if (overdueRatio > 0)
                          Expanded(
                            flex: (overdueRatio * 1000).round().clamp(1, 1000),
                            child: Container(color: SaaSColors.error),
                          ),
                      ],
                    )
                  : Container(
                      color: tokens.border,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legendItem(
                tokens,
                color: SaaSColors.success,
                label: 'Arrecadado ($paidCount)',
                value: brl.format(collected),
              ),
              _legendItem(
                tokens,
                color: SaaSColors.warning,
                label: 'Pendente ($pendingCount)',
                value: brl.format(pending),
              ),
              _legendItem(
                tokens,
                color: SaaSColors.error,
                label: 'Inadimplente ($overdueCount)',
                value: brl.format(overdue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(
    AncoraThemeTokens tokens, {
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: tokens.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Detecta metadados visuais (ícone, cor e rótulo) de transportadora a partir da descrição real da encomenda.
class CarrierVisual {
  const CarrierVisual({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static CarrierVisual fromDescription(String? description) {
    final text = (description ?? '').toLowerCase();
    if (text.contains('sedex') || text.contains('correios') || text.contains('pac')) {
      return const CarrierVisual(
        label: 'Correios / Sedex',
        icon: Icons.markunread_mailbox_outlined,
        color: Color(0xFFF59E0B),
      );
    }
    if (text.contains('mercado livre') || text.contains('mercadolivre') || text.contains('meli')) {
      return const CarrierVisual(
        label: 'Mercado Livre',
        icon: Icons.local_shipping_outlined,
        color: Color(0xFFEAB308),
      );
    }
    if (text.contains('amazon') || text.contains('prime')) {
      return const CarrierVisual(
        label: 'Amazon',
        icon: Icons.shopping_bag_outlined,
        color: Color(0xFF3B82F6),
      );
    }
    if (text.contains('shopee')) {
      return const CarrierVisual(
        label: 'Shopee',
        icon: Icons.storefront_outlined,
        color: Color(0xFFF97316),
      );
    }
    if (text.contains('ifood') || text.contains('rappi') || text.contains('delivery')) {
      return const CarrierVisual(
        label: 'Delivery',
        icon: Icons.delivery_dining_outlined,
        color: Color(0xFFEF4444),
      );
    }
    return const CarrierVisual(
      label: 'Encomenda',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF2563EB),
    );
  }
}
