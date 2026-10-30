import 'dart:convert';

import 'package:flutter/material.dart';

class EnterSearchField extends StatefulWidget {
  const EnterSearchField({
    super.key,
    required this.onSubmitted,
    this.hintText = 'Pesquisar registros',
  });

  final ValueChanged<String> onSubmitted;
  final String hintText;

  @override
  State<EnterSearchField> createState() => _EnterSearchFieldState();
}

class _EnterSearchFieldState extends State<EnterSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('enter-search-field'),
    controller: _controller,
    maxLength: 100,
    textInputAction: TextInputAction.search,
    onSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      hintText: widget.hintText,
      prefixIcon: const Icon(Icons.search),
      counterText: '',
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Limpar pesquisa',
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onSubmitted('');
              },
              icon: const Icon(Icons.close),
            ),
      border: const OutlineInputBorder(),
    ),
    onChanged: (_) => setState(() {}),
  );
}

bool recordMatchesQuery(Map<String, dynamic> record, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  return normalizedQuery.isEmpty ||
      jsonEncode(record).toLowerCase().contains(normalizedQuery);
}
