import 'package:flutter/material.dart';

/// Universal, brand-consistent App Logo widget for NextTripia AI.
/// Renders the authentic brand logo asset ('assets/images/app_icon.png')
/// with customizable size, optional typography label, and graceful fallback.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final String text;
  final double? fontSize;
  final Color? textColor;
  final double spacing;
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.size = 32.0,
    this.showText = false,
    this.text = 'NextTripia AI',
    this.fontSize,
    this.textColor,
    this.spacing = 10.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedTextColor = textColor ??
        (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B));
    final resolvedFontSize = fontSize ?? (size * 0.62).clamp(13.0, 24.0);

    final logoIcon = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.flight_takeoff_rounded,
          color: const Color(0xFF6366F1),
          size: size * 0.85,
        ),
      ),
    );

    if (!showText) {
      return logoIcon;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoIcon,
        SizedBox(width: spacing),
        Text(
          text,
          style: TextStyle(
            fontSize: resolvedFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: resolvedTextColor,
          ),
        ),
      ],
    );
  }
}
