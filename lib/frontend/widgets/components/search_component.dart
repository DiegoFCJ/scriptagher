import 'package:flutter/material.dart';

class SearchView extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const SearchView({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'Cerca un bot',
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerListener);
    super.dispose();
  }

  void _controllerListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.hintText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  widget.controller.clear();
                  widget.onClear?.call();
                  widget.onChanged?.call('');
                },
              )
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }
}
