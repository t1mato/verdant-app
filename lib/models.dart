  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';

  /// Represents a spending category with visual styling
  class CategoryInfo {
    final String name;
    final IconData icon;
    final Color color;
    final double? limit;

    const CategoryInfo(this.name, this.icon, this.color, {this.limit});
  }

  /// Represents a transaction item with category info
  class TransactionItem {
    final String id;
    final String name;
    final double amount;
    final CategoryInfo category;
    final DateTime date;

    TransactionItem({
      required this.id,
      required this.name,
      required this.amount,
      required this.category,
      required this.date,
    });

    Map<String, dynamic> toMap() {
      return {
        'name': name,
        'amount': amount,
        'category': category.name,
        'timestamp': Timestamp.fromDate(date),
      };
    }

    static TransactionItem fromFirestore(
        DocumentSnapshot doc, List<CategoryInfo> availableCategories) {
      final data = doc.data() as Map<String, dynamic>;
      final categoryName = data['category'] as String? ?? 'Other';
      final categoryInfo = availableCategories.firstWhere(
            (cat) => cat.name == categoryName,
        orElse: () => availableCategories.firstWhere(
              (cat) => cat.name == 'Other',
          orElse: () => const CategoryInfo('Other', Icons.more_horiz, Colors.grey),
        ),
      );

      return TransactionItem(
        id: doc.id,
        name: data['name'] ?? '',
        amount: (data['amount'] as num).toDouble(),
        category: categoryInfo,
        date: (data['timestamp'] as Timestamp).toDate(),
      );
    }
  }

  /// Standardized list of categories for the app
  const List<CategoryInfo> availableCategories = [
    CategoryInfo("Food", Icons.restaurant, Colors.orange),
    CategoryInfo("Bills", Icons.receipt, Colors.blue),
    CategoryInfo("Entertainment", Icons.movie, Colors.purple),
    CategoryInfo("Transport", Icons.directions_car, Colors.teal),
    CategoryInfo("Shopping", Icons.shopping_bag, Colors.pink),
    CategoryInfo("Health", Icons.favorite, Colors.red),
    CategoryInfo("Groceries", Icons.local_grocery_store, Colors.green),
    CategoryInfo("Other", Icons.more_horiz, Colors.grey),
  ];

  /// DateRange model for reporting and filtering
  class DateRange {
    final DateTime startDate;
    final DateTime endDate;
    final String label;

    DateRange({
      required this.startDate,
      required this.endDate,
      required this.label,
    });

    static DateRange forMonth(DateTime month) {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      return DateRange(
        startDate: firstDay,
        endDate: lastDay,
        label: '${month.year}-${month.month}',
      );
    }

    static DateRange forWeek(DateTime day) {
      // Find the start of the week (Monday)
      final monday = day.subtract(Duration(days: day.weekday - 1));
      final startDate = DateTime(monday.year, monday.month, monday.day);
      final endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      return DateRange(
        startDate: startDate,
        endDate: endDate,
        label: 'Week of ${startDate.day}/${startDate.month}',
      );
    }

    static DateRange forToday() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      return DateRange(
        startDate: today,
        endDate: endOfDay,
        label: 'Today',
      );
    }
  }

  /// User preferences model
  class UserPreferences {
    final double? totalBudget;
    final bool isDarkMode;
    final bool isMonthlyBudget;

    UserPreferences({
      this.totalBudget,
      this.isDarkMode = false,
      this.isMonthlyBudget = true,
    });

    Map<String, dynamic> toMap() {
      return {
        'totalBudget': totalBudget,
        'darkMode': isDarkMode,
        'isMonthly': isMonthlyBudget,
      };
    }

    static UserPreferences fromFirestore(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      return UserPreferences(
        totalBudget: data['totalBudget'] != null ? (data['totalBudget'] as num).toDouble() : null,
        isDarkMode: data['darkMode'] ?? false,
        isMonthlyBudget: data['isMonthly'] ?? true,
      );
    }

    UserPreferences copyWith({
      double? totalBudget,
      bool? isDarkMode,
      bool? isMonthlyBudget,
    }) {
      return UserPreferences(
        totalBudget: totalBudget ?? this.totalBudget,
        isDarkMode: isDarkMode ?? this.isDarkMode,
        isMonthlyBudget: isMonthlyBudget ?? this.isMonthlyBudget,
      );
    }
  }