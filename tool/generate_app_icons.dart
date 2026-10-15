import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/app_icon.png');
  if (!file.existsSync()) {
    print('Error: assets/images/app_icon.png not found');
    exit(1);
  }

  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    exit(1);
  }

  print('Original size: ${image.width}x${image.height}');

  // Crop / square fit if needed
  img.Image squareImage;
  if (image.width == image.height) {
    squareImage = image;
  } else {
    final size = image.width > image.height ? image.width : image.height;
    squareImage = img.Image(width: size, height: size, numChannels: 4);
    // Fill white or transparent? Let's check corners
    final cornerPixel = image.getPixel(0, 0);
    print('Corner pixel: r=${cornerPixel.r}, g=${cornerPixel.g}, b=${cornerPixel.b}, a=${cornerPixel.a}');
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        squareImage.setPixel(x, y, cornerPixel);
      }
    }
    final offsetX = (size - image.width) ~/ 2;
    final offsetY = (size - image.height) ~/ 2;
    img.compositeImage(squareImage, image, dstX: offsetX, dstY: offsetY);
  }

  // 1. Android Mipmaps
  final androidMipmaps = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in androidMipmaps.entries) {
    final resized = img.copyResize(squareImage, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    final outFile = File(entry.key);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('Wrote ${entry.key} (${entry.value}x${entry.value})');
  }

  // 2. iOS AppIcon set
  final iosIcons = {
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
  };

  for (final entry in iosIcons.entries) {
    final resized = img.copyResize(squareImage, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    final outFile = File(entry.key);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('Wrote ${entry.key} (${entry.value}x${entry.value})');
  }

  // 3. Web icons
  final webIcons = {
    'web/favicon.png': 48,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  };

  for (final entry in webIcons.entries) {
    final resized = img.copyResize(squareImage, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    final outFile = File(entry.key);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('Wrote ${entry.key} (${entry.value}x${entry.value})');
  }

  // 4. Windows runner ico
  try {
    final icoResized = img.copyResize(squareImage, width: 256, height: 256, interpolation: img.Interpolation.cubic);
    final icoFile = File('windows/runner/resources/app_icon.ico');
    if (icoFile.existsSync()) {
      icoFile.writeAsBytesSync(img.encodeIco(icoResized));
      print('Wrote windows/runner/resources/app_icon.ico (256x256)');
    }
  } catch (e) {
    print('Windows ico note: $e');
  }

  print('All app launcher icons successfully created!');
}
