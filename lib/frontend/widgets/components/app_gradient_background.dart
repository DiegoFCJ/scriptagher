import 'package:flutter/material.dart';

/// Wraps content with the gradient background used across the landing
/// experience and secondary pages.
class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({
    super.key,
    required this.child,
    this.padding,
    this.applyTopSafeArea = true,
    this.applyBottomSafeArea = true,
  });

  /// Content rendered on top of the gradient background.
  final Widget child;

  /// Optional padding applied inside the safe area.
  final EdgeInsetsGeometry? padding;

  /// Whether to honor the top safe area. Disable when the parent already
  /// accounts for it (e.g. Scaffold with AppBar).
  final bool applyTopSafeArea;

  /// Whether to honor the bottom safe area.
  final bool applyBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        colorScheme.primaryContainer.withOpacity(0.35),
        colorScheme.surface,
        colorScheme.background,
      ],
    );

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: SafeArea(
        top: applyTopSafeArea,
        bottom: applyBottomSafeArea,
        child: content,
      ),
    );
  }
}
