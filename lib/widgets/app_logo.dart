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
    final resolvedRadius = borderRadius ?? BorderRadius.circular(size * 0.25);
    final resolvedTextColor = textColor ??
        (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B));
    final resolvedFontSize = fontSize ?? (size * 0.62).clamp(13.0, 24.0);

    final logoIcon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.3 : 0.15),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: Image.asset(
          'assets/images/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFF6366F1),
            child: Icon(
              Icons.flight_takeoff_rounded,
              color: Colors.white,
              size: size * 0.6,
            ),
          ),
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
