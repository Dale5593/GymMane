import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/web_bridge.dart';

const _channel = MethodChannel('gymmane/gallery');

Future<bool> saveImageToGallery(Uint8List png, String name) async {
  if (kIsWeb) {
    // In the web app, the share sheet has "Save Image" (iOS) or the file downloads.
    try {
      await webShareBytes(png, name, 'image/png');
      return true;
    } catch (_) {
      return false;
    }
  }
  try {
    final ok = await _channel.invokeMethod<bool>('savePng', {'bytes': png, 'name': name});
    return ok ?? false;
  } catch (_) {
    return false;
  }
}
