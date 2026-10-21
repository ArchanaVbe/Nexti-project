import 'package:flutter/material.dart';

/// Official Google 'G' logo featuring Google's authentic 4-color brand mark.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({
    super.key,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              'G',
              style: TextStyle(
                fontSize: size * 0.75,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4285F4),
              ),
            ),
          ),
        );
      },
    );
  }
}
