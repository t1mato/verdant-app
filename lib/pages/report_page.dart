import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/database_service.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  final currencyFormat = NumberFormat.currency(symbol: '\$');
  late TabController _tabController;
  bool isLoading = true;

  // Transaction data
  List<TransactionItem> transactions = [];
  Map<String, double> categoryTotals = {};
  List<String> categoryLabels = [];
  List<double> categoryData = [];
  List<Color> categoryColors = [];

  // Time periods
  DateTime selectedMonth = DateTime.now();
  DateTime selectedWeek = DateTime.now();
  String selectedPeriod = 'Monthly';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupPeriodDates();
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupPeriodDates() {
    // Set selected week to start of current week
    final now = DateTime.now();
    selectedWeek = now.subtract(Duration(days: now.weekday - 1));
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      // Get proper date range based on selected period
      DateRange dateRange;

      if (selectedPeriod == 'Monthly') {
        dateRange = DateRange.forMonth(selectedMonth);
      } else if (selectedPeriod == 'Weekly') {
        final startDate = selectedWeek;
        final endDate = selectedWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        dateRange = DateRange(startDate: startDate, endDate: endDate, label: 'Weekly');
      } else { // All-time
        final startDate = DateTime(2020, 1, 1); // Far past date
        final endDate = DateTime.now().add(const Duration(days: 1)); // Include today
        dateRange = DateRange(startDate: startDate, endDate: endDate, label: 'All Time');
      }

      // Get transactions for the period
      final transactionsList = await dbService.getTransactionsStream(dateRange).first;

      // Process transactions for reports
      _processTransactions(transactionsList);
    } catch (e) {
      debugPrint('Error fetching report data: $e');
      setState(() => isLoading = false);
    }
  }

  void _processTransactions(List<TransactionItem> transactionsList) {
    // Prepare summary data
    final Map<String, double> catTotals = {};
    final List<String> labels = [];
    final List<double> values = [];
    final List<Color> colors = [];

    // Process transactions
    for (var tx in transactionsList) {
      catTotals.update(tx.category.name, (value) => value + tx.amount, ifAbsent: () => tx.amount);
    }

    // Sort categories by amount spent (descending)
    final sortedCategories = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedCategories) {
      final categoryInfo = availableCategories.firstWhere(
            (cat) => cat.name == entry.key,
        orElse: () => CategoryInfo(entry.key, Icons.category, Colors.grey),
      );

      labels.add(entry.key);
      values.add(entry.value);
      colors.add(categoryInfo.color);
    }

    setState(() {
      transactions = transactionsList;
      categoryTotals = catTotals;
      categoryLabels = labels;
      categoryData = values;
      categoryColors = colors;
      isLoading = false;
    });
  }

  void _previousPeriod() {
    setState(() {
      if (selectedPeriod == 'Monthly') {
        selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
      } else if (selectedPeriod == 'Weekly') {
        selectedWeek = selectedWeek.subtract(const Duration(days: 7));
      }
    });
    _fetchData();
  }

  void _nextPeriod() {
    final now = DateTime.now();

    setState(() {
      if (selectedPeriod == 'Monthly') {
        if (selectedMonth.year < now.year ||
            (selectedMonth.year == now.year && selectedMonth.month < now.month)) {
          selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
        }
      } else if (selectedPeriod == 'Weekly') {
        final nextWeek = selectedWeek.add(const Duration(days: 7));
        if (nextWeek.isBefore(now)) {
          selectedWeek = nextWeek;
        }
      }
    });
    _fetchData();
  }

  Widget _buildPieChart() {
    if (categoryLabels.isEmpty) {
      return const Center(
        child: Text("No spending data for this period"),
      );
    }

    return SfCircularChart(
      title: ChartTitle(
        text: 'Spending by Category',
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      legend: Legend(
        isVisible: true,
        overflowMode: LegendItemOverflowMode.wrap,
        position: LegendPosition.bottom,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries>[
        DoughnutSeries<_ChartData, String>(
          dataSource: List.generate(
            categoryLabels.length,
                (index) => _ChartData(
              categoryLabels[index],
              categoryData[index],
              categoryColors[index],
            ),
          ),
          xValueMapper: (_ChartData data, _) => data.label,
          yValueMapper: (_ChartData data, _) => data.amount,
          pointColorMapper: (_ChartData data, _) => data.color,
          dataLabelMapper: (_ChartData data, _) =>
          '${data.label}\n${currencyFormat.format(data.amount)}',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
          ),
          explode: true,
          explodeIndex: 0,
        )
      ],
    );
  }

  Widget _buildBarChart() {
    if (categoryLabels.isEmpty) {
      return const Center(
        child: Text("No spending data for this period"),
      );
    }

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        numberFormat: currencyFormat,
        labelStyle: const TextStyle(fontSize: 10),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        ColumnSeries<_ChartData, String>(
          dataSource: List.generate(
            categoryLabels.length,
                (index) => _ChartData(
              categoryLabels[index],
              categoryData[index],
              categoryColors[index],
            ),
          ),
          xValueMapper: (_ChartData data, _) => data.label,
          yValueMapper: (_ChartData data, _) => data.amount,
          pointColorMapper: (_ChartData data, _) => data.color,
          dataLabelMapper: (_ChartData data, _) => currencyFormat.format(data.amount),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
          ),
          width: 0.7,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        )
      ],
    );
  }

  Widget _buildSpendingTrendChart() {
    if (transactions.isEmpty) {
      return const Center(
        child: Text("No transaction data to display"),
      );
    }

    // Group transactions by day
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

    // Format X-axis dates
    List<String> xAxisLabels = [];
    for (var date in sortedDates) {
      xAxisLabels.add(DateFormat('MM/dd').format(date));
    }

    // Build data points
    List<FlSpot> spots = [];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailySpending[sortedDates[i]]!));
    }

    // Get min/max values
    double maxY = 0;
    if (spots.isNotEmpty) {
      maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
      maxY = (maxY * 1.2).ceilToDouble(); // Add 20% padding to the top
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            "Daily Spending Trend",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxY > 0 ? maxY / 5 : 50,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          currencyFormat.format(value).replaceAll('.00', ''),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                      interval: maxY > 0 ? maxY / 5 : 50,
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < xAxisLabels.length && index % 2 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              xAxisLabels[index],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.3))),
                minX: 0,
                maxX: spots.isEmpty ? 1 : spots.length - 1.0,
                minY: 0,
                maxY: maxY > 0 ? maxY : 100,
                lineBarsData: spots.isEmpty ? [] : [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: spots.length < 10),
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
    );
  }

  // Updated to use transaction name
  Widget _buildTopExpenses() {
    if (transactions.isEmpty) {
      return const Center(
        child: Text("No transactions to display"),
      );
    }

    // Sort transactions by amount (descending)
    final topTransactions = List<TransactionItem>.from(transactions)
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Take top 5 expenses
    final top5 = topTransactions.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Top Expenses",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: top5.length,
            itemBuilder: (context, index) {
              final tx = top5[index];

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
                    tx.name, // Using transaction name from the object
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySummary() {
    if (categoryTotals.isEmpty) {
      return const Center(
        child: Text("No spending data to display"),
      );
    }

    double totalSpent = categoryData.fold(0, (sum, amount) => sum + amount);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Category Breakdown",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: categoryLabels.length,
            itemBuilder: (context, index) {
              final categoryName = categoryLabels[index];
              final amount = categoryData[index];
              final percentage = totalSpent > 0 ? (amount / totalSpent * 100) : 0;

              final categoryInfo = availableCategories.firstWhere(
                    (cat) => cat.name == categoryName,
                orElse: () => CategoryInfo(categoryName, Icons.category, Colors.grey),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(categoryInfo.icon, color: categoryInfo.color, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              categoryName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Text(
                          "${percentage.toStringAsFixed(1)}% (${currencyFormat.format(amount)})",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(categoryInfo.color),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Updated to use transaction name
  Widget _buildTransactionsList() {
    if (transactions.isEmpty) {
      return const Center(
        child: Text("No transactions to display"),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Transactions",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: transactions.length.clamp(0, 10),
            itemBuilder: (context, index) {
              final tx = transactions[index];

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
                    tx.name, // Using transaction name from the object
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
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Summary"),
            Tab(text: "Trends"),
            Tab(text: "Details"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Period type dropdown
                DropdownButton<String>(
                  value: selectedPeriod,
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue != selectedPeriod) {
                      setState(() {
                        selectedPeriod = newValue;
                      });
                      _fetchData();
                    }
                  },
                  items: <String>['Monthly', 'Weekly', 'All Time']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),

                // Period navigation
                if (selectedPeriod != 'All Time')
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _previousPeriod,
                      ),
                      Text(
                        selectedPeriod == 'Monthly'
                            ? DateFormat('MMMM yyyy').format(selectedMonth)
                            : "${DateFormat('MMM d').format(selectedWeek)} - ${DateFormat('MMM d').format(selectedWeek.add(const Duration(days: 6)))}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextPeriod,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Summary Tab
                SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 350,
                        child: _buildPieChart(),
                      ),
                      _buildCategorySummary(),
                    ],
                  ),
                ),

                // Trends Tab
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSpendingTrendChart(),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 350,
                        child: _buildBarChart(),
                      ),
                    ],
                  ),
                ),

                // Details Tab
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTopExpenses(),
                      const SizedBox(height: 16),
                      // Transaction list
                      _buildTransactionsList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double amount;
  final Color color;

  _ChartData(this.label, this.amount, this.color);
}