{{flutter_js}}
{{flutter_build_config}}

// Offline caching is handled by our own sw.js (registered in index.html),
// so Flutter's service worker is not used.
_flutter.loader.load();
