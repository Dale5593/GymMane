// dart:io on Android/iOS; a small in-browser file system on the web (PWA).
export 'io_native.dart' if (dart.library.js_interop) 'io_web.dart';
