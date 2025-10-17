// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:scriptagher/shared/models/browser_bot_descriptor.dart';

import '../../models/bot.dart';
import 'browser_bot_runner_base.dart';

class _ImmediateSession implements BrowserBotSession {
  final StreamController<BotSandboxMessage> _controller =
      StreamController<BotSandboxMessage>();

  _ImmediateSession(BotSandboxMessage message) {
    _controller.add(message);
    _controller.close();
  }

  @override
  Future<void> get completed => Future.value();

  @override
  Stream<BotSandboxMessage> get messages => _controller.stream;

  @override
  void terminate() {}
}

class _WebBrowserBotSession implements BrowserBotSession {
  final html.Worker _worker;
  final StreamController<BotSandboxMessage> _controller;
  final Completer<void> _completer;

  _WebBrowserBotSession(this._worker, this._controller, this._completer);

  @override
  Future<void> get completed => _completer.future;

  @override
  Stream<BotSandboxMessage> get messages => _controller.stream;

  @override
  void terminate() {
    _worker.terminate();
    if (!_controller.isClosed) {
      _controller.add(
          BotSandboxMessage.system('Sandbox terminated by the host application.'));
      _controller.close();
    }
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class _WebBrowserBotRunner implements BrowserBotRunner {
  _WebBrowserBotSession? _currentSession;

  @override
  bool canRun(Bot bot) {
    return bot.browserDescriptor?.compatible == true &&
        bot.browserDescriptor!.hasRunnablePayload;
  }

  @override
  BrowserBotSession run(Bot bot) {
    _currentSession?.terminate();

    final descriptor = bot.browserDescriptor;
    if (descriptor == null || !descriptor.compatible) {
      return _ImmediateSession(BotSandboxMessage.stderr(
          'Bot ${bot.botName} is not compatible with the browser runtime.'));
    }

    if (!descriptor.hasRunnablePayload) {
      return _ImmediateSession(BotSandboxMessage.stderr(
          'Bot ${bot.botName} does not provide a runnable browser payload.'));
    }

    final controller = StreamController<BotSandboxMessage>.broadcast();
    final completer = Completer<void>();

    final worker =
        _createWorker(bot, descriptor, controller, completer);
    final session = _WebBrowserBotSession(worker, controller, completer);
    _currentSession = session;
    return session;
  }

  @override
  void dispose() {
    _currentSession?.terminate();
    _currentSession = null;
  }

  html.Worker _createWorker(
    Bot bot,
    BrowserBotDescriptor descriptor,
    StreamController<BotSandboxMessage> controller,
    Completer<void> completer,
  ) {
    final script = _buildWorkerScript(bot);
    final glue = descriptor.glueCode;
    final payloadScript = StringBuffer()
      ..write(script)
      ..write('\n')
      ..write(_buildRuntimeScript(descriptor, glue));

    final blob = html.Blob([payloadScript.toString()], 'application/javascript');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final worker = html.Worker(url);
    html.Url.revokeObjectUrl(url);

    worker.onMessage.listen((event) {
      final data = event.data;
      if (data is Map) {
        final type = data['type'];
        final message = data['data']?.toString() ?? '';
        switch (type) {
          case 'stdout':
            controller.add(BotSandboxMessage.stdout(message));
            break;
          case 'stderr':
            controller.add(BotSandboxMessage.stderr(message));
            break;
          case 'system':
            controller.add(BotSandboxMessage.system(message));
            break;
          case 'complete':
            controller.add(BotSandboxMessage.system(message));
            worker.terminate();
            controller.close();
            if (!completer.isCompleted) {
              completer.complete();
            }
            break;
          default:
            controller.add(BotSandboxMessage.stdout(jsonEncode(data)));
        }
      } else {
        controller.add(BotSandboxMessage.stdout(data.toString()));
      }
    });

    worker.onError.listen((event) {
      controller.add(BotSandboxMessage.stderr('${event.message}'));
      if (!completer.isCompleted) {
        completer.completeError(event.message ?? 'Worker error');
      }
      if (!controller.isClosed) {
        controller.close();
      }
    });

    worker.postMessage({
      'type': 'start',
      'bot': {
        'name': bot.botName,
        'language': bot.language,
      },
    });

    controller.add(BotSandboxMessage.system(
        'Avvio del bot ${bot.botName} nel sandbox del browser...'));

    return worker;
  }

  String _buildWorkerScript(Bot bot) {
    final metadata = bot.browserDescriptor?.metadata ?? const <String, dynamic>{};
    final args = bot.browserDescriptor?.args ?? const <String>[];

    return '''
const send = (type, data) => self.postMessage({ type, data });
const sendStdout = (data) => send('stdout', data);
const sendStderr = (data) => send('stderr', data);
const finalize = (data) => send('complete', data);

self.console = self.console || {};
self.console.log = (...args) => sendStdout(args.join(' '));
self.console.error = (...args) => sendStderr(args.join(' '));
self.console.warn = (...args) => send('system', args.join(' '));

self.__SCRIPTAGHER_METADATA__ = ${jsonEncode(metadata)};
self.__SCRIPTAGHER_ARGS__ = ${jsonEncode(args)};

self.onmessage = (event) => {
  if (event.data && event.data.type === 'terminate') {
    send('system', 'Sandbox terminated by host');
    close();
  }
};
''';
  }

  String _buildRuntimeScript(BrowserBotDescriptor descriptor, String? glue) {
    switch (descriptor.runtime) {
      case BrowserRuntime.javascript:
        return _buildJavaScriptRuntime(descriptor, glue);
      case BrowserRuntime.wasm:
        return _buildWasmRuntime(descriptor, glue);
    }
  }

  String _buildJavaScriptRuntime(
      BrowserBotDescriptor descriptor, String? glue) {
    final buffer = StringBuffer();
    if (glue != null && glue.isNotEmpty) {
      buffer.writeln(glue);
    }
    if (descriptor.script != null) {
      buffer.writeln(descriptor.script);
    }

    final entryPoint = descriptor.entryPoint;
    if (entryPoint != null && entryPoint.isNotEmpty) {
      buffer.writeln('''
(async () => {
  try {
    const entry = self[${jsonEncode(entryPoint)}];
    if (typeof entry === 'function') {
      const result = entry(self.__SCRIPTAGHER_ARGS__, self.__SCRIPTAGHER_METADATA__);
      if (result && typeof result.then === 'function') {
        await result;
      }
    }
    finalize('Execution completed');
  } catch (err) {
    sendStderr(err && err.stack ? err.stack : String(err));
    finalize('Execution failed');
  }
})();
''');
    } else {
      buffer.writeln(
          'send("system", ${jsonEncode('No entry point provided for JS payload.')});');
      buffer.writeln('finalize("Execution completed");');
    }

    return buffer.toString();
  }

  String _buildWasmRuntime(
      BrowserBotDescriptor descriptor, String? glue) {
    final wasmModule = descriptor.wasmModule ?? '';
    final entryPoint = descriptor.entryPoint ?? 'main';

    final buffer = StringBuffer();
    buffer.writeln('''
function base64ToUint8Array(base64) {
  const binaryString = atob(base64);
  const length = binaryString.length;
  const bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

async function runWasm() {
  try {
    const wasmBytes = base64ToUint8Array(${jsonEncode(wasmModule)});
    const defaultImports = {
      env: {
        print: (value) => sendStdout(String(value)),
        puts: (value) => sendStdout(String(value)),
        log: (value) => sendStdout(String(value)),
      },
    };
''');

    if (glue != null && glue.isNotEmpty) {
      buffer.writeln(glue);
    }

    buffer.writeln('''
    const imports = typeof createImportObject === 'function'
      ? createImportObject(sendStdout, self.__SCRIPTAGHER_METADATA__)
      : defaultImports;
    const { instance } = await WebAssembly.instantiate(wasmBytes, imports);
    const entry = instance.exports[${jsonEncode(entryPoint)}];
    if (typeof entry === 'function') {
      const result = entry();
      if (typeof result !== 'undefined') {
        send('system', `WASM returned: ${'$'}{result}`);
      }
    } else {
      sendStderr(${jsonEncode('WASM module is missing the entry point $entryPoint.')});
    }
    finalize('Execution completed');
  } catch (err) {
    sendStderr(err && err.stack ? err.stack : String(err));
    finalize('Execution failed');
  }
}

runWasm();
''');

    return buffer.toString();
  }
}

BrowserBotRunner createBrowserBotRunner() => _WebBrowserBotRunner();
