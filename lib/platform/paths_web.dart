import 'io_web.dart';

Future<Directory> getApplicationDocumentsDirectory() async => Directory('/docs');

Future<Directory> getApplicationSupportDirectory() async => Directory('/support');

Future<Directory> getTemporaryDirectory() async => Directory('/tmp');
