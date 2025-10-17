import 'dart:async';

class BrowserRunnerEvent {
  BrowserRunnerEvent({
    required this.type,
    required this.message,
    this.code,
  });

  final String type;
  final String message;
  final int? code;

  bool get isStatus => type == 'status';
}

class BrowserRunnerSession {
  BrowserRunnerSession({
    required Stream<BrowserRunnerEvent> stream,
    Future<void> Function()? onStop,
  })  : _stream = stream,
        _onStop = onStop;

  final Stream<BrowserRunnerEvent> _stream;
  final Future<void> Function()? _onStop;
  bool _stopped = false;

  Stream<BrowserRunnerEvent> get stream => _stream;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    if (_onStop != null) {
      await _onStop!();
    }
  }
}
