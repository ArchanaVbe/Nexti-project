import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  File? sourceFile;
  for (final path in [
    'assets/images/app_icon.jpeg',
    'assets/images/app_icon.jpg',
    'assets/images/app_icon.png',
  ]) {
    final candidate = File(path);
    if (candidate.existsSync()) {
      sourceFile = candidate;
      print('Found source icon at: $path');
      break;
    }
  }

  if (sourceFile == null) {
    print('Error: No source icon found in assets/images/');
    exit(1);
  }

  final bytes = sourceFile.readAsBytesSync();
  final rawImage = img.decodeImage(bytes);
  if (rawImage == null) {
    print('Failed to decode image');
    exit(1);
  }

  print('Loaded source image: ${rawImage.width}x${rawImage.height}');

  // 1. Remove black background with smooth alpha un-premultiplication
  // This extracts ONLY the neon "N" and airplane, with 100% transparent background.
  final transparentImg = img.Image(width: rawImage.width, height: rawImage.height, numChannels: 4);
  const double lowThreshold = 55.0;
  const double highThreshold = 105.0;

  for (int y = 0; y < rawImage.height; y++) {
    for (int x = 0; x < rawImage.width; x++) {
      final p = rawImage.getPixel(x, y);
      final double r = p.r.toDouble();
      final double g = p.g.toDouble();
      final double b = p.b.toDouble();
      final double maxC = [r, g, b].reduce((a, b) => a > b ? a : b);

      if (maxC <= lowThreshold) {
        transparentImg.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (maxC >= highThreshold) {
        transparentImg.setPixelRgba(x, y, r.round(), g.round(), b.round(), 255);
      } else {
        final double t = (maxC - lowThreshold) / (highThreshold - lowThreshold);
        final double alpha = t * t * (3 - 2 * t);
        final double boost = (highThreshold / maxC);
        final int nr = (r * boost).round().clamp(0, 255);
        final int ng = (g * boost).round().clamp(0, 255);
        final int nb = (b * boost).round().clamp(0, 255);
        final int na = (alpha * 255).round().clamp(0, 255);
        transparentImg.setPixelRgba(x, y, nr, ng, nb, na);
      }
    }
  }

  // 2. Compute exact bounding box of the "N" design
  int minX = transparentImg.width, maxX = 0;
  int minY = transparentImg.height, maxY = 0;
  for (int y = 0; y < transparentImg.height; y++) {
    for (int x = 0; x < transparentImg.width; x++) {
      final p = transparentImg.getPixel(x, y);
      if (p.a > 15) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  final croppedWidth = maxX - minX + 1;
  final croppedHeight = maxY - minY + 1;
  print('Logo content bounds: ${croppedWidth}x$croppedHeight');

  // 3. Center the logo with optical padding in a high-res square canvas (1024x1024)
  const int targetCanvasSize = 1024;
  final centeredLogo = img.Image(width: targetCanvasSize, height: targetCanvasSize, numChannels: 4);
  for (int y = 0; y < targetCanvasSize; y++) {
    for (int x = 0; x < targetCanvasSize; x++) {
      centeredLogo.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }

  // Crop source content
  final croppedContent = img.copyCrop(transparentImg, x: minX, y: minY, width: croppedWidth, height: croppedHeight);
  
  // Scale to fit ~86% of the 1024 canvas for crisp, balanced optical display
  final maxDim = max(croppedWidth, croppedHeight);
  final targetDim = (targetCanvasSize * 0.86).round();
  final scaleFactor = targetDim / maxDim;
  final scaledW = (croppedWidth * scaleFactor).round();
  final scaledH = (croppedHeight * scaleFactor).round();
  final scaledContent = img.copyResize(croppedContent, width: scaledW, height: scaledH, interpolation: img.Interpolation.cubic);

  final dstX = (targetCanvasSize - scaledW) ~/ 2;
  final dstY = (targetCanvasSize - scaledH) ~/ 2;
  img.compositeImage(centeredLogo, scaledContent, dstX: dstX, dstY: dstY);

  // 4. Save canonical transparent in-app asset: assets/images/app_icon.png
  final assetFile = File('assets/images/app_icon.png');
  assetFile.writeAsBytesSync(img.encodePng(centeredLogo));
  print('Saved transparent in-app icon: assets/images/app_icon.png (1024x1024, 100% transparent background)');

  // 5. Android Launcher Mipmaps (Standard & Round with transparent background)
  final androidMipmaps = {
    'android/app/src/main/res/mipmap-mdpi': 48,
    'android/app/src/main/res/mipmap-hdpi': 72,
    'android/app/src/main/res/mipmap-xhdpi': 96,
    'android/app/src/main/res/mipmap-xxhdpi': 144,
    'android/app/src/main/res/mipmap-xxxhdpi': 192,
  };

  for (final entry in androidMipmaps.entries) {
    final resized = img.copyResize(centeredLogo, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    
    final outFile = File('${entry.key}/ic_launcher.png');
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(resized));

    final roundFile = File('${entry.key}/ic_launcher_round.png');
    roundFile.writeAsBytesSync(img.encodePng(resized));
    print('Wrote ${outFile.path} (${entry.value}x${entry.value})');
  }

  // 5b. Android Adaptive Icon Foreground (108dp canvas with safe zone)
  final adaptiveMipmaps = {
    'android/app/src/main/res/mipmap-mdpi': 108,
    'android/app/src/main/res/mipmap-hdpi': 162,
    'android/app/src/main/res/mipmap-xhdpi': 216,
    'android/app/src/main/res/mipmap-xxhdpi': 324,
    'android/app/src/main/res/mipmap-xxxhdpi': 432,
  };

  for (final entry in adaptiveMipmaps.entries) {
    final canvasSize = entry.value;
    final fgCanvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
    for (int y = 0; y < canvasSize; y++) {
      for (int x = 0; x < canvasSize; x++) {
        fgCanvas.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
    final logoSize = (canvasSize * 0.72).round();
    final resizedLogo = img.copyResize(centeredLogo, width: logoSize, height: logoSize, interpolation: img.Interpolation.cubic);
    final offset = (canvasSize - logoSize) ~/ 2;
    img.compositeImage(fgCanvas, resizedLogo, dstX: offset, dstY: offset);

    final fgFile = File('${entry.key}/ic_launcher_foreground.png');
    fgFile.parent.createSync(recursive: true);
    fgFile.writeAsBytesSync(img.encodePng(fgCanvas));
    print('Wrote ${fgFile.path} (${canvasSize}x$canvasSize)');
  }

  // 6. Web icons (transparent background)
  final webIcons = {
    'web/favicon.png': 48,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  };

  for (final entry in webIcons.entries) {
    final resized = img.copyResize(centeredLogo, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    final outFile = File(entry.key);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('Wrote ${entry.key} (${entry.value}x${entry.value})');
  }

  // 7. Windows runner ico
  try {
    final icoResized = img.copyResize(centeredLogo, width: 256, height: 256, interpolation: img.Interpolation.cubic);
    final icoFile = File('windows/runner/resources/app_icon.ico');
    if (icoFile.existsSync()) {
      icoFile.writeAsBytesSync(img.encodeIco(icoResized));
      print('Wrote windows/runner/resources/app_icon.ico (256x256)');
    }
  } catch (e) {
    print('Windows ico note: $e');
  }

  print('All transparent icons successfully generated!');
}
