import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Review'),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          if (provider.expenses.isEmpty) {
            return const Center(
              child: Text('No expenses to review'),
            );
          }

          // Group expenses by category
          final expensesByCategory = <String, List<Expense>>{};
          double totalExpenses = 0;

          for (var expense in provider.expenses) {
            expensesByCategory.putIfAbsent(expense.category, () => []);
            expensesByCategory[expense.category]!.add(expense);
            totalExpenses += expense.amount;
          }

          // Calculate category totals
          final categoryTotals = <String, double>{};
          for (var category in expensesByCategory.keys) {
            categoryTotals[category] = expensesByCategory[category]!
                .fold(0, (sum, expense) => sum + expense.amount);
          }

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Total Expenses',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                            .format(totalExpenses),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Category Distribution',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: categoryTotals.entries.map((entry) {
                          final percentage = (entry.value / totalExpenses) * 100;
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: _getCategoryColor(entry.key),
                              radius: 12,
                            ),
                            label: Text(
                              '${entry.key}: ${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: expensesByCategory.length,
                  itemBuilder: (context, index) {
                    final category = expensesByCategory.keys.elementAt(index);
                    final expenses = expensesByCategory[category]!;
                    final categoryTotal = categoryTotals[category]!;
                    final percentage = (categoryTotal / totalExpenses) * 100;

                    return ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: _getCategoryColor(category),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(category),
                      subtitle: Text(
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                            .format(categoryTotal),
                      ),
                      children: expenses.map((expense) => ListTile(
                        title: Text(expense.title),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(expense.date),
                        ),
                        trailing: Text(
                          NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                              .format(expense.amount),
                        ),
                      )).toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Food': Colors.green,
      'Transport': Colors.blue,
      'Shopping': Colors.red,
      'Entertainment': Colors.orange,
      'Bills': Colors.purple,
      'Events': Colors.pink,
      'Other': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }
} 