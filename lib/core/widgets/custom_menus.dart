import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_assets.dart';
import '../design_system/motion_system.dart';
import '../theme/app_theme.dart';
import 'saas_dashboard_widgets.dart';

/// Item genérico para menus customizados e seletores do sistema.
class AncoraMenuOption<T> {
  const AncoraMenuOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.isDanger = false,
    this.shortcut,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool isDanger;
  final String? shortcut;
}

/// Seletor Dropdown customizado com overlay animado, foco de teclado e busca opcional.
class AncoraDropdown<T> extends StatefulWidget {
  const AncoraDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint = 'Selecione uma opção',
    this.prefixIcon,
    this.searchable = false,
    this.compact = false,
    this.maxMenuWidth = 340,
  });

  final List<AncoraMenuOption<T>> items;
  final ValueChanged<T> onChanged;
  final T? value;
  final String hint;
  final IconData? prefixIcon;
  final bool searchable;
  final bool compact;
  final double maxMenuWidth;

  @override
  State<AncoraDropdown<T>> createState() => _AncoraDropdownState<T>();
}

class _AncoraDropdownState<T> extends State<AncoraDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _triggerFocus = FocusNode();
  final FocusNode _overlayFocus = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _hovered = false;
  String _searchQuery = '';
  int _highlightedIndex = -1;

  @override
  void dispose() {
    _removeOverlay(notifyState: false);
    _triggerFocus.dispose();
    _overlayFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _removeOverlay({bool notifyState = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (notifyState && mounted && _isOpen) {
      setState(() => _isOpen = false);
      _triggerFocus.requestFocus();
    } else {
      _isOpen = false;
    }
  }

  void _openOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final targetGlobal = renderBox.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    final tokens = AncoraThemeTokens.of(context);
    final reduce = AncoraMotion.shouldReduceMotion(context);
    _searchQuery = '';
    _highlightedIndex = widget.items.indexWhere((o) => o.value == widget.value);

    final desiredWidth = size.width < 220
        ? widget.maxMenuWidth.clamp(size.width, 320.0)
        : size.width;
    final menuWidth = math.min(desiredWidth, math.max(120.0, screen.width - 24));
    final overflowRight = (targetGlobal.dx + menuWidth) - (screen.width - 12);
    final dxOffset = overflowRight > 0 ? -overflowRight : 0.0;

    final availableBelow = math.max(90.0, screen.height - (targetGlobal.dy + size.height) - 16);
    final availableAbove = math.max(90.0, targetGlobal.dy - 16);
    final openAbove = availableBelow < 180 && availableAbove > availableBelow;
    final maxHeight = math.min(
      320.0,
      openAbove ? availableAbove : availableBelow,
    );

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return StatefulBuilder(
          builder: (ctx, setOverlayState) {
            final filtered = _searchQuery.trim().isEmpty
                ? widget.items
                : widget.items
                      .where(
                        (opt) =>
                            opt.label.toLowerCase().contains(
                              _searchQuery.trim().toLowerCase(),
                            ) ||
                            (opt.subtitle?.toLowerCase().contains(
                                  _searchQuery.trim().toLowerCase(),
                                ) ??
                                false),
                      )
                      .toList();

            if (_highlightedIndex >= filtered.length) {
              _highlightedIndex = filtered.isEmpty ? -1 : 0;
            }

            void moveHighlight(int delta) {
              if (filtered.isEmpty) return;
              setOverlayState(() {
                if (_highlightedIndex < 0) {
                  _highlightedIndex = delta > 0 ? 0 : filtered.length - 1;
                } else {
                  _highlightedIndex =
                      (_highlightedIndex + delta) % filtered.length;
                  if (_highlightedIndex < 0) {
                    _highlightedIndex += filtered.length;
                  }
                }
              });
            }

            void selectHighlighted() {
              if (_highlightedIndex >= 0 &&
                  _highlightedIndex < filtered.length) {
                final opt = filtered[_highlightedIndex];
                _removeOverlay();
                widget.onChanged(opt.value);
              }
            }

            return FocusScope(
              autofocus: true,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      _removeOverlay,
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      moveHighlight(1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      moveHighlight(-1),
                  const SingleActivator(LogicalKeyboardKey.enter):
                      selectHighlighted,
                },
                child: Focus(
                  focusNode: _overlayFocus,
                  autofocus: !widget.searchable,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _removeOverlay,
                      ),
                    ),
                    CompositedTransformFollower(
                      link: _layerLink,
                      showWhenUnlinked: false,
                      targetAnchor:
                          openAbove ? Alignment.topLeft : Alignment.bottomLeft,
                      followerAnchor:
                          openAbove ? Alignment.bottomLeft : Alignment.topLeft,
                      offset: Offset(dxOffset, openAbove ? -6 : 6),
                      child: Material(
                        color: Colors.transparent,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: reduce ? 1.0 : 0.0,
                            end: 1.0,
                          ),
                          duration: reduce ? Duration.zero : AncoraMotion.fast,
                          curve: AncoraMotion.easeOut,
                          builder: (c, t, child) {
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  (1 - t) * (openAbove ? 6 : -6),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            width: menuWidth,
                            constraints: BoxConstraints(maxHeight: maxHeight),
                            decoration: BoxDecoration(
                              color: tokens.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: tokens.borderStrong),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: tokens.isDark ? 0.45 : 0.12,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.searchable)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      10,
                                      10,
                                      6,
                                    ),
                                    child: TextField(
                                      autofocus: true,
                                      onChanged: (v) => setOverlayState(
                                        () => _searchQuery = v,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Filtrar opções...',
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          size: 17,
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                Flexible(
                                  child: filtered.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'Nenhuma opção encontrada',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          padding: const EdgeInsets.all(6),
                                          itemCount: filtered.length,
                                          itemBuilder: (_, index) {
                                            final opt = filtered[index];
                                            final selected =
                                                opt.value == widget.value;
                                            final highlighted =
                                                index == _highlightedIndex;
                                            return Semantics(
                                              button: true,
                                              selected: selected,
                                              excludeSemantics: true,
                                              label: opt.subtitle != null &&
                                                      opt.subtitle!.isNotEmpty
                                                  ? '${opt.label}, ${opt.subtitle}'
                                                  : opt.label,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                onTap: () {
                                                  _removeOverlay();
                                                  widget.onChanged(opt.value);
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 9,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? tokens.accent
                                                              .withValues(
                                                                alpha: tokens.isDark
                                                                    ? 0.22
                                                                    : 0.10,
                                                              )
                                                        : (highlighted
                                                              ? tokens.surfaceSubtle
                                                              : Colors.transparent),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      if (opt.icon != null) ...[
                                                        Icon(
                                                          opt.icon,
                                                          size: 16,
                                                          color: selected
                                                              ? tokens.accent
                                                              : tokens
                                                                    .textSecondary,
                                                        ),
                                                        const SizedBox(width: 9),
                                                      ],
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              opt.label,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: selected
                                                                    ? FontWeight.w700
                                                                    : FontWeight.w500,
                                                                color: selected
                                                                    ? tokens.accent
                                                                    : tokens
                                                                          .textPrimary,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            if (opt.subtitle !=
                                                                    null &&
                                                                opt
                                                                    .subtitle!
                                                                    .isNotEmpty)
                                                              Text(
                                                                opt.subtitle!,
                                                                style: TextStyle(
                                                                  fontSize: 11.5,
                                                                  color: tokens
                                                                      .textMuted,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (selected)
                                                        Icon(
                                                          Icons.check_rounded,
                                                          size: 16,
                                                          color: tokens.accent,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
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
              ),
            );
          },
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    if (!widget.searchable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen) {
          _overlayFocus.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    AncoraMenuOption<T>? selectedOption;
    for (final opt in widget.items) {
      if (opt.value == widget.value) {
        selectedOption = opt;
        break;
      }
    }

    return Semantics(
      button: true,
      toggled: _isOpen,
      label: selectedOption != null
          ? '${widget.hint}: ${selectedOption.label}'
          : widget.hint,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _toggle,
          const SingleActivator(LogicalKeyboardKey.space): _toggle,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_isOpen) _removeOverlay();
          },
        },
        child: Focus(
          focusNode: _triggerFocus,
          child: CompositedTransformTarget(
            link: _layerLink,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: AncoraMotion.duration(context, AncoraMotion.fast),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 11 : 14,
                    vertical: widget.compact ? 7 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isOpen
                          ? tokens.accent
                          : (_hovered ? tokens.borderStrong : tokens.border),
                      width: _isOpen ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.prefixIcon != null) ...[
                        Icon(widget.prefixIcon, size: 17, color: tokens.accent),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          selectedOption?.label ?? widget.hint,
                          style: TextStyle(
                            fontSize: widget.compact ? 12.5 : 13.5,
                            fontWeight: FontWeight.w600,
                            color: selectedOption != null
                                ? tokens.textPrimary
                                : tokens.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _isOpen ? 0.5 : 0.0,
                        duration: AncoraMotion.duration(
                          context,
                          AncoraMotion.fast,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu contextual animado para ações rápidas em cards, tabelas e barras de ferramentas.
class AncoraContextMenu<T> extends StatelessWidget {
  const AncoraContextMenu({
    super.key,
    required this.options,
    required this.onSelected,
    this.child,
    this.tooltip = 'Mais opções',
  });

  final List<AncoraMenuOption<T>> options;
  final ValueChanged<T> onSelected;
  final Widget? child;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.borderStrong),
      ),
      color: tokens.surfaceElevated,
      itemBuilder: (ctx) {
        return options.map((opt) {
          final color = opt.isDanger ? tokens.danger : tokens.textPrimary;
          return PopupMenuItem<T>(
            value: opt.value,
            child: Row(
              children: [
                if (opt.icon != null) ...[
                  Icon(
                    opt.icon,
                    size: 17,
                    color: opt.isDanger ? tokens.danger : tokens.textSecondary,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (opt.shortcut != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      opt.shortcut!,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: tokens.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList();
      },
      child:
          child ??
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.border),
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textSecondary,
            ),
          ),
    );
  }
}

/// Definição de um destino na barra lateral / navegação do sistema.
class AncoraNavDestination {
  const AncoraNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    this.activeIcon,
    this.section,
    this.badgeCount = 0,
    this.badgeColor,
    this.showInBottomNav = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String? section;
  final int badgeCount;
  final Color? badgeColor;
  final bool showInBottomNav;
}

/// Shell responsiva unificada para os portais Âncora Gestão:
/// barra lateral expansível/retrátil no desktop e barra + drawer adaptativos no mobile.
class AncoraNavigationShell extends StatefulWidget {
  const AncoraNavigationShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.sidebarHeaderExtra,
    this.sidebarFooterExtra,
    this.headerActions = const [],
    this.floatingActionButton,
    this.banner,
    this.brandIcon = Icons.anchor_rounded,
    this.onOpenCommandPalette,
    this.topBarTitleOverride,
  });

  final String title;
  final String subtitle;
  final List<AncoraNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? sidebarHeaderExtra;
  final Widget? sidebarFooterExtra;
  final List<Widget> headerActions;
  final Widget? floatingActionButton;
  final Widget? banner;
  final IconData brandIcon;
  final VoidCallback? onOpenCommandPalette;
  final String? topBarTitleOverride;

  @override
  State<AncoraNavigationShell> createState() => _AncoraNavigationShellState();
}

class _AncoraNavigationShellState extends State<AncoraNavigationShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 960;

    final bottomDests = <int>[];
    for (int i = 0; i < widget.destinations.length; i++) {
      if (widget.destinations[i].showInBottomNav) bottomDests.add(i);
    }
    if (bottomDests.isEmpty && widget.destinations.length >= 2) {
      for (int i = 0; i < widget.destinations.length && i < 4; i++) {
        bottomDests.add(i);
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: tokens.canvas,
      floatingActionButton: widget.floatingActionButton,
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: tokens.surface,
              child: SafeArea(
                child: _buildSidebarContent(
                  tokens,
                  collapsed: false,
                  closeDrawerOnTap: true,
                ),
              ),
            ),
      bottomNavigationBar: (!isDesktop && bottomDests.length >= 2)
          ? NavigationBar(
              backgroundColor: tokens.surface,
              indicatorColor: bottomDests.contains(widget.selectedIndex)
                  ? tokens.accent.withValues(
                      alpha: tokens.isDark ? 0.25 : 0.14,
                    )
                  : Colors.transparent,
              selectedIndex: bottomDests.contains(widget.selectedIndex)
                  ? bottomDests.indexOf(widget.selectedIndex)
                  : 0,
              onDestinationSelected: (pos) => widget.onSelect(bottomDests[pos]),
              destinations: bottomDests.map((idx) {
                final d = widget.destinations[idx];
                return NavigationDestination(
                  icon: Badge(
                    isLabelVisible: d.badgeCount > 0,
                    label: Text('${d.badgeCount}'),
                    child: Icon(d.icon),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: d.badgeCount > 0,
                    label: Text('${d.badgeCount}'),
                    child: Icon(d.activeIcon ?? d.icon, color: tokens.accent),
                  ),
                  label: d.label,
                );
              }).toList(),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            AnimatedContainer(
              duration: AncoraMotion.duration(context, AncoraMotion.normal),
              curve: AncoraMotion.easeOut,
              width: _collapsed ? 78 : 264,
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(
                  right: BorderSide(
                    color: tokens.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : tokens.border,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (_, box) => _buildSidebarContent(
                  tokens,
                  collapsed: _collapsed || box.maxWidth < 190,
                  closeDrawerOnTap: false,
                ),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(tokens, isDesktop),
                if (widget.banner != null) widget.banner!,
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AncoraThemeTokens tokens, bool isDesktop) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final current =
        widget.selectedIndex >= 0 &&
            widget.selectedIndex < widget.destinations.length
        ? widget.destinations[widget.selectedIndex]
        : null;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(
            color: tokens.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : tokens.border,
          ),
        ),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              tooltip: 'Menu de navegação',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 6),
          ] else ...[
            IconButton(
              tooltip: _collapsed
                  ? 'Expandir barra lateral'
                  : 'Recolher barra lateral',
              onPressed: () => setState(() => _collapsed = !_collapsed),
              icon: Icon(
                _collapsed
                    ? Icons.view_sidebar_rounded
                    : Icons.menu_open_rounded,
                size: 20,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            flex: isDesktop ? 2 : 1,
            child: Row(
              children: [
                if (current != null) ...[
                  Icon(
                    current.activeIcon ?? current.icon,
                    size: 19,
                    color: tokens.accent,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    widget.topBarTitleOverride ??
                        current?.label ??
                        widget.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                      color: tokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: isDesktop ? 5 : 3,
            fit: FlexFit.loose,
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDesktop) ...[
                      const AncoraConnectionStatusPill(),
                      if (screenWidth >= 1520) ...[
                        const SizedBox(width: 8),
                        const AncoraLiveClockPill(),
                      ],
                      const SizedBox(width: 8),
                    ],
                    if (widget.onOpenCommandPalette != null && isDesktop) ...[
                      InkWell(
                        onTap: widget.onOpenCommandPalette,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
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
                                Icons.search_rounded,
                                size: 16,
                                color: tokens.textMuted,
                              ),
                              if (screenWidth >= 1480) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Buscar ou ir para...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: tokens.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ] else
                                const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: tokens.borderStrong,
                                  ),
                                ),
                                child: Text(
                                  'Ctrl K',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    ...widget.headerActions.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: w,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(
    AncoraThemeTokens tokens, {
    required bool collapsed,
    required bool closeDrawerOnTap,
  }) {
    String? lastSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            collapsed ? 12 : 16,
            16,
            collapsed ? 12 : 12,
            12,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: widget.brandIcon == Icons.anchor_rounded
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.asset(
                          AppAssets.ancoraLogo,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            widget.brandIcon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : Icon(widget.brandIcon, color: Colors.white, size: 20),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!closeDrawerOnTap)
                  IconButton(
                    tooltip: 'Recolher menu',
                    onPressed: () => setState(() => _collapsed = true),
                    icon: Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (collapsed && !closeDrawerOnTap)
          Center(
            child: IconButton(
              tooltip: 'Expandir menu',
              onPressed: () => setState(() => _collapsed = false),
              icon: Icon(
                Icons.keyboard_double_arrow_right_rounded,
                size: 18,
                color: tokens.textMuted,
              ),
            ),
          ),
        if (!collapsed && widget.sidebarHeaderExtra != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: widget.sidebarHeaderExtra!,
          ),
        Divider(height: 1, color: tokens.border),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemCount: widget.destinations.length,
            itemBuilder: (context, index) {
              final dest = widget.destinations[index];
              final isSelected = index == widget.selectedIndex;
              final showSectionHeader =
                  !collapsed &&
                  dest.section != null &&
                  dest.section != lastSection;
              lastSection = dest.section;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSectionHeader)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        10,
                        index == 0 ? 2 : 12,
                        10,
                        6,
                      ),
                      child: Text(
                        dest.section!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Tooltip(
                      message: collapsed ? dest.label : '',
                      preferBelow: false,
                      verticalOffset: 24,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () {
                          if (closeDrawerOnTap) {
                            _scaffoldKey.currentState?.closeDrawer();
                          }
                          widget.onSelect(index);
                        },
                        child: AnimatedContainer(
                          duration: AncoraMotion.duration(
                            context,
                            AncoraMotion.fast,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: collapsed ? 0 : 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tokens.accent.withValues(
                                    alpha: tokens.isDark ? 0.18 : 0.09,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                            border: isSelected
                                ? Border.all(
                                    color: tokens.accent.withValues(
                                      alpha: tokens.isDark ? 0.35 : 0.22,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: collapsed
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                            children: [
                              Badge(
                                isLabelVisible:
                                    collapsed && dest.badgeCount > 0,
                                label: Text('${dest.badgeCount}'),
                                child: Icon(
                                  isSelected
                                      ? (dest.activeIcon ?? dest.icon)
                                      : dest.icon,
                                  size: 19,
                                  color: isSelected
                                      ? tokens.accent
                                      : tokens.textSecondary,
                                ),
                              ),
                              if (!collapsed) ...[
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Text(
                                    dest.label,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? tokens.accent
                                          : tokens.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (dest.badgeCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dest.badgeColor ?? tokens.accent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${dest.badgeCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.sidebarFooterExtra != null && !collapsed) ...[
          Divider(height: 1, color: tokens.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: widget.sidebarFooterExtra!,
          ),
        ],
      ],
    );
  }
}
