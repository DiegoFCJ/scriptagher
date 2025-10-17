import 'dart:convert';

/// Describes how a bot can be executed inside a browser sandbox.
///
/// The descriptor contains the information required to bootstrap either a
/// JavaScript or a WebAssembly payload. The payload itself is typically
/// shipped as inline source (for JavaScript) or base64 (for WebAssembly).
class BrowserBotDescriptor {
  final bool compatible;
  final BrowserRuntime runtime;
  final String? script;
  final String? wasmModule;
  final String? glueCode;
  final String? entryPoint;
  final List<String> args;
  final Map<String, dynamic> metadata;

  const BrowserBotDescriptor({
    required this.compatible,
    required this.runtime,
    this.script,
    this.wasmModule,
    this.glueCode,
    this.entryPoint,
    this.args = const <String>[],
    this.metadata = const <String, dynamic>{},
  });

  /// Returns true when the descriptor contains enough information to run.
  bool get hasRunnablePayload {
    switch (runtime) {
      case BrowserRuntime.javascript:
        return (script != null && script!.trim().isNotEmpty) ||
            (glueCode != null && glueCode!.trim().isNotEmpty);
      case BrowserRuntime.wasm:
        return wasmModule != null && wasmModule!.trim().isNotEmpty;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'compatible': compatible,
      'runtime': runtime.name,
      if (script != null) 'script': script,
      if (wasmModule != null) 'wasmModule': wasmModule,
      if (glueCode != null) 'glueCode': glueCode,
      if (entryPoint != null) 'entryPoint': entryPoint,
      if (args.isNotEmpty) 'args': args,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  String toEncodedJson() => jsonEncode(toJson());

  factory BrowserBotDescriptor.fromJson(Map<String, dynamic> json) {
    final runtimeRaw = (json['runtime'] ?? json['type'] ?? 'javascript')
        .toString()
        .toLowerCase();
    final runtime = BrowserRuntimeExtension.fromString(runtimeRaw);

    final argsRaw = json['args'];
    final args = argsRaw is List
        ? argsRaw.map((dynamic value) => value.toString()).toList()
        : const <String>[];

    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(metadataRaw)
        : <String, dynamic>{};

    return BrowserBotDescriptor(
      compatible: _parseCompatibility(json),
      runtime: runtime,
      script: _stringOrNull(json['script'] ?? json['javascript'] ?? json['code']),
      wasmModule: _stringOrNull(json['wasm'] ?? json['wasmModule']),
      glueCode: _stringOrNull(json['glue'] ?? json['bootstrap'] ?? json['loader']),
      entryPoint: _stringOrNull(json['entryPoint'] ?? json['entry_point']),
      args: args,
      metadata: metadata,
    );
  }

  factory BrowserBotDescriptor.fromEncodedJson(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) {
      return BrowserBotDescriptor.fromJson(decoded);
    }
    throw FormatException('Invalid browser payload encoding');
  }

  static bool _parseCompatibility(Map<String, dynamic> json) {
    final compatValue = json['compatible'] ??
        json['browserCompatible'] ??
        json['supportsBrowser'];
    if (compatValue is bool) {
      return compatValue;
    }
    if (compatValue is num) {
      return compatValue != 0;
    }
    if (compatValue is String) {
      final normalized = compatValue.toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString();
    if (stringValue.trim().isEmpty) return null;
    return stringValue;
  }
}

enum BrowserRuntime { javascript, wasm }

extension BrowserRuntimeExtension on BrowserRuntime {
  static BrowserRuntime fromString(String value) {
    switch (value) {
      case 'js':
      case 'javascript':
        return BrowserRuntime.javascript;
      case 'wasm':
      case 'webassembly':
        return BrowserRuntime.wasm;
      default:
        return BrowserRuntime.javascript;
    }
  }
}
