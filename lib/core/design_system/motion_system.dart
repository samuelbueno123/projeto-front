import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'test_env_stub.dart' if (dart.library.io) 'test_env_io.dart';

/// Utilitário centralizado para microinterações fluidas que respeita `prefers-reduced-motion`
/// (`MediaQuery.disableAnimationsOf`) e ambientes de teste (`FLUTTER_TEST`).
class AncoraMotion {
  AncoraMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  static bool get isTestEnvironment => isFlutterTestEnvironment();

  static bool shouldReduceMotion(BuildContext context) {
    if (isTestEnvironment) return true;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  static Duration duration(BuildContext context, [Duration target = normal]) {
    return shouldReduceMotion(context) ? Duration.zero : target;
  }
}

/// Transição suave entre abas, telas ou estados com respeito a movimento reduzido.
class AncoraAnimatedSwitcher extends StatelessWidget {
  const AncoraAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AncoraMotion.normal,
    this.offsetY = 0.02,
  });

  final Widget child;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    if (AncoraMotion.shouldReduceMotion(context)) {
      return KeyedSubtree(key: child.key, child: child);
    }
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: const Duration(milliseconds: 160),
      switchInCurve: AncoraMotion.easeOut,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (childWidget, animation) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide = Tween<Offset>(
          begin: Offset(0, offsetY),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: childWidget),
        );
      },
      child: child,
    );
  }
}

/// Animação de entrada discreta e escalonada para cards, métricas e itens de lista.
class AncoraEntrance extends StatefulWidget {
  const AncoraEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AncoraMotion.normal,
    this.offset = const Offset(0, 12),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<AncoraEntrance> createState() => _AncoraEntranceState();
}

class _AncoraEntranceState extends State<AncoraEntrance> {
  bool _visible = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    if (AncoraMotion.shouldReduceMotion(context)) {
      _visible = true;
      return;
    }
    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AncoraMotion.shouldReduceMotion(context)) {
      return widget.child;
    }
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: widget.duration,
      curve: AncoraMotion.easeOut,
      child: AnimatedSlide(
        offset: _visible
            ? Offset.zero
            : Offset(widget.offset.dx / 200, widget.offset.dy / 100),
        duration: widget.duration,
        curve: AncoraMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Card interativo com feedback tátil no hover e no toque (press scale + elevação).
class AncoraInteractiveCard extends StatefulWidget {
  const AncoraInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.onSecondaryTapDown,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor,
    this.borderColor,
    this.hoverBorderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;

  @override
  State<AncoraInteractiveCard> createState() => _AncoraInteractiveCardState();
}

class _AncoraInteractiveCardState extends State<AncoraInteractiveCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final reduce = AncoraMotion.shouldReduceMotion(context);
    final isInteractive = widget.onTap != null;
    final resolvedBorder = (_hovered && isInteractive)
        ? (widget.hoverBorderColor ?? tokens.accent.withValues(alpha: 0.48))
        : (widget.borderColor ?? tokens.border);

    return MouseRegion(
      cursor: isInteractive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: isInteractive ? (_) => setState(() => _hovered = true) : null,
      onExit: isInteractive ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTapDown: isInteractive
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: isInteractive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: isInteractive
            ? () => setState(() => _pressed = false)
            : null,
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedScale(
          scale: (_pressed && isInteractive && !reduce) ? 0.985 : 1.0,
          duration: reduce ? Duration.zero : AncoraMotion.fast,
          curve: AncoraMotion.easeOut,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : AncoraMotion.fast,
            curve: AncoraMotion.easeOut,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? tokens.surface,
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: resolvedBorder,
                width: _hovered && isInteractive ? 1.4 : 1.0,
              ),
              boxShadow: (_hovered && isInteractive && !tokens.isDark)
                  ? [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Contador numérico animado para KPIs e métricas de dashboards.
class AncoraAnimatedCounter extends StatelessWidget {
  const AncoraAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
    this.duration = const Duration(milliseconds: 520),
  });

  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    String format(num val) {
      if (fractionDigits <= 0) {
        return '$prefix${val.round()}$suffix';
      }
      return '$prefix${val.toStringAsFixed(fractionDigits).replaceAll('.', ',')}$suffix';
    }

    if (AncoraMotion.shouldReduceMotion(context)) {
      return Text(format(value), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AncoraMotion.easeOut,
      builder: (context, animatedValue, _) {
        return Text(format(animatedValue), style: style);
      },
    );
  }
}

/// Indicador pulsante para status ao vivo (SSE conectado / Alerta SOS).
class AncoraLiveDot extends StatefulWidget {
  const AncoraLiveDot({
    super.key,
    required this.color,
    this.size = 8,
    this.animate = true,
  });

  final Color color;
  final double size;
  final bool animate;

  @override
  State<AncoraLiveDot> createState() => _AncoraLiveDotState();
}

class _AncoraLiveDotState extends State<AncoraLiveDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldPulse =
        widget.animate && !AncoraMotion.shouldReduceMotion(context);
    if (shouldPulse && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    } else if (!shouldPulse && _controller != null) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final glow = 2.0 + controller.value * 4.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.45 * (1 - controller.value * 0.4),
                ),
                blurRadius: glow,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Abre um diálogo com transição moderna de escala + fade (instantâneo em reduced motion).
Future<T?> showAncoraDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (AncoraMotion.shouldReduceMotion(context)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => builder(dialogContext),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AncoraMotion.easeOut,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Bloco shimmer moderno para estados de carregamento assíncronos.
class AncoraShimmerBlock extends StatefulWidget {
  const AncoraShimmerBlock({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<AncoraShimmerBlock> createState() => _AncoraShimmerBlockState();
}

class _AncoraShimmerBlockState extends State<AncoraShimmerBlock>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AncoraMotion.shouldReduceMotion(context);
    if (!reduce && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat(reverse: true);
    } else if (reduce && _controller != null) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final baseColor = tokens.isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final highlightColor = tokens.isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);

    final ctrl = _controller;
    if (ctrl == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: widget.borderRadius,
        ),
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, ctrl.value),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// Skeleton completo para telas de dashboard e cards de resumo.
class AncoraDashboardSkeleton extends StatelessWidget {
  const AncoraDashboardSkeleton({super.key, this.cardCount = 4});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AncoraShimmerBlock(width: 240, height: 26),
          const SizedBox(height: 8),
          const AncoraShimmerBlock(width: 340, height: 14),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(cardCount, (_) {
              return Container(
                width: 230,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AncoraShimmerBlock(
                      width: 36,
                      height: 36,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(height: 14),
                    AncoraShimmerBlock(width: 90, height: 22),
                    SizedBox(height: 8),
                    AncoraShimmerBlock(width: 150, height: 12),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          const AncoraListSkeleton(itemCount: 3),
        ],
      ),
    );
  }
}

/// Skeleton para listas e feed de notificações/itens.
class AncoraListSkeleton extends StatelessWidget {
  const AncoraListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return Column(
      children: List.generate(itemCount, (index) {
        return Container(
          margin: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: const Row(
            children: [
              AncoraShimmerBlock(
                width: 44,
                height: 44,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AncoraShimmerBlock(width: 180, height: 15),
                    SizedBox(height: 8),
                    AncoraShimmerBlock(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Skeleton estruturado para tabelas e listagens administrativas.
class AncoraTableSkeleton extends StatelessWidget {
  const AncoraTableSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: List.generate(rows, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 14),
            child: const Row(
              children: [
                Expanded(flex: 2, child: AncoraShimmerBlock(height: 14)),
                SizedBox(width: 16),
                Expanded(flex: 3, child: AncoraShimmerBlock(height: 14)),
                SizedBox(width: 16),
                Expanded(flex: 1, child: AncoraShimmerBlock(height: 14)),
              ],
            ),
          );
        }),
      ),
    );
  }
}
