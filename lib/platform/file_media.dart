// Show images/videos stored as app files: from disk on Android/iOS, from the
// in-browser file store on the web.
export 'file_media_native.dart' if (dart.library.js_interop) 'file_media_web.dart';
