import 'package:flutter/material.dart';

import '../../models/bot_filter.dart';

class SearchView extends StatefulWidget {
  const SearchView({
    super.key,
    required this.onFilterChanged,
    this.initialQuery = '',
    this.hintText = 'Cerca o filtra i bot',
  });

  final ValueChanged<BotFilter> onFilterChanged;
  final String initialQuery;
  final String hintText;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late final TextEditingController _controller;
  late String _currentQuery;

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.initialQuery;
    _controller = TextEditingController(text: widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFilterChanged(BotFilter.fromQuery(_currentQuery));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _currentQuery = value;
    });
    widget.onFilterChanged(BotFilter.fromQuery(value));
  }

  void _clearQuery() {
    _controller.clear();
    _onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _currentQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Pulisci ricerca',
                onPressed: _clearQuery,
              )
            : null,
        helperText:
            'Esempi: lang:python tag:utility #desktop author:"Jane Doe"',
        border: const OutlineInputBorder(),
      ),
      onChanged: _onQueryChanged,
    );
  }
}
