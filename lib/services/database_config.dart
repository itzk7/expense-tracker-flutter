import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> initializeDatabase() async {
  if (kIsWeb) {
    // Initialize for web
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isAndroid || Platform.isIOS) {
    // Use default sqflite implementation for mobile platforms
    // No need to set databaseFactory as it uses the default one
  } else {
    // Initialize FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
} 