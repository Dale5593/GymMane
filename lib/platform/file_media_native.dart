import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:video_player/video_player.dart';

ImageProvider fileImageProvider(String path) => FileImage(File(path));

VideoPlayerController fileVideoController(String path, {VideoPlayerOptions? videoPlayerOptions}) =>
    VideoPlayerController.file(File(path), videoPlayerOptions: videoPlayerOptions);
