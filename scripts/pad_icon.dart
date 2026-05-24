// Run this script from the project root using:
// dart run scripts/pad_icon.dart

import 'dart:io';
import 'package:image/image.dart' as img;
void main() {
  // Pad foreground icon for adaptive icon and splash screen.
  final imageFile = File('assets/icon_foreground.png');
  final original = img.decodeImage(imageFile.readAsBytesSync());
  if (original != null) {
    // Create new transparent image 1024x1024
    final canvas = img.Image(width: 1024, height: 1024, numChannels: 4);
    
    // Scale original to 640x640 (roughly 60% size, well within the 66% Android safe zone)
    final scaled = img.copyResize(original, width: 640, height: 640, interpolation: img.Interpolation.linear);
    
    // Draw scaled onto newImg at center
    img.compositeImage(canvas, scaled, dstX: (1024 - 640) ~/ 2, dstY: (1024 - 640) ~/ 2);
    
    File('assets/icon_foreground_padded.png').writeAsBytesSync(img.encodePng(canvas));
    print('Created padded foreground: assets/icon_foreground_padded.png');
  }
}
