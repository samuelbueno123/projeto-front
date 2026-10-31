import 'dart:convert';

import 'package:flutter/material.dart';

class EnterSearchField extends StatefulWidget {
  const EnterSearchField({
    super.key,
    required this.onSubmitted,
    this.hintText = 'Pesquisar registros (pressione Enter)',
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

  void _triggerSearch() {
    widget.onSubmitted(_controller.text);
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
      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2F3FB0)),
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Limpar pesquisa',
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onSubmitted('');
              },
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _triggerSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Enter ↵',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F3FB0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD8E0F0)),
      ),
    ),
    onChanged: (_) => setState(() {}),
  );
}

bool recordMatchesQuery(Map<String, dynamic> record, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  return normalizedQuery.isEmpty ||
      jsonEncode(record).toLowerCase().contains(normalizedQuery);
}
