import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'backup_service_interface.dart';
import 'package:flutter/foundation.dart';

class MobileBackupHelper implements PlatformBackupHelper {
  @override
  Future<void> saveBackup(Excel excel, String fileName) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint('Failed to get external storage directory');
        return;
      }

      final backupDir = Directory('${directory.path}/expense_tracker_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);
      debugPrint('Backup saved to: ${file.path}');
    } catch (e) {
      debugPrint('Error saving backup: $e');
      rethrow;
    }
  }
}

PlatformBackupHelper createPlatformBackupHelper() => MobileBackupHelper(); 