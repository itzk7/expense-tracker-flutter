import 'dart:html' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'backup_service_interface.dart';

class WebBackupHelper implements PlatformBackupHelper {
  @override
  Future<void> saveBackup(Excel excel, String fileName) async {
    final bytes = excel.encode();
    if (bytes != null) {
      final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement()
        ..href = url
        ..style.display = 'none'
        ..download = fileName;
        
      html.document.body?.children.add(anchor);
      anchor.click();
      
      await Future.delayed(const Duration(milliseconds: 100));
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    }
  }
}

PlatformBackupHelper createPlatformBackupHelper() => WebBackupHelper(); 