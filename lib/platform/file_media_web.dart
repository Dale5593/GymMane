import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:video_player/video_player.dart';

import 'io_web.dart';
import 'web_bridge_web.dart';

final _empty = Uint8List(0);

ImageProvider fileImageProvider(String path) {
  if (Vfs.isRemote(path)) return NetworkImage(path);
  return MemoryImage(Vfs.files[path] ?? _empty);
}

String _videoMime(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'm4v' => 'video/x-m4v',
    '3gp' => 'video/3gpp',
    _ => 'video/mp4',
  };
}

VideoPlayerController fileVideoController(String path, {VideoPlayerOptions? videoPlayerOptions}) =>
    VideoPlayerController.networkUrl(Uri.parse(webBlobUrlForPath(path, _videoMime(path))),
        videoPlayerOptions: videoPlayerOptions);
