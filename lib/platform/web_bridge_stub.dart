import 'dart:typed_data';

Future<void> initWebPlatform() async {}

void webKeepAwake(bool on) {}

Future<void> webPlaySound(String key, Uint8List? bytes, {double volume = 1}) async {}

Future<void> webShareBytes(Uint8List bytes, String name, String mime, {String? title}) async {}

String webBlobUrlForPath(String path, String mime) => path;

Future<double?> webAudioDuration(Uint8List bytes) async => null;

List<double> webSafeInsets() => const [0, 0, 0, 0];
