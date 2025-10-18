import 'package:flutter/material.dart';

class GradientHeroSection extends StatelessWidget {
  const GradientHeroSection({
    super.key,
    this.eyebrow,
    required this.title,
    required this.subtitle,
    this.primaryAction,
    this.secondaryAction,
    this.icon,
    this.leading,
    this.alignment = CrossAxisAlignment.start,
    this.padding = const EdgeInsets.all(24),
    this.gradient,
  });

  final String? eyebrow;
  final String title;
  final String subtitle;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final IconData? icon;
  final Widget? leading;
  final CrossAxisAlignment alignment;
  final EdgeInsets padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedGradient = gradient ??
        const LinearGradient(
          colors: [Color(0xFF4E54C8), Color(0xFF8F94FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 680;
        final textTheme = theme.textTheme;

        final content = Column(
          crossAxisAlignment: alignment,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (eyebrow != null)
              Text(
                eyebrow!,
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              title,
              style: textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ) ??
                  const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (primaryAction != null) primaryAction!,
                if (secondaryAction != null) secondaryAction!,
              ],
            ),
          ],
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: resolvedGradient,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: padding.add(EdgeInsets.only(
              top: leading != null ? 12 : 0,
            )),
            child: Stack(
              children: [
                if (leading != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: leading!,
                  ),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: content),
                      if (icon != null)
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              icon,
                              size: 120,
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            icon,
                            size: 72,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      content,
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
