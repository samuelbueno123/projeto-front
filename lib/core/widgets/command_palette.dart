import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/motion_system.dart';
import '../theme/app_theme.dart';

/// Ação executável exibida na Command Palette (`Ctrl+K` / `Cmd+K`).
class AncoraCommandAction {
  const AncoraCommandAction({
    required this.id,
    required this.title,
    required this.icon,
    required this.onExecute,
    this.subtitle,
    this.category = 'Navegação',
    this.keywords = '',
  });

  final String id;
  final String title;
  final String? subtitle;
  final String category;
  final String keywords;
  final IconData icon;
  final VoidCallback onExecute;
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

/// Wrapper que habilita o atalho `Ctrl+K` / `Cmd+K` globalmente no portal atual.
class AncoraCommandShortcutWrapper extends StatelessWidget {
  const AncoraCommandShortcutWrapper({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<AncoraCommandAction> actions;
  final Widget child;

  static Future<void> open(
    BuildContext context,
    List<AncoraCommandAction> actions,
  ) {
    return showAncoraDialog<void>(
      context: context,
      builder: (_) => AncoraCommandPaletteDialog(actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              open(context, actions);
              return null;
            },
          ),
        },
        child: Focus(autofocus: false, child: child),
      ),
    );
  }
}

/// Modal Command Palette com pesquisa instantânea e seleção por teclado.
class AncoraCommandPaletteDialog extends StatefulWidget {
  const AncoraCommandPaletteDialog({super.key, required this.actions});

  final List<AncoraCommandAction> actions;

  @override
  State<AncoraCommandPaletteDialog> createState() =>
      _AncoraCommandPaletteDialogState();
}

class _AncoraCommandPaletteDialogState
    extends State<AncoraCommandPaletteDialog> {
  final TextEditingController _controller = TextEditingController();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<AncoraCommandAction> get _filtered {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return widget.actions;
    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return widget.actions.where((a) {
      final haystack =
          '${a.title} ${a.subtitle ?? ''} ${a.category} ${a.keywords}'
              .toLowerCase();
      return terms.every(haystack.contains);
    }).toList();
  }

  void _triggerAction(AncoraCommandAction action) {
    Navigator.of(context).pop();
    action.onExecute();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final items = _filtered;
    if (_selectedIndex >= items.length && items.isNotEmpty) {
      _selectedIndex = items.length - 1;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              items.isNotEmpty) {
            setState(
              () => _selectedIndex = (_selectedIndex + 1) % items.length,
            );
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
              items.isNotEmpty) {
            setState(
              () => _selectedIndex =
                  (_selectedIndex - 1 + items.length) % items.length,
            );
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              items.isNotEmpty) {
            _triggerAction(items[_selectedIndex]);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.borderStrong),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: tokens.isDark ? 0.55 : 0.18,
                  ),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: tokens.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          onChanged: (_) => setState(() => _selectedIndex = 0),
                          decoration: InputDecoration(
                            hintText:
                                'Digite um comando, aba ou ação rápida...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(color: tokens.textMuted),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.border),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: tokens.border),
                Flexible(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 30,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nenhum comando encontrado',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: items.length,
                          itemBuilder: (_, idx) {
                            final item = items[idx];
                            final selected = idx == _selectedIndex;
                            return InkWell(
                              borderRadius: BorderRadius.circular(11),
                              onTap: () => _triggerAction(item),
                              onHover: (hovered) {
                                if (hovered && _selectedIndex != idx) {
                                  setState(() => _selectedIndex = idx);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? tokens.accent.withValues(
                                          alpha: tokens.isDark ? 0.22 : 0.11,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? tokens.accent.withValues(
                                                alpha: 0.18,
                                              )
                                            : tokens.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 17,
                                        color: selected
                                            ? tokens.accent
                                            : tokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: selected
                                                  ? tokens.accent
                                                  : tokens.textPrimary,
                                            ),
                                          ),
                                          if (item.subtitle != null &&
                                              item.subtitle!.isNotEmpty)
                                            Text(
                                              item.subtitle!,
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
                                    Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ],
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
    );
  }
}
