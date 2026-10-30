import 'dart:js_interop';
import 'dart:typed_data';

import 'io_web.dart';

@JS('gmKeepAwake')
external void _keepAwake(JSBoolean on);

@JS('gmPlaySound')
external JSPromise<JSAny?> _playSound(JSString key, JSUint8Array? bytes, JSNumber volume);

@JS('gmShareFile')
external JSPromise<JSAny?> _shareFile(JSUint8Array bytes, JSString name, JSString mime, JSString? title);

@JS('gmBlobUrl')
external JSString _blobUrl(JSUint8Array bytes, JSString mime);

Future<void> initWebPlatform() => Vfs.init();

void webKeepAwake(bool on) {
  try {
    _keepAwake(on.toJS);
  } catch (_) {}
}

Future<void> webPlaySound(String key, Uint8List? bytes, {double volume = 1}) async {
  try {
    await _playSound(key.toJS, bytes?.toJS, volume.toJS).toDart;
  } catch (_) {}
}

Future<void> webShareBytes(Uint8List bytes, String name, String mime, {String? title}) async {
  await _shareFile(bytes.toJS, name.toJS, mime.toJS, title?.toJS).toDart;
}

final _urls = <String, String>{};

String webBlobUrlForPath(String path, String mime) {
  if (path.startsWith('blob:') || path.startsWith('http')) return path;
  final cached = _urls[path];
  if (cached != null) return cached;
  final bytes = Vfs.files[path] ?? Uint8List(0);
  return _urls[path] = _blobUrl(bytes.toJS, mime.toJS).toDart;
}

@JS('gmAudioDuration')
external JSPromise<JSNumber?> _audioDuration(JSUint8Array bytes);

Future<double?> webAudioDuration(Uint8List bytes) async {
  try {
    return (await _audioDuration(bytes.toJS).toDart)?.toDartDouble;
  } catch (_) {
    return null;
  }
}

@JS('gmSafeInsets')
external JSArray<JSNumber> _safeInsets();

/// Safe-area insets (top, right, bottom, left) in logical pixels, from CSS env().
List<double> webSafeInsets() {
  try {
    return [for (final n in _safeInsets().toDart) n.toDartDouble];
  } catch (_) {
    return const [0, 0, 0, 0];
  }
}
