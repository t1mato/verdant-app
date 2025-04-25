import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/database_service.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({Key? key}) : super(key: key);

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  bool isLoading = true;
  List<TransactionItem> transactions = [];
  Map<String, double> categoryTotals = {};
  final currencyFormat = NumberFormat.currency(symbol: '\$');

  // Summary metrics
  double totalSpent = 0;
  double todaySpent = 0;
  double currentWeekSpent = 0;
  int streak = 0;
  double? totalBudget;
  double currentBalance = 0;

  // Date formatting
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final startOfWeek = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  final DateTime selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      // Load user preferences
      final userPrefs = await dbService.getUserPreferences();
      totalBudget = userPrefs.totalBudget;

      // Get transactions for current month
      final dateRange = DateRange.forMonth(selectedMonth);
      final transactionsList = await dbService.getTransactionsStream(dateRange).first;

      // Process transactions
      _processTransactions(transactionsList);
    } catch (e) {
      debugPrint('Error loading summary data: $e');
      setState(() => isLoading = false);
    }
  }

  void _processTransactions(List<TransactionItem> transactionsList) {
    Map<String, double> catTotals = {};
    double spent = 0.0;
    double todayAmount = 0.0;
    double weekAmount = 0.0;
    final now = DateTime.now();

    // Process transactions
    for (var tx in transactionsList) {
      // Add to category totals
      catTotals.update(tx.category.name, (value) => value + tx.amount, ifAbsent: () => tx.amount);
      spent += tx.amount;

      // Calculate today's spending
      final formatted = DateFormat('yyyy-MM-dd').format(tx.date);
      if (formatted == today) {
        todayAmount += tx.amount;
      }

      // Calculate this week's spending
      if (tx.date.isAfter(startOfWeek) || tx.date.isAtSameMomentAs(startOfWeek)) {
        weekAmount += tx.amount;
      }
    }

    // Calculate streak
    int consecutiveDays = _calculateStreak(transactionsList);

    setState(() {
      transactions = transactionsList;
      categoryTotals = catTotals;
      totalSpent = spent;
      todaySpent = todayAmount;
      currentWeekSpent = weekAmount;
      streak = consecutiveDays;
      currentBalance = totalBudget != null ? (totalBudget! - spent).clamp(0, totalBudget!) : 0;
      isLoading = false;
    });
  }

  int _calculateStreak(List<TransactionItem> txList) {
    if (txList.isEmpty) return 0;

    // Group by day
    final Set<String> daysWithTransactions = {};
    for (var tx in txList) {
      daysWithTransactions.add(DateFormat('yyyy-MM-dd').format(tx.date));
    }

    final sortedDays = daysWithTransactions.toList()
      ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));

    // Calculate consecutive days
    int consecutiveDays = 0;
    if (sortedDays.isEmpty) return 0;

    DateTime checkDate = DateTime.parse(sortedDays[0]);
    for (int i = 0; i < sortedDays.length; i++) {
      if (i > 0) {
        final currentDate = DateTime.parse(sortedDays[i]);
        final expectedDate = checkDate.subtract(const Duration(days: 1));

        if (DateFormat('yyyy-MM-dd').format(currentDate) !=
            DateFormat('yyyy-MM-dd').format(expectedDate)) {
          break;
        }
        checkDate = currentDate;
      }
      consecutiveDays++;
    }

    return consecutiveDays;
  }

  Widget _buildHealthIndicator() {
    double percentage = totalBudget != null && totalBudget! > 0
        ? (currentBalance / totalBudget!).clamp(0.0, 1.0)
        : 0.0;

    int score = (percentage * 100).round();

    Color scoreColor;
    if (score > 80) {
      scoreColor = Colors.green;
    } else if (score > 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Budget Health",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CircularPercentIndicator(
              radius: 60.0,
              lineWidth: 10.0,
              percent: percentage,
              animation: true,
              animationDuration: 1000,
              center: Text(
                "$score",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              progressColor: scoreColor,
              backgroundColor: Colors.grey.shade200,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 8),
            Text(
              _getHealthMessage(percentage),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHealthMessage(double percentage) {
    int score = (percentage * 100).round();

    if (score > 80) {
      return "Excellent budget management!";
    } else if (score > 60) {
      return "Good job! Budget on track.";
    } else if (score > 40) {
      return "Watch your spending!";
    } else {
      return "Budget alert! Reduce spending.";
    }
  }

  Widget _buildSpendingTrends() {
    if (transactions.isEmpty) {
      return const Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text("No transaction data available"),
          ),
        ),
      );
    }

    // Group transactions by day for chart
    final Map<DateTime, double> dailySpending = {};

    for (var tx in transactions) {
      final date = DateTime(
        tx.date.year,
        tx.date.month,
        tx.date.day,
      );
      dailySpending[date] = (dailySpending[date] ?? 0) + tx.amount;
    }

    final sortedDates = dailySpending.keys.toList()..sort();
    if (sortedDates.isEmpty) return const SizedBox.shrink();

    final List<FlSpot> spendingSpots = [];
    for (int i = 0; i < sortedDates.length; i++) {
      spendingSpots.add(FlSpot(i.toDouble(), dailySpending[sortedDates[i]]!));
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Spending Trends",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                            final date = sortedDates[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('d').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 22,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spendingSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modified to show transaction labels from the TransactionItem
  Widget _buildTransactionCard(TransactionItem tx) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tx.category.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            tx.category.icon,
            color: tx.category.color,
            size: 20,
          ),
        ),
        title: Text(
          tx.name, // Using the transaction name directly
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy').format(tx.date),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Text(
          currencyFormat.format(tx.amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Summary"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget Summary Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Budget Summary",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(selectedMonth),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Total Budget"),
                              Text(
                                currencyFormat.format(totalBudget ?? 0),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Remaining"),
                              Text(
                                currencyFormat.format(currentBalance),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: currentBalance > 0 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: totalBudget != null && totalBudget! > 0
                            ? (totalSpent / totalBudget!).clamp(0.0, 1.0)
                            : 0.0,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          (currentBalance > 0) ? Colors.green : Colors.red,
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Spent: ${currencyFormat.format(totalSpent)}",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Time-Based Summary Section
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Time-Based Summary",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTimeCard(
                            "Today",
                            currencyFormat.format(todaySpent),
                            Icons.today,
                            Colors.blue,
                          ),
                          _buildTimeCard(
                            "This Week",
                            currencyFormat.format(currentWeekSpent),
                            Icons.calendar_view_week,
                            Colors.purple,
                          ),
                          _buildTimeCard(
                            "Month",
                            currencyFormat.format(totalSpent),
                            Icons.calendar_month,
                            Colors.teal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Health Score and Streak section
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildHealthIndicator(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Tracking Streak",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.orange,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "$streak days",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              streak > 1
                                  ? "Keep it up!"
                                  : "Start your streak!",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Spending Trends chart
              _buildSpendingTrends(),

              const SizedBox(height: 16),

              // Recent Transactions (Added to show transaction names)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Recent Transactions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (transactions.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text("No transactions recorded yet"),
                          ),
                        )
                      else
                        Column(
                          children: transactions
                              .take(5)
                              .map((tx) => _buildTransactionCard(tx))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Smart Insights
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Smart Insights",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (todaySpent > 0.3 * totalSpent)
                        _buildInsightItem(
                          "\u26A0 High daily spending!",
                          "You spent over 30% of your budget today.",
                          Colors.red,
                          Icons.trending_up,
                        ),
                      if (currentWeekSpent > 0.7 * totalSpent)
                        _buildInsightItem(
                          "\u26A0 Weekly budget alert",
                          "You're close to your weekly budget limit.",
                          Colors.orange,
                          Icons.warning_amber,
                        ),
                      if (todaySpent <= 0.3 * totalSpent && currentWeekSpent <= 0.7 * totalSpent)
                        _buildInsightItem(
                          "✓ On track",
                          "Your spending is on target this period.",
                          Colors.green,
                          Icons.check_circle,
                        ),
                      if (streak >= 3)
                        _buildInsightItem(
                          "🔥 Great streak!",
                          "You've recorded transactions for $streak days in a row.",
                          Colors.blue,
                          Icons.local_fire_department,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard(String title, String amount, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String title, String description, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}