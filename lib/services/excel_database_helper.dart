import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExcelDatabaseHelper {
  static final ExcelDatabaseHelper _instance = ExcelDatabaseHelper._internal();
  factory ExcelDatabaseHelper() => _instance;
  ExcelDatabaseHelper._internal();

  Future<String> get _excelFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    final year = DateTime.now().year;
    return '${directory.path}/expenses_$year.xlsx';
  }

  Future<Excel> _getOrCreateExcel() async {
    final file = File(await _excelFilePath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return Excel.decodeBytes(bytes);
    }
    return _createNewExcelFile();
  }

  Excel _createNewExcelFile() {
    final excel = Excel.createExcel();
    // Create 12 sheets for each month
    for (int month = 1; month <= 12; month++) {
      final sheetName = _getMonthName(month);
      final sheet = excel[sheetName];
      _initializeSheet(sheet);
    }
    return excel;
  }

  void _initializeSheet(Sheet sheet) {
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
  }

  Future<void> saveExcel(Excel excel) async {
    final file = File(await _excelFilePath);
    await file.writeAsBytes(excel.encode()!);
  }

  Future<int> insertExpense(Expense expense) async {
    final excel = await _getOrCreateExcel();
    final sheetName = _getMonthName(expense.date.month);
    final sheet = excel[sheetName];

    // Find the next empty row
    int nextRow = 1;
    while (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow)).value != null) {
      nextRow++;
    }

    // Calculate running total
    double runningTotal = 0;
    for (int i = 1; i < nextRow; i++) {
      final amount = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i)).value;
      if (amount != null) {
        runningTotal += double.parse(amount.toString());
      }
    }
    runningTotal += expense.amount;

    // Add expense data
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow))
      .value = TextCellValue(DateFormat('yyyy-MM-dd').format(expense.date));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: nextRow))
      .value = TextCellValue(expense.category);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: nextRow))
      .value = TextCellValue(expense.title);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: nextRow))
      .value = DoubleCellValue(expense.amount);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: nextRow))
      .value = DoubleCellValue(runningTotal);

    await saveExcel(excel);
    return nextRow; // Return the row number as ID
  }

  Future<List<Expense>> getExpenses() async {
    final excel = await _getOrCreateExcel();
    final expenses = <Expense>[];
    final year = DateTime.now().year;

    for (int month = 1; month <= 12; month++) {
      final sheetName = _getMonthName(month);
      final sheet = excel[sheetName];
      
      int row = 1;
      while (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value != null) {
        final dateStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value.toString();
        final category = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value.toString();
        final title = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value.toString();
        final amount = double.parse(sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value.toString());

        expenses.add(Expense(
          id: row,
          title: title,
          amount: amount,
          date: DateFormat('yyyy-MM-dd').parse(dateStr),
          category: category,
        ));
        row++;
      }
    }

    return expenses;
  }

  Future<List<Expense>> getExpensesByMonth(DateTime date) async {
    final excel = await _getOrCreateExcel();
    final sheetName = _getMonthName(date.month);
    final sheet = excel[sheetName];
    final expenses = <Expense>[];

    int row = 1;
    while (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value != null) {
      final dateStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value.toString();
      final category = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value.toString();
      final title = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value.toString();
      final amount = double.parse(sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value.toString());

      expenses.add(Expense(
        id: row,
        title: title,
        amount: amount,
        date: DateFormat('yyyy-MM-dd').parse(dateStr),
        category: category,
      ));
      row++;
    }

    return expenses;
  }

  Future<bool> deleteExpense(int id, DateTime date) async {
    final excel = await _getOrCreateExcel();
    final sheetName = _getMonthName(date.month);
    final sheet = excel[sheetName];

    // Shift all rows up to fill the gap
    int lastRow = id;
    while (sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: lastRow + 1)).value != null) {
      for (int col = 0; col < 4; col++) {
        final nextValue = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRow + 1)).value;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRow)).value = nextValue;
      }
      lastRow++;
    }

    // Clear the last row
    for (int col = 0; col < 5; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRow)).value = null;
    }

    // Recalculate running totals
    double runningTotal = 0;
    for (int row = 1; row < lastRow; row++) {
      final amount = double.parse(sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value.toString());
      runningTotal += amount;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(runningTotal);
    }

    await saveExcel(excel);
    return true;
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