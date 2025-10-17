// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/bot.dart';
import 'browser_bot_runner_stub.dart';
import 'browser_runner_models.dart';

class BrowserBotRunnerWeb implements BrowserBotRunnerDelegate {
  BrowserBotRunnerWeb({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;

  @override
  bool get isSupported => true;

  @override
  Future<BrowserRunnerSession> start(
    Bot bot, {
    required String baseUrl,
  }) async {
    if (bot.compat.browserSupported != true ||
        !bot.compat.browserPayloads.hasJavaScript) {
      throw StateError('Bot non compatibile con l\'esecuzione nel browser');
    }

    final resolvedScript = await _resolveScript(bot, baseUrl);
    if (resolvedScript == null) {
      throw StateError('Payload JavaScript mancante per ${bot.botName}.');
    }

    final wasmBytes = await _resolveWasm(bot, baseUrl);
    final worker = _createWorker();
    final controller = StreamController<BrowserRunnerEvent>.broadcast();
    StreamSubscription<MessageEvent>? messageSub;
    StreamSubscription<Event>? errorSub;

    void handleError(Object error) {
      if (!controller.isClosed) {
        controller.add(
          BrowserRunnerEvent(
            type: 'stderr',
            message: error.toString(),
          ),
        );
        controller.add(
          BrowserRunnerEvent(type: 'status', message: 'failed'),
        );
      }
    }

    try {
      messageSub = worker.onMessage.listen((event) {
        _handleWorkerMessage(controller, event.data);
      });

      errorSub = worker.onError.listen((event) {
        final message = event is ErrorEvent
            ? (event.message?.toString() ?? 'Worker error')
            : 'Worker error';
        handleError(message);
      });

      final buffer = wasmBytes?.buffer;
      final payloadMessage = <String, Object?>{
        'type': 'start',
        if (resolvedScript.source != null) 'source': resolvedScript.source,
        if (resolvedScript.url != null) 'scriptUrl': resolvedScript.url,
        if (buffer != null) 'wasmBytes': buffer,
        'baseUrl': baseUrl,
        'bot': {
          'name': bot.botName,
          'language': bot.language,
        },
        if (bot.compat.browserRunner != null)
          'runner': bot.compat.browserRunner,
        if (bot.compat.browserPayloads.metadata.isNotEmpty)
          'metadata': bot.compat.browserPayloads.metadata,
        if (!bot.compat.browserPayloads.isEmpty)
          'payloads': bot.compat.browserPayloads.toJson(),
      };

      if (buffer != null) {
        worker.postMessage(payloadMessage, [buffer]);
      } else {
        worker.postMessage(payloadMessage);
      }
    } catch (error, stackTrace) {
      messageSub?.cancel();
      errorSub?.cancel();
      worker.terminate();
      await _closeController(controller);
      Error.throwWithStackTrace(error, stackTrace);
    }

    return BrowserRunnerSession(
      stream: controller.stream,
      onStop: () async {
        try {
          worker.postMessage({'type': 'terminate'});
        } catch (_) {}
        worker.terminate();
        await messageSub?.cancel();
        await errorSub?.cancel();
        await _closeController(controller);
      },
    );
  }

  Future<void> _closeController(
      StreamController<BrowserRunnerEvent> controller) async {
    if (!controller.isClosed) {
      await controller.close();
    }
  }

  Worker _createWorker() {
    final blob = Blob(<String>[_workerBootstrap], 'application/javascript');
    final url = Url.createObjectUrlFromBlob(blob);
    final worker = Worker(url);
    Url.revokeObjectUrl(url);
    return worker;
  }

  Future<_ResolvedScript?> _resolveScript(Bot bot, String baseUrl) async {
    final payload = bot.compat.browserPayloads.javascript;
    if (payload == null || !payload.hasData) {
      return null;
    }

    final source = payload.decodeUtf8();
    if (source != null && source.trim().isNotEmpty) {
      return _ResolvedScript(source: source);
    }

    final url = payload.url;
    if (url != null && url.isNotEmpty) {
      return _ResolvedScript(url: _resolveUrl(baseUrl, url));
    }

    return null;
  }

  Future<Uint8List?> _resolveWasm(Bot bot, String baseUrl) async {
    final payload = bot.compat.browserPayloads.wasm;
    if (payload == null || !payload.hasData) {
      return null;
    }

    final inlineBytes = payload.decodeBytes();
    if (inlineBytes != null && inlineBytes.isNotEmpty) {
      return inlineBytes;
    }

    final url = payload.url;
    if (url != null && url.isNotEmpty) {
      final resolved = _resolveUrl(baseUrl, url);
      final response = await _httpClient.get(Uri.parse(resolved));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Uint8List.fromList(response.bodyBytes);
      }
      throw StateError(
          'Impossibile scaricare il payload WASM (${response.statusCode}).');
    }

    return null;
  }

  void _handleWorkerMessage(
    StreamController<BrowserRunnerEvent> controller,
    dynamic data,
  ) {
    if (controller.isClosed) {
      return;
    }

    if (data is Map) {
      final type = data['type']?.toString() ?? 'stdout';
      final message = data['message']?.toString() ?? '';
      final rawCode = data['code'];
      int? code;
      if (rawCode is num) {
        code = rawCode.toInt();
      } else if (rawCode is String) {
        code = int.tryParse(rawCode);
      }
      controller.add(
        BrowserRunnerEvent(
          type: type,
          message: message,
          code: code,
        ),
      );
    } else if (data != null) {
      controller.add(
        BrowserRunnerEvent(
          type: 'stdout',
          message: data.toString(),
        ),
      );
    }
  }

  String _resolveUrl(String baseUrl, String value) {
    final base = Uri.parse(baseUrl);
    final target = Uri.parse(value);
    return (target.hasScheme ? target : base.resolveUri(target)).toString();
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}

class _ResolvedScript {
  const _ResolvedScript({this.source, this.url});

  final String? source;
  final String? url;
}

const String _workerBootstrap = r'''
self.console = {
  log: (...args) => self.postMessage({ type: 'stdout', message: args.join(' ') }),
  error: (...args) => self.postMessage({ type: 'stderr', message: args.join(' ') }),
};

function send(type, message, extra) {
  const payload = Object.assign({ type, message: String(message ?? '') }, extra || {});
  self.postMessage(payload);
}

self.onmessage = async (event) => {
  const data = event.data || {};
  if (data.type === 'start') {
    try {
      let entrypoint = null;
      if (typeof data.source === 'string' && data.source.length > 0) {
        entrypoint = new Function('sandbox', 'context', data.source);
      }
      if (typeof data.scriptUrl === 'string' && data.scriptUrl.length > 0) {
        importScripts(data.scriptUrl);
        if (typeof self.scriptagherMain === 'function') {
          entrypoint = self.scriptagherMain;
        }
      }
      const sandbox = {
        print: (value) => send('stdout', value),
        error: (value) => send('stderr', value),
        status: (value, code) => send('status', value, code != null ? { code } : {}),
        emit: (type, value, extra) => send(type, value, extra),
        wasmBytes: data.wasmBytes || null,
        baseUrl: data.baseUrl || null,
        bot: data.bot || {},
        metadata: data.metadata || {},
        payloads: data.payloads || {},
      };
      if (!entrypoint) {
        throw new Error('Nessun entrypoint disponibile per il bot.');
      }
      const context = {
        wasmBytes: data.wasmBytes || null,
        baseUrl: data.baseUrl || null,
        bot: data.bot || {},
        metadata: data.metadata || {},
        payloads: data.payloads || {},
      };
      const result = await entrypoint(sandbox, context);
      if (typeof result === 'string' && result.length > 0) {
        sandbox.print(result);
      }
      sandbox.status('finished', 0);
    } catch (error) {
      const message = error && error.stack ? String(error.stack) : String(error);
      send('stderr', message);
      send('status', 'failed', { code: 1 });
    }
  } else if (data.type === 'stdin') {
    if (typeof self.scriptagherOnInput === 'function') {
      try {
        await self.scriptagherOnInput(data.message);
      } catch (error) {
        const message = error && error.stack ? String(error.stack) : String(error);
        send('stderr', message);
      }
    }
  } else if (data.type === 'terminate') {
    close();
  }
};
''';

BrowserBotRunnerDelegate createBrowserRunner({http.Client? httpClient}) =>
    BrowserBotRunnerWeb(httpClient: httpClient);

bool get browserRunnerSupported => true;
