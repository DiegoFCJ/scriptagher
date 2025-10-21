import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays feedback messages using a top-anchored material banner on
/// Android/iOS and falls back to traditional snackbars on other platforms.
class FeedbackBanner {
  FeedbackBanner._();

  static Timer? _activeTimer;

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Shows a feedback message that adapts to the current platform.
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
    IconData? icon,
    String? dismissLabel,
  }) {
    if (context is! Element || !(context as Element).mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger.hideCurrentSnackBar();

    if (_isMobilePlatform) {
      _showMaterialBanner(
        context,
        messenger,
        message,
        isError: isError,
        duration: duration,
        icon: icon,
        dismissLabel: dismissLabel,
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
    }
  }

  static void _showMaterialBanner(
    BuildContext context,
    ScaffoldMessengerState messenger,
    String message, {
    required bool isError,
    required Duration duration,
    IconData? icon,
    String? dismissLabel,
  }) {
    messenger.clearMaterialBanners();
    _activeTimer?.cancel();

    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isError ? colorScheme.errorContainer : colorScheme.secondaryContainer;
    final foregroundColor =
        isError ? colorScheme.onErrorContainer : colorScheme.onSecondaryContainer;
    final effectiveIcon =
        icon ?? (isError ? Icons.error_outline_rounded : Icons.info_outline_rounded);
    final effectiveDismissLabel = (dismissLabel ?? 'Chiudi').toUpperCase();

    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: backgroundColor,
        content: Text(
          message,
          style: TextStyle(color: foregroundColor),
        ),
        leading: Icon(effectiveIcon, color: foregroundColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            style: TextButton.styleFrom(
              foregroundColor: foregroundColor,
            ),
            child: Text(effectiveDismissLabel),
          ),
        ],
      ),
    );

    _activeTimer = Timer(duration, () {
      if (messenger.mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }
}
