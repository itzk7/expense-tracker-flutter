import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static SharedPreferences? _prefs;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<dynamic> get database async {
    if (kIsWeb) {
      // Use SharedPreferences for web
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs;
    } else {
      // Use SQLite for mobile
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
    }
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expenses.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    if (kIsWeb) {
      // Web implementation using SharedPreferences
      final prefs = db as SharedPreferences;
      final expenses = await getExpenses();
      final id = DateTime.now().millisecondsSinceEpoch;
      expenses.add(expense.copyWith(id: id));
      await prefs.setString('expenses', expensesToJson(expenses));
      return id;
    } else {
      // Mobile implementation using SQLite
      return await (db as Database).insert('expenses', expense.toMap());
    }
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    if (kIsWeb) {
      // Web implementation using SharedPreferences
      final prefs = db as SharedPreferences;
      final expensesJson = prefs.getString('expenses') ?? '[]';
      return expensesFromJson(expensesJson);
    } else {
      // Mobile implementation using SQLite
      final List<Map<String, dynamic>> maps = await (db as Database).query(
      'expenses',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
    }
  }

  Future<List<Expense>> getExpensesByMonth(DateTime date) async {
    Database db = await database;
    final startDate = DateTime(date.year, date.month, 1);
    final endDate = DateTime(date.year, date.month + 1, 0);

    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date ASC',
    );

    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Expense>> getExpensesByDateRange(DateTime startDate, DateTime endDate) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date ASC',
    );

    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<int> updateExpense(Expense expense) async {
    Database db = await database;
    return await db.update(
      'expenses',
      {
        ...expense.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    if (kIsWeb) {
      // Web implementation using SharedPreferences
      final prefs = db as SharedPreferences;
      final expenses = await getExpenses();
      expenses.removeWhere((e) => e.id == id);
      await prefs.setString('expenses', expensesToJson(expenses));
      return 1;
    } else {
      // Mobile implementation using SQLite
      return await (db as Database).delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    }
  }

  Future<Map<String, double>> getCategoryTotals(DateTime? startDate, DateTime? endDate) async {
    Database db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM expenses
      $whereClause
      GROUP BY category
    ''', whereArgs);

    return Map.fromEntries(
      result.map((row) => MapEntry(row['category'] as String, row['total'] as double))
    );
  }

  Future<double> getTotalExpenses(DateTime? startDate, DateTime? endDate) async {
    Database db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE date BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM expenses
      $whereClause
    ''', whereArgs);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Helper methods for JSON conversion
  String expensesToJson(List<Expense> expenses) {
    return jsonEncode(expenses.map((e) => e.toMap()).toList());
  }

  List<Expense> expensesFromJson(String json) {
    if (json == '[]') return [];
    final List<dynamic> list = jsonDecode(json);
    return list.map((e) => Expense.fromMap(Map<String, dynamic>.from(e))).toList();
  }
} 