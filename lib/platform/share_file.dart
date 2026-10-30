import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'io.dart';
import 'web_bridge.dart';

/// Shares a file the app has just written. On Android/iOS this is the normal
/// share sheet; in the web app it opens the browser share sheet (or downloads
/// the file when sharing files isn't available).
Future<void> shareFile(String path, {String? mimeType, String? subject, String? text}) async {
  if (kIsWeb) {
    final bytes = await File(path).readAsBytes();
    final name = path.split('/').last;
    await webShareBytes(bytes, name, mimeType ?? _mimeOf(name), title: subject);
    return;
  }
  await SharePlus.instance.share(ShareParams(
    files: [XFile(path, mimeType: mimeType)],
    subject: subject,
    text: text,
  ));
}

String _mimeOf(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'pdf' => 'application/pdf',
    'json' => 'application/json',
    'csv' => 'text/csv',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}
