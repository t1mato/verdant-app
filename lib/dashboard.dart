import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;
  final double? limit;

  CategoryInfo(this.name, this.icon, this.color, {this.limit});
}

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
}

class CategorySpending {
  final CategoryInfo category;
  double amount;

  CategorySpending(this.category, this.amount);
}

final List<CategoryInfo> availableCategories = [
  CategoryInfo("Food", Icons.restaurant, Colors.orange),
  CategoryInfo("Bills", Icons.receipt, Colors.blue),
  CategoryInfo("Entertainment", Icons.movie, Colors.purple),
  CategoryInfo("Transport", Icons.directions_car, Colors.teal),
  CategoryInfo("Shopping", Icons.shopping_bag, Colors.pink),
  CategoryInfo("Health", Icons.favorite, Colors.red),
  CategoryInfo("Groceries", Icons.local_grocery_store, Colors.green),
  CategoryInfo("Other", Icons.more_horiz, Colors.grey),
];

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  double? totalBudget;
  double currentBalance = 0.0;
  List<TransactionItem> transactions = [];
  List<CategorySpending> categorySpending = [];
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  late TabController _tabController;
  bool isLoading = true;
  bool isDarkMode = false;
  bool isMonthly = true;
  DateTime selectedMonth = DateTime.now();

  // Formatting utilities
  final currencyFormat = NumberFormat.currency(symbol: '\$');
  final dateFormat = DateFormat('MMM d');
  final monthFormat = DateFormat('MMMM yyyy');

  // Data cache
  late Stream<DocumentSnapshot> userPrefsStream;
  late Stream<QuerySnapshot> transactionStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupStreams();
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupStreams() {
    // Stream for user preferences
    userPrefsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();

    userPrefsStream.listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          final data = snapshot.data() as Map<String, dynamic>;
          totalBudget = data['totalBudget'] ?? 0.0;
          isDarkMode = data['darkMode'] ?? false;
          isMonthly = data['isMonthly'] ?? true;
        });
      }
    });

    // Stream for transactions
    _updateTransactionStream();
  }

  void _updateTransactionStream() {
    final DateTime firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final DateTime lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);

    transactionStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .orderBy('timestamp', descending: true)
        .snapshots();

    transactionStream.listen((snapshot) {
      _processTransactions(snapshot);
    });
  }

  void _processTransactions(QuerySnapshot snapshot) {
    final List<TransactionItem> loadedTransactions = [];
    final Map<String, double> catSpending = {};
    double spent = 0.0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = availableCategories.firstWhere(
            (cat) => cat.name == data['category'],
        orElse: () => availableCategories[7], // Default to "Other"
      );

      final amount = (data['amount'] as num).toDouble();
      final date = (data['timestamp'] as Timestamp).toDate();

      loadedTransactions.add(TransactionItem(
        id: doc.id,
        name: data['name'],
        amount: amount,
        category: category,
        date: date,
      ));

      catSpending[category.name] = (catSpending[category.name] ?? 0.0) + amount;
      spent += amount;
    }

    final List<CategorySpending> catSpendingList = [];
    for (var entry in catSpending.entries) {
      final category = availableCategories.firstWhere(
            (cat) => cat.name == entry.key,
        orElse: () => availableCategories[7],
      );
      catSpendingList.add(CategorySpending(category, entry.value));
    }

    catSpendingList.sort((a, b) => b.amount.compareTo(a.amount));

    setState(() {
      transactions = loadedTransactions;
      categorySpending = catSpendingList;
      currentBalance = totalBudget != null ? (totalBudget! - spent).clamp(0, totalBudget!) : 0;
      isLoading = false;
    });
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        setState(() {
          totalBudget = data['totalBudget'] ?? 0.0;
          isDarkMode = data['darkMode'] ?? false;
          isMonthly = data['isMonthly'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Simplified method to update user preferences
  Future<void> _saveUserPreferences() async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'totalBudget': totalBudget,
      'darkMode': isDarkMode,
      'isMonthly': isMonthly,
    }, SetOptions(merge: true));
  }

  // Transaction operations
  Future<void> _addTransaction(String name, double amount, String categoryName, DateTime date) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add({
      'name': name,
      'amount': amount,
      'category': categoryName,
      'timestamp': Timestamp.fromDate(date),
    });
  }

  Future<void> _deleteTransaction(TransactionItem item) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(item.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _restoreTransaction(item),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _restoreTransaction(TransactionItem item) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(item.id)
          .set({
        'name': item.name,
        'amount': item.amount,
        'category': item.category.name,
        'timestamp': Timestamp.fromDate(item.date),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Budget dialog methods
  void _setBudget() => _showBudgetDialog('Set Budget', null);
  void _editBudget() => _showBudgetDialog('Edit Budget', totalBudget);

  void _showBudgetDialog(String title, double? initialValue) {
    final budgetController = TextEditingController(
      text: initialValue?.toStringAsFixed(2) ?? '',
    );
    bool localIsMonthly = isMonthly;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {
          return AlertDialog(
              title: Text(title),
        content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        },
      },
    )),
    ],
    );
  },
  );
}

Widget _buildInsightsTab() {
  if (transactions.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "No insights available",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add transactions to see insights",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // Calculate insights
  double totalSpent = totalBudget != null ? totalBudget! - currentBalance : 0;
  double avgDailySpending = 0;
  CategoryInfo? topCategory;
  double topCategoryAmount = 0;
  DateTime? largestExpenseDate;
  double largestExpenseAmount = 0;
  String largestExpenseName = "";

  if (transactions.isNotEmpty) {
    // Get oldest and newest dates
    DateTime oldestDate = transactions.map((tx) => tx.date).reduce(
          (a, b) => a.isBefore(b) ? a : b,
    );
    DateTime newestDate = transactions.map((tx) => tx.date).reduce(
          (a, b) => a.isAfter(b) ? a : b,
    );

    // Calculate days with spending
    int daysWithSpending = newestDate.difference(oldestDate).inDays + 1;
    if (daysWithSpending > 0) {
      avgDailySpending = totalSpent / daysWithSpending;
    }

    // Find top category
    if (categorySpending.isNotEmpty) {
      topCategory = categorySpending[0].category;
      topCategoryAmount = categorySpending[0].amount;
    }

    // Find largest expense
    for (var tx in transactions) {
      if (tx.amount > largestExpenseAmount) {
        largestExpenseAmount = tx.amount;
        largestExpenseName = tx.name;
        largestExpenseDate = tx.date;
      }
    }
  }

  // Calculate daily spending data for chart
  final Map<DateTime, double> dailySpending = {};

  for (var tx in transactions) {
    final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
    dailySpending[date] = (dailySpending[date] ?? 0) + tx.amount;
  }

  final sortedDates = dailySpending.keys.toList()..sort();

  final List<FlSpot> spendingSpots = [];
  for (int i = 0; i < sortedDates.length; i++) {
    spendingSpots.add(FlSpot(i.toDouble(), dailySpending[sortedDates[i]]!));
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spending Overview
        _buildInsightCard(
          "Spending Overview",
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInsightItem(
                    "Total Spent",
                    currencyFormat.format(totalSpent),
                    Colors.red,
                  ),
                  _buildInsightItem(
                    "Daily Average",
                    currencyFormat.format(avgDailySpending),
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (topCategory != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInsightItem(
                      "Top Category",
                      topCategory.name,
                      topCategory.color,
                      icon: topCategory.icon,
                    ),
                    _buildInsightItem(
                      "Amount",
                      currencyFormat.format(topCategoryAmount),
                      topCategory.color,
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Largest Expense
        if (largestExpenseDate != null)
          _buildInsightCard(
            "Largest Expense",
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.arrow_circle_up, color: Colors.red, size: 42),
              title: Text(
                largestExpenseName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(DateFormat('MMM d, yyyy').format(largestExpenseDate)),
              trailing: Text(
                currencyFormat.format(largestExpenseAmount),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

        // Daily Spending Chart
        if (spendingSpots.isNotEmpty)
          _buildInsightCard(
            "Daily Spending",
            SizedBox(
              height: 200,
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
          ),

        // Budget Health
        _buildInsightCard(
          "Budget Health",
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Budget Health Score",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildHealthScore(),
                const SizedBox(height: 16),
                Text(
                  _getHealthMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
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

Widget _buildInsightCard(String title, Widget content) {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    ),
  );
}

Widget _buildInsightItem(String label, String value, Color color, {IconData? icon}) {
  return Column(
    children: [
      if (icon != null)
        Icon(icon, color: color, size: 24)
      else
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value.substring(0, 1),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    ],
  );
}

Widget _buildHealthScore() {
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

  return CircularPercentIndicator(
    radius: 60.0,
    lineWidth: 10.0,
    percent: percentage,
    center: Text(
      "$score",
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: scoreColor,
      ),
    ),
    progressColor: scoreColor,
    backgroundColor: Colors.grey.shade200,
    circularStrokeCap: CircularStrokeCap.round,
  );
}

String _getHealthMessage() {
  double percentage = totalBudget != null && totalBudget! > 0
      ? (currentBalance / totalBudget!).clamp(0.0, 1.0)
      : 0.0;

  int score = (percentage * 100).round();

  if (score > 80) {
    return "Excellent! You're managing your budget very well.";
  } else if (score > 60) {
    return "Good job! Your budget is on track.";
  } else if (score > 40) {
    return "Watch your spending - you're using your budget quickly.";
  } else {
    return "Budget alert! You need to reduce spending.";
  }
}

// Settings tab
Widget _buildSettingsTab() {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text("Budget"),
              subtitle: Text(
                totalBudget != null
                    ? "${currencyFormat.format(totalBudget!)} (${isMonthly ? 'Monthly' : 'One-time'})"
                    : "Not set",
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _editBudget,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.calendar_month),
              title: const Text("Monthly Budget"),
              subtitle: const Text("Reset budget at month start"),
              value: isMonthly,
              onChanged: (value) {
                setState(() {
                  isMonthly = value;
                });
                _saveUserPreferences();
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text("Dark Mode"),
              subtitle: const Text("Switch between light and dark theme"),
              value: isDarkMode,
              onChanged: (value) {
                setState(() {
                  isDarkMode = value;
                });
                _saveUserPreferences();
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text("Categories"),
              subtitle: const Text("Manage expense categories"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Categories management coming soon!')),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text("Backup Data"),
              subtitle: const Text("Export your budget data"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data backup feature coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("About"),
              subtitle: const Text("App information and privacy policy"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: "Budget Tracker",
                  applicationVersion: "1.0.0",
                  applicationLegalese: "© 2025 Budget Tracker App",
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Sign Out", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                // Navigate to login page
              },
            ),
          ],
        ),
      ),
    ],
  );
}

@override
Widget build(BuildContext context) {
  return Theme(
    data: isDarkMode
        ? ThemeData.dark().copyWith(
      primaryColor: Colors.teal,
      colorScheme: ColorScheme.dark(
        primary: Colors.teal,
        secondary: Colors.tealAccent,
      ),
    )
        : ThemeData.light().copyWith(
      primaryColor: Colors.teal,
      colorScheme: ColorScheme.light(
        primary: Colors.teal,
        secondary: Colors.tealAccent,
      ),
    ),
    child: Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Budget Tracker",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isMonthly)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _previousMonth,
                            ),
                            Text(
                              monthFormat.format(selectedMonth),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                        onPressed: _toggleDarkMode,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadUserData,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: totalBudget == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Welcome to Budget Tracker!",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Set up your budget to get started",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _setBudget,
                      icon: const Icon(Icons.add),
                      label: const Text("Set Budget"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : Column(
                children: [
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: "Dashboard"),
                      Tab(text: "Transactions"),
                      Tab(text: "Insights"),
                    ],
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Dashboard Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBudgetIndicator(),
                              const SizedBox(height: 16),
                              const Text(
                                "Recent Transactions",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              transactions.isEmpty
                                  ? Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      "No transactions yet",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                                  : Column(
                                children: transactions
                                    .take(5)
                                    .map((tx) => _buildTransactionItem(tx))
                                    .toList(),
                              ),
                              if (transactions.length > 5)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: () {
                                        _tabController.animateTo(1);
                                      },
                                      child: const Text("View All Transactions"),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Transactions Tab
                        _buildTransactionsTab(),

                        // Insights Tab
                        _buildInsightsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: totalBudget == null
          ? null
          : FloatingActionButton.extended(
        onPressed: () => _quickAdd(context),
        icon: const Icon(Icons.add),
        label: const Text("Quick Add"),
      ),
    ),
  );
}TextField(
controller: budgetController,
decoration: const InputDecoration(
labelText: "Enter budget amount",
prefixIcon: Icon(Icons.attach_money),
border: OutlineInputBorder(),
),
keyboardType: TextInputType.number,
),
const SizedBox(height: 16),
SwitchListTile(
title: const Text("Monthly Budget"),
subtitle: const Text("Reset budget at month start"),
value: localIsMonthly,
onChanged: (value) {
setStateDialog(() => localIsMonthly = value);
},
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text("Cancel")
),
ElevatedButton(
onPressed: () async {
final enteredBudget = double.tryParse(budgetController.text);
if (enteredBudget != null && enteredBudget > 0) {
setState(() {
totalBudget = enteredBudget;
isMonthly = localIsMonthly;
});
await _saveUserPreferences();
Navigator.pop(context);
}
},
child: Text(initialValue == null ? "Set" : "Update"),
),
],
);
}
);
},
);
}

// UI related methods
void _toggleDarkMode() {
setState(() => isDarkMode = !isDarkMode);
_saveUserPreferences();
}

void _previousMonth() {
setState(() {
selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
});
_updateTransactionStream();
}

void _nextMonth() {
final now = DateTime.now();
if (selectedMonth.year < now.year ||
(selectedMonth.year == now.year && selectedMonth.month < now.month)) {
setState(() {
selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
});
_updateTransactionStream();
}
}

// Quick add transaction UI
void _quickAdd(BuildContext context) {
showModalBottomSheet(
context: context,
isScrollControlled: true,
shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
),
builder: (context) {
double amount = 0;
CategoryInfo selectedCategory = availableCategories[0];

return StatefulBuilder(
builder: (context, setModalState) {
return Padding(
padding: EdgeInsets.only(
bottom: MediaQuery.of(context).viewInsets.bottom,
left: 16, right: 16, top: 16,
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
// Drag handle
Container(
width: 40, height: 4,
decoration: BoxDecoration(
color: Colors.grey.shade300,
borderRadius: BorderRadius.circular(2),
),
),
const SizedBox(height: 16),
const Text(
"Quick Add Expense",
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),
// Amount input
TextField(
autofocus: true,
decoration: const InputDecoration(
labelText: "Amount",
prefixIcon: Icon(Icons.attach_money),
border: OutlineInputBorder(),
),
keyboardType: TextInputType.number,
onChanged: (value) {
setModalState(() {
amount = double.tryParse(value) ?? 0;
});
},
),
const SizedBox(height: 16),
// Category selector
SizedBox(
height: 100,
child: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: availableCategories.length,
itemBuilder: (context, index) {
final category = availableCategories[index];
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 8),
child: GestureDetector(
onTap: () {
setModalState(() {
selectedCategory = category;
});
},
child: Column(
children: [
Container(
width: 50,
height: 50,
decoration: BoxDecoration(
color: selectedCategory == category
? category.color
    : category.color.withOpacity(0.2),
shape: BoxShape.circle,
),
child: Icon(
category.icon,
color: selectedCategory == category
? Colors.white
    : category.color,
),
),
const SizedBox(height: 8),
Text(
category.name,
style: TextStyle(
color: selectedCategory == category
? category.color
    : null,
fontWeight: selectedCategory == category
? FontWeight.bold
    : null,
),
),
],
),
),
);
},
),
),
const SizedBox(height: 16),
// Add button
SizedBox(
width: double.infinity,
child: ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: selectedCategory.color,
foregroundColor: Colors.white,
padding: const EdgeInsets.symmetric(vertical: 12),
),
onPressed: amount > 0 ? () async {
await _addTransaction(
selectedCategory.name,
amount,
selectedCategory.name,
DateTime.now(),
);
Navigator.pop(context);
} : null,
child: Text("Add ${currencyFormat.format(amount)}"),
),
),
const SizedBox(height: 20),
],
),
);
}
);
},
);
}

// Add full transaction dialog
void _addNewTransaction() {
CategoryInfo? selectedCategory = availableCategories.isNotEmpty ? availableCategories[0] : null;
final amountController = TextEditingController();
final nameController = TextEditingController();
DateTime selectedDate = DateTime.now();

showDialog(
context: context,
builder: (context) {
return StatefulBuilder(builder: (context, setStateDialog) {
return AlertDialog(
title: const Row(
children: [
Icon(Icons.add_shopping_cart, size: 24),
SizedBox(width: 8),
Text("Add Expense"),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
TextField(
controller: nameController,
decoration: const InputDecoration(
labelText: "Description",
prefixIcon: Icon(Icons.short_text),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 16),
TextField(
controller: amountController,
decoration: const InputDecoration(
labelText: "Amount",
prefixIcon: Icon(Icons.attach_money),
border: OutlineInputBorder(),
),
keyboardType: TextInputType.number,
),
const SizedBox(height: 16),
const Text("Category", style: TextStyle(fontSize: 16)),
const SizedBox(height: 8),
SizedBox(
height: 100,
child: GridView.builder(
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 4,
childAspectRatio: 1.0,
crossAxisSpacing: 10,
mainAxisSpacing: 10,
),
itemCount: availableCategories.length,
itemBuilder: (context, index) {
final category = availableCategories[index];
return GestureDetector(
onTap: () {
setStateDialog(() {
selectedCategory = category;
});
},
child: Container(
decoration: BoxDecoration(
color: selectedCategory == category
? category.color.withOpacity(0.3)
    : Colors.transparent,
borderRadius: BorderRadius.circular(10),
border: Border.all(
color: selectedCategory == category
? category.color
    : Colors.grey.shade300,
width: 2,
),
),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(category.icon, color: category.color),
const SizedBox(height: 4),
Text(
category.name,
style: TextStyle(
fontSize: 10,
color: category.color,
),
overflow: TextOverflow.ellipsis,
),
],
),
),
);
},
),
),
const SizedBox(height: 16),
ListTile(
contentPadding: EdgeInsets.zero,
leading: const Icon(Icons.calendar_today),
title: Text(DateFormat('EEE, MMM d').format(selectedDate)),
trailing: const Icon(Icons.arrow_drop_down),
onTap: () async {
final picked = await showDatePicker(
context: context,
initialDate: selectedDate,
firstDate: DateTime(2020),
lastDate: DateTime.now().add(const Duration(days: 1)),
);
if (picked != null) {
setStateDialog(() {
selectedDate = picked;
});
}
},
),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text("Cancel")
),
ElevatedButton(
onPressed: () async {
String transactionName = nameController.text.trim();
double amount = double.tryParse(amountController.text) ?? 0.0;

if (selectedCategory != null && transactionName.isNotEmpty && amount > 0) {
await _addTransaction(
transactionName,
amount,
selectedCategory!.name,
selectedDate,
);
Navigator.pop(context);
} else {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please fill all fields correctly')),
);
}
},
child: const Text("Add"),
),
],
);
});
},
);
}

// UI Components
Widget _buildBudgetIndicator() {
double percentage = totalBudget != null && totalBudget! > 0
? (currentBalance / totalBudget!).clamp(0.0, 1.0)
    : 0.0;

Color indicatorColor;
if (percentage > 0.5) {
indicatorColor = Colors.green;
} else if (percentage > 0.2) {
indicatorColor = Colors.orange;
} else {
indicatorColor = Colors.red;
}

return Card(
elevation: 4,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
isMonthly ? "Monthly Budget" : "Budget",
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
GestureDetector(
onTap: _editBudget,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: Colors.blue.withOpacity(0.1),
borderRadius: BorderRadius.circular(12),
),
child: const Row(
children: [
Icon(Icons.edit, size: 14, color: Colors.blue),
SizedBox(width: 4),
Text(
"Edit",
style: TextStyle(
color: Colors.blue,
fontWeight: FontWeight.bold,
),
),
],
),
),
),
],
),
const SizedBox(height: 16),
CircularPercentIndicator(
radius: 100.0,
lineWidth: 15.0,
percent: percentage,
animation: true,
animationDuration: 1000,
center: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(
currencyFormat.format(currentBalance),
style: const TextStyle(
fontSize: 24,
fontWeight: FontWeight.bold,
),
),
Text(
"of ${currencyFormat.format(totalBudget ?? 0)}",
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade600,
),
),
],
),
progressColor: indicatorColor,
backgroundColor: Colors.grey.shade200,
circularStrokeCap: CircularStrokeCap.round,
footer: Padding(
padding: const EdgeInsets.only(top: 16.0),
child: Text(
_getBudgetStatusMessage(percentage),
style: TextStyle(
fontSize: 14,
color: indicatorColor,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
),
);
}

String _getBudgetStatusMessage(double percentage) {
if (percentage > 0.75) return "You're doing great! Keep it up!";
if (percentage > 0.5) return "Good job managing your budget!";
if (percentage > 0.25) return "Watch your spending!";
return "Budget alert! You're spending fast!";
}

// Transaction item widget
Widget _buildTransactionItem(TransactionItem tx) {
return Card(
margin: const EdgeInsets.symmetric(vertical: 4),
elevation: 1,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
child: ListTile(
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
leading: Container(
width: 48,
height: 48,
decoration: BoxDecoration(
color: tx.category.color.withOpacity(0.2),
borderRadius: BorderRadius.circular(8),
),
child: Icon(
tx.category.icon,
color: tx.category.color,
size: 24,
),
),
title: Text(
tx.name,
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
subtitle: Text(
tx.category.name,
style: TextStyle(color: Colors.grey.shade600),
),
trailing: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.end,
children: [
Text(
"-${currencyFormat.format(tx.amount)}",
style: const TextStyle(
fontWeight: FontWeight.bold,
color: Colors.red,
),
),
Text(
DateFormat('h:mm a').format(tx.date),
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade500,
),
),
],
),
),
);
}

// Tab views
Widget _buildTransactionsTab() {
if (transactions.isEmpty) {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.receipt_long,
size: 64,
color: Colors.grey.shade400,
),
const SizedBox(height: 16),
Text(
"No transactions yet",
style: TextStyle(
fontSize: 18,
color: Colors.grey.shade600,
),
),
const SizedBox(height: 8),
Text(
"Tap the + button to add one",
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade500,
),
),
],
),
);
}

final groupedTransactions = <String, List<TransactionItem>>{};
for (var tx in transactions) {
final dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
if (!groupedTransactions.containsKey(dateKey)) {
groupedTransactions[dateKey] = [];
}
groupedTransactions[dateKey]!.add(tx);
}

final sortedDates = groupedTransactions.keys.toList()..sort((b, a) => a.compareTo(b));

return ListView.builder(
itemCount: sortedDates.length,
padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
itemBuilder: (context, dateIndex) {
final dateKey = sortedDates[dateIndex];
final txs = groupedTransactions[dateKey]!;
final date = DateTime.parse(dateKey);

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Padding(
padding: const EdgeInsets.only(top: 16, bottom: 8),
child: Row(
children: [
Text(
DateFormat('EEEE, MMMM d').format(date),
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.bold,
color: Colors.grey.shade600,
),
),
const Spacer(),
if (DateUtils.isSameDay(date, DateTime.now()))
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
decoration: BoxDecoration(
color: Colors.blue.shade100,
borderRadius: BorderRadius.circular(12),
),
child: const Text(
"Today",
style: TextStyle(
fontSize: 12,
color: Colors.blue,
fontWeight: FontWeight.bold,
),
),
),
],
),
),
...txs.map((tx) => Dismissible(
key: Key(tx.id),
background: Container(
margin: const EdgeInsets.symmetric(vertical: 4),
decoration: BoxDecoration(
color: Colors.red.shade400,
borderRadius: BorderRadius.circular(12),
),
alignment: Alignment.centerLeft,
padding: const EdgeInsets.symmetric(horizontal: 20),
child: const Icon(Icons.delete, color: Colors.white),
),
secondaryBackground: Container(
margin: const EdgeInsets.symmetric(vertical: 4),
decoration: BoxDecoration(
color: Colors.red.shade400,
borderRadius: BorderRadius.circular(12),
),
alignment: Alignment.centerRight,
padding: const EdgeInsets.symmetric(horizontal: 20),
child: const Icon(Icons.delete, color: Colors.white),
),
confirmDismiss: (direction) async {
return await showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: const Text("Delete Transaction"),
content: const Text("Do you want to delete this transaction?"),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(false),
child: const Text("Cancel"),
),
TextButton(
onPressed: () => Navigator.of(context).pop(true),
child: const Text("Delete"),
),
],
);






