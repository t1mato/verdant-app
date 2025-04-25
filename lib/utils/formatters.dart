import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// Common date formatters
class DateFormatters {
  static final shortDate = DateFormat('MMM d');
  static final monthYear = DateFormat('MMMM yyyy');
  static final fullDate = DateFormat('MMMM d, yyyy');
  static final dayMonth = DateFormat('d MMM');
  static final weekday = DateFormat('EEEE');
  static final time = DateFormat('h:mm a');
  static final dateTime = DateFormat('MMM d, h:mm a');
}

/// Common currency formatters
class CurrencyFormatters {
  static final standard = NumberFormat.currency(symbol: '\$');
  static final compact = NumberFormat.compactCurrency(symbol: '\$');
  static final noSymbol = NumberFormat.currency(symbol: '');
  static final noDecimals = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  /// Format a currency value with color based on positive/negative
  static Widget coloredAmount(double amount, {TextStyle? style, bool showPlus = false}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    return Text(
      '${isNegative ? "-" : (showPlus && amount > 0 ? "+" : "")}${standard.format(absAmount)}',
      style: (style ?? const TextStyle()).copyWith(
        color: isNegative ? Colors.red : Colors.green,
      ),
    );
  }

  /// Format a currency value with color based on positive/negative for expenses
  static Widget coloredExpense(double amount, {TextStyle? style}) {
    return Text(
      '-${standard.format(amount)}',
      style: (style ?? const TextStyle()).copyWith(
        color: Colors.red,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Percentage formatters and utilities
class PercentFormatters {
  static final standard = NumberFormat.percentPattern();
  static final oneDecimal = NumberFormat.percentPattern()..maximumFractionDigits = 1;
  static final noDecimal = NumberFormat.percentPattern()..maximumFractionDigits = 0;

  /// Get color based on percentage value (green for high, red for low)
  static Color getProgressColor(double value) {
    if (value > 0.7) return Colors.green;
    if (value > 0.4) return Colors.orange;
    return Colors.red;
  }

  /// Get color based on percentage value (red for high, green for low)
  /// Used for expense tracking where higher percentages are worse
  static Color getExpenseColor(double value) {
    if (value < 0.3) return Colors.green;
    if (value < 0.6) return Colors.orange;
    return Colors.red;
  }
}

/// String extension methods for common operations
extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }
}

/// DateTime extension methods for common operations
extension DateTimeExtensions on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  DateTime startOfDay() {
    return DateTime(year, month, day);
  }

  DateTime endOfDay() {
    return DateTime(year, month, day, 23, 59, 59);
  }

  DateTime startOfWeek() {
    // Start of week (Monday)
    return subtract(Duration(days: weekday - 1)).startOfDay();
  }

  DateTime startOfMonth() {
    return DateTime(year, month, 1);
  }

  DateTime endOfMonth() {
    return DateTime(year, month + 1, 0, 23, 59, 59);
  }

  bool isToday() {
    final now = DateTime.now();
    return isSameDay(now);
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(yesterday);
  }

  String toFriendlyDate() {
    if (isToday()) return 'Today';
    if (isYesterday()) return 'Yesterday';
    return DateFormatters.shortDate.format(this);
  }
}