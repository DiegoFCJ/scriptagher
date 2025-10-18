import 'package:flutter/material.dart';

class CallToActionBanner extends StatelessWidget {
  const CallToActionBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryAction,
    this.secondaryAction,
    this.gradient,
    this.icon,
  });

  final String title;
  final String subtitle;
  final Widget primaryAction;
  final Widget? secondaryAction;
  final Gradient? gradient;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedGradient = gradient ??
        const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: resolvedGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ) ??
                      const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
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
                    primaryAction,
                    if (secondaryAction != null) secondaryAction!,
                  ],
                ),
              ],
            );

            if (!isWide) {
              return content;
            }

            return Row(
              children: [
                Expanded(child: content),
                if (icon != null)
                  Icon(
                    icon,
                    color: Colors.white.withOpacity(0.2),
                    size: 96,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
