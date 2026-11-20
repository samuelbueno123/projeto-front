import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

export '../utils/formatters.dart' show recordMatchesQuery;

/// Campo de busca moderno com botão de pesquisa, limpeza reativa e suporte opcional a debounce.
class EnterSearchField extends StatefulWidget {
  const EnterSearchField({
    super.key,
    required this.onSubmitted,
    this.hintText = 'Pesquisar registros (pressione Enter)',
    this.initialValue = '',
    this.onChanged,
    this.debounceDuration,
  });

  final ValueChanged<String> onSubmitted;
  final String hintText;
  final String initialValue;
  final ValueChanged<String>? onChanged;
  final Duration? debounceDuration;

  @override
  State<EnterSearchField> createState() => _EnterSearchFieldState();
}

class _EnterSearchFieldState extends State<EnterSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    _debounce?.cancel();
    widget.onSubmitted(_controller.text);
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onChanged?.call(value);
    if (widget.debounceDuration != null) {
      _debounce?.cancel();
      _debounce = Timer(widget.debounceDuration!, () {
        if (mounted) widget.onSubmitted(value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: _handleChanged,
      onSubmitted: (_) => _triggerSearch(),
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: IconButton(
          tooltip: 'Pesquisar',
          onPressed: _triggerSearch,
          icon: Icon(Icons.search_rounded, size: 20, color: tokens.accent),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Limpar pesquisa',
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged?.call('');
                  _triggerSearch();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            IconButton(
              tooltip: 'Aplicar filtro (Enter)',
              onPressed: _triggerSearch,
              icon: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        filled: true,
        fillColor: tokens.surface,
      ),
    );
  }
}
