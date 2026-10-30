// A tiny stand-in for the parts of dart:io GymMane uses, for the web build.
//
// Files live in memory and are mirrored to IndexedDB (see web/gm_bridge.js),
// except for anything under /tmp, which only lasts for the session. The whole
// store is loaded once at start-up so the synchronous calls the app relies on
// (existsSync, listSync) keep working.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibEncoder;

@JS('gmVfsLoadAll')
external JSPromise<JSArray<JSAny?>> _loadAll();

@JS('gmVfsPut')
external JSPromise<JSAny?> _put(JSString path, JSUint8Array bytes);

@JS('gmVfsDelete')
external JSPromise<JSAny?> _delete(JSString path);

@JS('gmFetchBytes')
external JSPromise<JSUint8Array> _fetchBytes(JSString url);

class Vfs {
  Vfs._();

  static final Map<String, Uint8List> files = {};
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final all = (await _loadAll().toDart).toDart;
      for (var i = 0; i + 1 < all.length; i += 2) {
        final key = (all[i] as JSString).toDart;
        final bytes = (all[i + 1] as JSUint8Array).toDart;
        files[key] = bytes;
      }
    } catch (_) {}
  }

  static bool _persist(String path) => !path.startsWith('/tmp/');

  static Future<void> write(String path, Uint8List bytes) async {
    files[path] = bytes;
    if (!_persist(path)) return;
    try {
      await _put(path.toJS, bytes.toJS).toDart;
    } catch (_) {}
  }

  static Future<void> remove(String path) async {
    files.remove(path);
    if (!_persist(path)) return;
    try {
      await _delete(path.toJS).toDart;
    } catch (_) {}
  }

  static bool isRemote(String path) =>
      path.startsWith('blob:') || path.startsWith('http:') || path.startsWith('https:') || path.startsWith('data:');

  static Future<Uint8List> fetch(String url) async => (await _fetchBytes(url.toJS).toDart).toDart;
}

class Platform {
  Platform._();

  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isMacOS = false;
  static const bool isWindows = false;
  static const bool isLinux = false;
  static const bool isFuchsia = false;
  static const String operatingSystem = 'web';
  static const String pathSeparator = '/';
  static const Map<String, String> environment = {};
  static String get localeName => 'en';
  static int get numberOfProcessors => 1;
}

class IOException implements Exception {
  const IOException();
}

class FileSystemException extends IOException {
  const FileSystemException([this.message = '', this.path = '']);

  final String message;
  final String? path;

  @override
  String toString() => 'FileSystemException: $message, path = \'$path\'';
}

enum FileMode { read, write, append, writeOnly, writeOnlyAppend }

String _clean(String path) => path.length > 1 && path.endsWith('/') ? path.substring(0, path.length - 1) : path;

abstract class FileSystemEntity {
  FileSystemEntity(String path) : path = _clean(path);

  final String path;

  Uri get uri => Uri(path: path);

  Directory get parent {
    final i = path.lastIndexOf('/');
    return Directory(i <= 0 ? '/' : path.substring(0, i));
  }

  Future<bool> exists();

  bool existsSync();

  Future<FileSystemEntity> delete({bool recursive = false});

  void deleteSync({bool recursive = false});

  @override
  String toString() => "${runtimeType.toString()}: '$path'";
}

class File extends FileSystemEntity {
  File(super.path);

  bool get _remote => Vfs.isRemote(path);

  @override
  Future<bool> exists() async => _remote || Vfs.files.containsKey(path);

  @override
  bool existsSync() => Vfs.files.containsKey(path);

  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    if (!existsSync()) await Vfs.write(path, Uint8List(0));
    return this;
  }

  void createSync({bool recursive = false, bool exclusive = false}) {
    if (!existsSync()) unawaited(Vfs.write(path, Uint8List(0)));
  }

  Future<Uint8List> readAsBytes() async {
    if (_remote) return Vfs.fetch(path);
    return readAsBytesSync();
  }

  Uint8List readAsBytesSync() {
    final bytes = Vfs.files[path];
    if (bytes == null) throw FileSystemException('Cannot open file', path);
    return bytes;
  }

  Future<String> readAsString({Encoding encoding = utf8}) async => encoding.decode(await readAsBytes());

  String readAsStringSync({Encoding encoding = utf8}) => encoding.decode(readAsBytesSync());

  Future<List<String>> readAsLines({Encoding encoding = utf8}) async =>
      const LineSplitter().convert(await readAsString(encoding: encoding));

  Uint8List _merge(List<int> bytes, FileMode mode) {
    final add = bytes is Uint8List ? Uint8List.fromList(bytes) : Uint8List.fromList(bytes);
    if (mode != FileMode.append && mode != FileMode.writeOnlyAppend) return add;
    final old = Vfs.files[path];
    if (old == null || old.isEmpty) return add;
    return Uint8List(old.length + add.length)
      ..setRange(0, old.length, old)
      ..setRange(old.length, old.length + add.length, add);
  }

  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) async {
    await Vfs.write(path, _merge(bytes, mode));
    return this;
  }

  void writeAsBytesSync(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) {
    unawaited(Vfs.write(path, _merge(bytes, mode)));
  }

  Future<File> writeAsString(String contents,
          {FileMode mode = FileMode.write, Encoding encoding = utf8, bool flush = false}) =>
      writeAsBytes(encoding.encode(contents), mode: mode, flush: flush);

  void writeAsStringSync(String contents,
          {FileMode mode = FileMode.write, Encoding encoding = utf8, bool flush = false}) =>
      writeAsBytesSync(encoding.encode(contents), mode: mode, flush: flush);

  Future<File> copy(String newPath) async {
    final bytes = await readAsBytes();
    await Vfs.write(_clean(newPath), bytes);
    return File(newPath);
  }

  Future<File> rename(String newPath) async {
    final copied = await copy(newPath);
    if (!_remote) await Vfs.remove(path);
    return copied;
  }

  Future<int> length() async => (await readAsBytes()).length;

  int lengthSync() => readAsBytesSync().length;

  Future<DateTime> lastModified() async => DateTime.now();

  DateTime lastModifiedSync() => DateTime.now();

  @override
  Future<File> delete({bool recursive = false}) async {
    await Vfs.remove(path);
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) => unawaited(Vfs.remove(path));
}

class Directory extends FileSystemEntity {
  Directory(super.path);

  static Directory get systemTemp => Directory('/tmp');

  String get _prefix => path == '/' ? '/' : '$path/';

  @override
  Future<bool> exists() async => true;

  @override
  bool existsSync() => true;

  Future<Directory> create({bool recursive = false}) async => this;

  void createSync({bool recursive = false}) {}

  Future<Directory> createTemp([String? prefix]) async =>
      Directory('$path/${prefix ?? ''}${DateTime.now().microsecondsSinceEpoch}');

  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) {
    final prefix = _prefix;
    final out = <FileSystemEntity>[];
    final dirs = <String>{};
    for (final key in Vfs.files.keys.toList()) {
      if (!key.startsWith(prefix)) continue;
      final rest = key.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash < 0 || recursive) {
        out.add(File(key));
      }
      if (slash >= 0 && !recursive) dirs.add('$prefix${rest.substring(0, slash)}');
    }
    return [...out, for (final d in dirs) Directory(d)];
  }

  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) =>
      Stream.fromIterable(listSync(recursive: recursive, followLinks: followLinks));

  @override
  Future<Directory> delete({bool recursive = false}) async {
    for (final key in Vfs.files.keys.where((k) => k.startsWith(_prefix)).toList()) {
      await Vfs.remove(key);
    }
    return this;
  }

  @override
  void deleteSync({bool recursive = false}) => unawaited(delete(recursive: recursive));
}

class _ZLib {
  const _ZLib();

  List<int> encode(List<int> input) => const ZLibEncoder().encodeBytes(input);
}

const zlib = _ZLib();
