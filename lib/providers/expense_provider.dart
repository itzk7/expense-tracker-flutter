import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';
import '../services/backup_service.dart';

class ExpenseProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final BackupService _backupService = BackupService();
  List<Expense> _expenses = [];

  List<Expense> get expenses => _expenses;

  ExpenseProvider() {
    // Initialization without voice handlers
  }

  Future<void> loadExpenses() async {
    try {
      debugPrint('Loading expenses...');
      _expenses = await _db.getExpenses();
      debugPrint('Loaded ${_expenses.length} expenses');
      notifyListeners();
    
      if (!kIsWeb) {
        // Only create backup for mobile platforms
        await _backupService.createDailyBackup();
      }
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      _expenses = [];
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      debugPrint('Adding expense: ${expense.title}');
      final id = await _db.insertExpense(expense);
      final newExpense = expense.copyWith(id: id);
      _expenses.insert(0, newExpense); // Add to the beginning of the list
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding expense: $e');
    }
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    try {
      await _db.deleteExpense(id);
      _expenses.removeWhere((expense) => expense.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting expense: $e');
    }
  }

  Future<List<Expense>> getExpensesByMonth(DateTime date) async {
    return await _db.getExpensesByMonth(date);
  }

  Future<double> getTotalExpenses([DateTime? startDate, DateTime? endDate]) async {
    return await _db.getTotalExpenses(startDate, endDate);
  }

  Future<Map<String, double>> getCategoryTotals([DateTime? startDate, DateTime? endDate]) async {
    return await _db.getCategoryTotals(startDate, endDate);
  }

  Future<void> forceBackup() async {
    await _backupService.createDailyBackup();
  }

  Future<String> getBackupPath() async {
    return await _backupService.getBackupPath();
  }

  Future<void> openBackupFolder() async {
    await _backupService.openBackupFolder();
  }

  String? getLastBackupPath() {
    return _backupService.lastBackupPath;
  }

  Future<List<String>> getBackupFiles() async {
    return await _backupService.getBackupFiles();
  }
} 