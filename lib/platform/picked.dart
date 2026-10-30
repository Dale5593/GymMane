import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'io.dart';

/// A path the rest of the app can treat like a normal file path. In the web
/// app, picked files only exist as bytes, so they are parked in the
/// in-browser file store first.
Future<String?> pickedFilePath(PlatformFile f) async {
  if (!kIsWeb) return f.path;
  final bytes = f.bytes;
  if (bytes == null) return null;
  return _stash(f.name, bytes, f.extension);
}

Future<String> pickedImagePath(XFile x) async {
  if (!kIsWeb) return x.path;
  final bytes = await x.readAsBytes();
  return _stash(x.name, bytes, _extFromMime(x.mimeType));
}

int _seq = 0;

Future<String> _stash(String name, Uint8List bytes, String? hint) async {
  final dot = name.lastIndexOf('.');
  var ext = dot > 0 && dot < name.length - 1 ? name.substring(dot + 1).toLowerCase() : (hint ?? '');
  if (ext.isEmpty || ext.length > 5) ext = _sniff(bytes);
  final path = '/tmp/picked/${DateTime.now().microsecondsSinceEpoch}-${_seq++}.$ext';
  await File(path).writeAsBytes(bytes);
  return path;
}

String? _extFromMime(String? mime) => switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/heic' => 'heic',
      'video/mp4' => 'mp4',
      'video/quicktime' => 'mov',
      _ => null,
    };

String _sniff(Uint8List b) {
  bool at(int i, List<int> sig) {
    if (b.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (b[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (at(0, [0x47, 0x49, 0x46])) return 'gif';
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) return 'webp';
  if (at(4, [0x66, 0x74, 0x79, 0x70])) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (brand.startsWith('qt')) return 'mov';
    if (brand.startsWith('hei') || brand.startsWith('mif')) return 'heic';
    return 'mp4';
  }
  return 'jpg';
}
