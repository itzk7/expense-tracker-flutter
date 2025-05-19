import 'package:excel/excel.dart';

abstract class PlatformBackupHelper {
  Future<void> saveBackup(Excel excel, String fileName);
} 