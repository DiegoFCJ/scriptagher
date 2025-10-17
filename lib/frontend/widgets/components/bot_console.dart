import 'package:flutter/material.dart';

import '../../services/browser_bot_runner/browser_bot_runner.dart';

class BotConsole extends StatefulWidget {
  final List<BotSandboxMessage> messages;
  final VoidCallback? onClear;

  const BotConsole({super.key, required this.messages, this.onClear});

  @override
  State<BotConsole> createState() => _BotConsoleState();
}

class _BotConsoleState extends State<BotConsole> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant BotConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Console',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.onClear != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Pulisci output',
                onPressed: widget.onClear,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final entry = widget.messages[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    entry.message,
                    style: TextStyle(
                      color: _colorForType(entry.type),
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Color _colorForType(BotSandboxMessageType type) {
    switch (type) {
      case BotSandboxMessageType.stdout:
        return Colors.greenAccent.shade200;
      case BotSandboxMessageType.stderr:
        return Colors.redAccent.shade200;
      case BotSandboxMessageType.system:
        return Colors.blueAccent.shade100;
    }
  }
}
