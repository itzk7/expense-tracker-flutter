import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import '../models/expense.dart';
import 'google_http_client.dart';

class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  Future<void> syncToGoogleDrive(List<Expense> expenses) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null) {
        throw Exception('Failed to obtain access token.');
      }

      final client = GoogleHttpClient(accessToken);

      final driveApi = drive.DriveApi(client);

      // Create Excel file
      final excel = Excel.createExcel();
      final yearlySheets = _groupExpensesByYear(expenses);

      for (var yearEntry in yearlySheets.entries) {
        final year = yearEntry.key;
        final yearlyExpenses = yearEntry.value;
        final monthlySheets = _groupExpensesByMonth(yearlyExpenses);

        for (var monthEntry in monthlySheets.entries) {
          final month = monthEntry.key;
          final monthlyExpenses = monthEntry.value;
          final sheetName = '${_getMonthName(month)}_$year';

          final sheet = excel[sheetName];
          
          // Add headers
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
            ..value = TextCellValue('Date')
            ..cellStyle = CellStyle(
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
            ..value = TextCellValue('Category')
            ..cellStyle = CellStyle(
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
            ..value = TextCellValue('Description')
            ..cellStyle = CellStyle(
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
            ..value = TextCellValue('Amount')
            ..cellStyle = CellStyle(
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
            ..value = TextCellValue('Running Total')
            ..cellStyle = CellStyle(
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );

          double runningTotal = 0;
          for (var i = 0; i < monthlyExpenses.length; i++) {
            final expense = monthlyExpenses[i];
            runningTotal += expense.amount;

            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
              .value = TextCellValue(expense.date.toString().split(' ')[0]);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
              .value = TextCellValue(expense.category);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
              .value = TextCellValue(expense.title);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
              .value = DoubleCellValue(expense.amount);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1))
              .value = DoubleCellValue(runningTotal);
          }
        }
      }

      // Save Excel file locally
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/expenses.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      // Upload to Google Drive
      var driveFile = drive.File()
        ..name = 'expenses.xlsx'
        ..mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(
          file.openRead(),
          file.lengthSync(),
        ),
      );

      // Clean up temporary file
      await file.delete();
    } catch (e) {
      print('Error syncing to Google Drive: $e');
      rethrow;
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
} 