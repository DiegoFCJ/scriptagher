import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/utils/execution_compatibility.dart';

Bot _createBot(BotCompat compat) {
  return Bot(
    botName: 'Test Bot',
    description: 'desc',
    startCommand: 'run',
    sourcePath: '/data/remote/test',
    language: 'python',
    compat: compat,
  );
}

void main() {
  test('web execution is blocked when browser runner is unavailable', () {
    const compat = BotCompat(
      browserSupported: false,
      browserReason: 'No browser',
    );
    final bot = _createBot(compat);

    final result = computeExecutionCompatibility(
      bot: bot,
      isWebPlatform: true,
      isDesktopPlatform: false,
      isMobilePlatform: false,
      shouldUseBrowserRunner: false,
    );

    expect(result.isSupported, isFalse);
    expect(result.reason, contains('browser'));
  });

  test('mobile execution uses metadata to determine support', () {
    final compat = BotCompat(
      browserPayloads: const BrowserPayloads(
        metadata: {
          'mobile': {
            'supported': false,
            'reason': 'Non disponibile su mobile',
          },
        },
      ),
    );
    final bot = _createBot(compat);

    final result = computeExecutionCompatibility(
      bot: bot,
      isWebPlatform: false,
      isDesktopPlatform: false,
      isMobilePlatform: true,
      shouldUseBrowserRunner: false,
    );

    expect(result.isSupported, isFalse);
    expect(result.reason, contains('mobile'));
  });
}
