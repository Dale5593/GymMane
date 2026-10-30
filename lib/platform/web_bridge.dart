// Browser-only helpers (wake lock, Web Audio, share sheet). No-ops on Android/iOS.
export 'web_bridge_stub.dart' if (dart.library.js_interop) 'web_bridge_web.dart';
