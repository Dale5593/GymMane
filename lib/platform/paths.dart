// path_provider on Android/iOS; virtual folders on the web (PWA).
export 'paths_native.dart' if (dart.library.js_interop) 'paths_web.dart';
