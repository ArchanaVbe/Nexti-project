import 'package:flutter/material.dart';

/// Standard Google Maps Pin icon featuring the authentic Google Maps brand logo.
class GoogleMapsIcon extends StatelessWidget {
  final double size;
  final bool hasShadow;

  const GoogleMapsIcon({
    super.key,
    this.size = 24,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      'assets/images/google_maps_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to high-quality Material pin in Google Maps Red
        return Icon(
          Icons.location_on_rounded,
          size: size,
          color: const Color(0xFFEA4335),
        );
      },
    );

    if (hasShadow) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
