import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void configureDatabase() {
  if (Platform.isAndroid) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
