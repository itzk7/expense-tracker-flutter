import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import 'database_helper.dart';
import 'package:flutter/foundation.dart';
import 'backup_service_interface.dart';

// Platform-specific implementation
import 'backup_service_mobile.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  final DatabaseHelper _db = DatabaseHelper();
  String? _lastBackupPath;
  final PlatformBackupHelper _platformHelper = createPlatformBackupHelper();
  
  factory BackupService() => _instance;
  BackupService._internal();

  // Getter for the last backup path
  String? get lastBackupPath => _lastBackupPath;

  Future<String> get _backupDirectory async {
    if (kIsWeb) {
      return 'Web Storage';
    }
    
    final directory = await getApplicationDocumentsDirectory();
    debugPrint('Application Documents Directory: ${directory.path}');
    
    final backupDir = Directory('${directory.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    final absolutePath = backupDir.absolute.path;
    debugPrint('Absolute Backup Directory Path: $absolutePath');
    return absolutePath;
  }

  Future<String> getBackupPath() async {
    return await _backupDirectory;
  }

  Future<void> openBackupFolder() async {
    final path = await _backupDirectory;
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  Future<bool> shouldCreateBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('lastBackupDate');
    
    if (lastBackup == null) return true;
    
    final lastBackupDate = DateTime.parse(lastBackup);
    final now = DateTime.now();
    
    return lastBackupDate.year != now.year ||
           lastBackupDate.month != now.month ||
           lastBackupDate.day != now.day;
  }

  Future<String> createDailyBackup() async {
    if (!await shouldCreateBackup()) return 'No backup needed today.';

    try {
      final now = DateTime.now();
      final expenses = await _db.getExpenses();
      debugPrint('Creating backup with ${expenses.length} expenses');
      
      final excel = await _createExcelBackup(expenses);
      final fileName = 'expense_backup_${DateFormat('yyyy_MM_dd').format(now)}.xlsx';
      
      await _platformHelper.saveBackup(excel, fileName);

      // Return a success message instead of showing a Snackbar
      return 'Backup saved to: $fileName';
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return 'Error creating backup: $e';
    }
  }

  Future<List<String>> getBackupFiles() async {
    if (kIsWeb) return [];
    
    final backupPath = await _backupDirectory;
    final directory = Directory(backupPath);
    if (!await directory.exists()) return [];
    
    final files = await directory.list().toList();
    return files
        .whereType<File>()
        .where((file) => file.path.endsWith('.xlsx'))
        .map((file) => file.absolute.path)
        .toList();
  }

  Future<Excel> _createExcelBackup(List<Expense> expenses) async {
    // Create a new Excel file
    final excel = Excel.createExcel();
    
    // Remove default Sheet1
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Create Summary sheet
    final summarySheet = excel['Summary'];
    _initializeSummarySheet(summarySheet);

    // Process expenses to get totals
    final yearlyExpenses = _groupExpensesByYear(expenses);
    Map<String, double> categoryTotals = {};
    double grandTotal = 0.0;

    // Calculate totals first
    for (var yearEntry in yearlyExpenses.entries) {
      final yearlyExpenses = yearEntry.value;
      for (var expense in yearlyExpenses) {
        categoryTotals.update(
          expense.category, 
          (value) => value + expense.amount,
          ifAbsent: () => expense.amount
        );
        grandTotal += expense.amount;
      }
    }

    // Fill in the Summary sheet with pie chart visualization
    int rowIndex = 1;
    
    // Add category totals
    for (var entry in categoryTotals.entries) {
      final percentage = (entry.value / grandTotal * 100).toStringAsFixed(1);
      
      summarySheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        TextCellValue(entry.key)
      );
      summarySheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        DoubleCellValue(entry.value)
      );
      summarySheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
        TextCellValue('$percentage%')
      );
      rowIndex++;
    }

    // Add Total Row
    summarySheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex + 1),
      TextCellValue('Total')
    );
    summarySheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex + 1),
      DoubleCellValue(grandTotal)
    );

    // Add pie chart visualization header
    final chartStartRow = rowIndex + 3;
    summarySheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: chartStartRow),
      TextCellValue('Expense Distribution')
    );

    // Add pie chart data
    rowIndex = chartStartRow + 2;
    for (var entry in categoryTotals.entries) {
      final percentage = entry.value / grandTotal;
      final pieSegment = '${entry.key}: ${(percentage * 100).toStringAsFixed(1)}%';
      
      summarySheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        TextCellValue(pieSegment)
      );
      rowIndex++;
    }

    // Create monthly sheets and populate data
    for (var yearEntry in yearlyExpenses.entries) {
      final year = yearEntry.key;
      final monthlyExpenses = _groupExpensesByMonth(yearEntry.value);
      
      for (var monthEntry in monthlyExpenses.entries) {
        final month = monthEntry.key;
        final expenses = monthEntry.value;
        final monthName = DateFormat('MMMM').format(DateTime(year, month));
        final sheetName = '${monthName}_$year';
        
        final sheet = excel[sheetName];
        _initializeSheet(sheet);
        
        // Add expenses to sheet
        var rowIndex = 1;
        double monthlyTotal = 0.0;
        
        for (var expense in expenses) {
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            TextCellValue(DateFormat('yyyy-MM-dd').format(expense.date))
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            TextCellValue(expense.category)
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            TextCellValue(expense.title)
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            DoubleCellValue(expense.amount)
          );
          
          monthlyTotal += expense.amount;
          rowIndex++;
        }
        
        // Add monthly total
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex + 1),
          DoubleCellValue(monthlyTotal)
        );
      }
    }

    return excel;
  }

  void _initializeSheet(Sheet sheet) {
    final headers = ['Date', 'Category', 'Description', 'Amount'];
    
    // Add headers
    for (var i = 0; i < headers.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        TextCellValue(headers[i])
      );
    }
  }

  void _initializeSummarySheet(Sheet sheet) {
    final headers = ['Category', 'Amount', 'Percentage'];
    
    // Add headers
    for (var i = 0; i < headers.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        TextCellValue(headers[i])
      );
    }
  }

  Future<void> _cleanOldBackups() async {
    final backupPath = await _backupDirectory;
    final directory = Directory(backupPath);
    final files = await directory.list().toList();
    
    if (files.length <= 7) return;

    // Sort files by creation date
    files.sort((a, b) => File(b.path).lastModifiedSync()
        .compareTo(File(a.path).lastModifiedSync()));

    // Delete old files
    for (var i = 7; i < files.length; i++) {
      await File(files[i].path).delete();
    }
  }

  Map<int, List<Expense>> _groupExpensesByYear(List<Expense> expenses) {
    final map = <int, List<Expense>>{};
    for (var expense in expenses) {
      final year = expense.date.year;
      map.putIfAbsent(year, () => []).add(expense);
    }
    return map;
  }

  Map<int, List<Expense>> _groupExpensesByMonth(List<Expense> expenses) {
    final map = <int, List<Expense>>{};
    for (var expense in expenses) {
      final month = expense.date.month;
      map.putIfAbsent(month, () => []).add(expense);
    }
    return map;
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }

  String _getCategoryColor(String category) {
    final colors = {
      'Food': '008000',      // Green
      'Transport': '0000FF', // Blue
      'Shopping': 'FF0000',  // Red
      'Entertainment': 'FFA500', // Orange
      'Bills': '800080',     // Purple
      'Events': 'FF69B4',    // Pink
      'Other': '808080',     // Gray
    };
    return colors[category] ?? '000000';
  }

  String _createPieSegment(double start, double percentage) {
    final segments = ['○', '◔', '◑', '◕', '●'];
    final index = (percentage * segments.length).floor().clamp(0, segments.length - 1);
    return segments[index];
  }

  Future<String> saveBackup(Excel excel, String fileName) async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      final backupDir = Directory('${directory?.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);
      
      // Return a success message instead of showing a Snackbar
      return 'Backup saved to: ${file.path}';
    }
    return 'Backup not saved.';
  }
} 