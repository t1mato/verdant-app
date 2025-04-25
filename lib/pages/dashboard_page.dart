import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double? totalBudget;
  double currentBalance = 0.0;
  List<TransactionItem> transactions = [];
  bool isLoading = true;
  bool isMonthly = true;
  DateTime selectedMonth = DateTime.now();

  // Add this property to track connectivity status
  bool _isOffline = true; // Start assuming offline until checked

// Add this method to check connectivity
  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _isOffline = connectivityResult == ConnectivityResult.none;
      });
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      // Keep _isOffline as true if there's an error checking
    }
  }

  // Check if selected month is current month
  bool get isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  // Formatting utilities
  final currencyFormat = NumberFormat.currency(symbol: '\$');
  final dateFormat = DateFormat('MMM d');
  final monthFormat = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    _checkConnectivity(); // Check connectivity when page loads

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        debugPrint('User authenticated, loading data...');
        _loadData();
      } else {
        debugPrint('No user authenticated, redirecting to login...');
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      debugPrint('Loading dashboard data...');
      // Get database service
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      // Load user preferences
      final userPrefs = await dbService.getUserPreferences();
      debugPrint('User preferences loaded: budget=${userPrefs.totalBudget}, isMonthly=${userPrefs.isMonthlyBudget}');

      // Load transactions for current month
      final dateRange = DateRange.forMonth(selectedMonth);
      debugPrint('Fetching transactions for date range: ${dateRange.startDate} to ${dateRange.endDate}');

      final transactionsList = await dbService.getTransactionsStream(dateRange).first;
      debugPrint('Transactions loaded: ${transactionsList.length} items');

      setState(() {
        totalBudget = userPrefs.totalBudget;
        isMonthly = userPrefs.isMonthlyBudget;
        transactions = transactionsList;

        // Calculate current balance
        double spent = 0.0;
        for (var tx in transactions) {
          spent += tx.amount;
        }

        currentBalance = totalBudget != null
            ? (totalBudget! - spent).clamp(0, totalBudget!)
            : 0;

        isLoading = false;
        debugPrint('Dashboard state updated: totalBudget=$totalBudget, currentBalance=$currentBalance');
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => isLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (selectedMonth.year < now.year ||
        (selectedMonth.year == now.year && selectedMonth.month < now.month)) {
      setState(() {
        selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
      });
      _loadData();
    }
  }

  // Budget dialog methods
  void _setBudget() => _setBudgetDialog('Set Budget', null);
  void _editBudget() => _setBudgetDialog('Edit Budget', totalBudget);

  void _setBudgetDialog(String title, double? initialValue) {
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
                    TextField(
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
                      final enteredBudget = double.tryParse(
                          budgetController.text);
                      if (enteredBudget != null && enteredBudget > 0) {
                        try {
                          // Get the database service directly
                          final dbService = Provider.of<DatabaseService>(
                              context, listen: false);

                          // Explicitly log the operation
                          debugPrint(
                              'Updating budget: $enteredBudget, isMonthly: $localIsMonthly');

                          // Update the budget
                          await dbService.updateBudget(
                              enteredBudget, localIsMonthly);

                          // Update local state
                          setState(() {
                            totalBudget = enteredBudget;
                            isMonthly = localIsMonthly;
                          });

                          // Show a success message
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(
                                  'Budget updated successfully'))
                          );

                          Navigator.pop(context);
                          // Reload data to make sure UI reflects the changes
                          _loadData();
                        } catch (e) {
                          // Show the error
                          debugPrint('Error updating budget: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(
                                  'Error updating budget: ${e.toString()}'))
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(
                                'Please enter a valid amount'))
                        );
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

  // Quick add transaction UI
  void _quickAdd(BuildContext context) {
    // Don't allow adding transactions for past months
    if (!isCurrentMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transactions can only be added for the current month'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        double amount = 0;
        CategoryInfo selectedCategory = availableCategories[0];
        final nameController = TextEditingController(); // Add controller for transaction label

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
                    // Add a field for transaction label
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Label (optional)",
                        hintText: "Enter a description",
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedCategory.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: amount > 0 ? () async {
                          try {
                            debugPrint('==== QUICK ADD TRANSACTION START ====');
                            debugPrint('Amount: $amount, Category: ${selectedCategory.name}');

                            final dbService = Provider.of<DatabaseService>(context, listen: false);
                            debugPrint('DatabaseService retrieved, userID: ${dbService.userId}');

                            // Use label if provided, otherwise use category name
                            final transactionName = nameController.text.trim().isNotEmpty
                                ? nameController.text.trim()
                                : selectedCategory.name;
                            debugPrint('Transaction name: $transactionName');

                            final tx = TransactionItem(
                              id: '', // Will be assigned by Firebase
                              name: transactionName,
                              amount: amount,
                              category: selectedCategory,
                              date: DateTime.now(),
                            );
                            debugPrint('TransactionItem created');

                            final String txId = await dbService.addTransaction(tx);
                            debugPrint('Transaction added with ID: $txId');

                            Navigator.pop(context);
                            debugPrint('Bottom sheet closed');

                            debugPrint('Calling _loadData() to refresh');
                            await _loadData(); // Refresh data
                            debugPrint('==== QUICK ADD TRANSACTION COMPLETE ====');
                          } catch (e) {
                            debugPrint('==== QUICK ADD TRANSACTION ERROR ====');
                            debugPrint(e.toString());
                            debugPrint(StackTrace.current.toString());

                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}'))
                            );
                          }
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

  // Add full transaction with fixed dialog layout
  void _addNewTransaction() {
    // Don't allow adding transactions for past months
    if (!isCurrentMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transactions can only be added for the current month'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
            content: Container(
              width: double.maxFinite,
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
                  // Replace GridView with a Wrap widget to prevent scrolling issues
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: availableCategories.map((category) {
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            selectedCategory = category;
                          });
                        },
                        child: Container(
                          width: 60,
                          height: 60,
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
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(DateFormat('EEE, MMM d').format(selectedDate)),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final now = DateTime.now();
                      // Only allow selecting dates in the current month
                      final firstDayOfMonth = DateTime(now.year, now.month, 1);
                      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: firstDayOfMonth,
                        lastDate: lastDayOfMonth,
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
                  if (transactionName.isEmpty) {
                    transactionName = selectedCategory?.name ?? 'Expense';
                  }

                  double amount = double.tryParse(amountController.text) ?? 0.0;

                  if (selectedCategory != null && amount > 0) {
                    try {
                      final dbService = Provider.of<DatabaseService>(context, listen: false);

                      final tx = TransactionItem(
                        id: '', // Will be assigned by Firebase
                        name: transactionName,
                        amount: amount,
                        category: selectedCategory!,
                        date: selectedDate,
                      );

                      await dbService.addTransaction(tx);
                      Navigator.pop(context);
                      _loadData(); // Refresh data
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding transaction: ${e.toString()}'))
                      );
                    }
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            Icons.edit,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Edit",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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
    return Dismissible(
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
      // Only allow deleting transactions in the current month
      direction: isCurrentMonth ? DismissDirection.horizontal : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (!isCurrentMonth) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transactions from previous months cannot be deleted'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }

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
          },
        );
      },
      onDismissed: (_) async {
        try {
          final dbService = Provider.of<DatabaseService>(context, listen: false);
          await dbService.deleteTransaction(tx.id);
          _loadData(); // Refresh data
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting transaction: ${e.toString()}'))
          );
        }
      },
      child: Card(
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
                DateFormat('MMM d, h:mm a').format(tx.date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          // Allow editing transaction only in current month
          onTap: isCurrentMonth ? () => _editTransaction(tx) : null,
        ),
      ),
    );
  }

  void _editTransaction(TransactionItem tx) {
    final nameController = TextEditingController(text: tx.name);
    final amountController = TextEditingController(text: tx.amount.toString());
    CategoryInfo selectedCategory = tx.category;
    DateTime selectedDate = tx.date;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return Dialog(
                // Use Dialog instead of AlertDialog for more flexible sizing
                insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Important for proper sizing
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Row(
                        children: [
                          Icon(Icons.edit, size: 24),
                          SizedBox(width: 8),
                          Text("Edit Transaction", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description field
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Description",
                          prefixIcon: Icon(Icons.short_text),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount field
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

                      // Category label
                      const Text("Category", style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),

                      // Categories - simplified to fit dialog properly
                      Container(
                        height: 120, // Fixed height prevents layout issues
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(), // Prevents scrolling
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: availableCategories.length > 8 ? 8 : availableCategories.length, // Limit visible categories
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
                                  color: selectedCategory.name == category.name
                                      ? category.color.withOpacity(0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedCategory.name == category.name
                                        ? category.color
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(category.icon, color: category.color, size: 20),
                                    const SizedBox(height: 2),
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: category.color,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date picker
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final firstDayOfMonth = DateTime(now.year, now.month, 1);
                          final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: firstDayOfMonth,
                            lastDate: lastDayOfMonth,
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18),
                              const SizedBox(width: 8),
                              Text(DateFormat('EEE, MMM d').format(selectedDate)),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel")
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              String transactionName = nameController.text.trim();
                              if (transactionName.isEmpty) {
                                transactionName = selectedCategory.name;
                              }

                              double amount = double.tryParse(amountController.text) ?? 0.0;

                              if (amount > 0) {
                                try {
                                  final dbService = Provider.of<DatabaseService>(context, listen: false);

                                  final updatedTx = TransactionItem(
                                    id: tx.id,
                                    name: transactionName,
                                    amount: amount,
                                    category: selectedCategory,
                                    date: selectedDate,
                                  );

                                  await dbService.updateTransaction(updatedTx);
                                  Navigator.pop(context);
                                  _loadData(); // Refresh data
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error updating transaction: ${e.toString()}'))
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill all fields correctly')),
                                );
                              }
                            },
                            child: const Text("Update"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildShortcutButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: _checkConnectivity, // Check again when tapped
              child: Icon(
                _isOffline ? Icons.cloud_off : Icons.cloud_done,
                color: _isOffline ? Colors.red : Colors.green,
              ),
            ),
          ),
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isMonthly)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _previousMonth,
                      ),
                      Text(
                        monthFormat.format(selectedMonth),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                const Spacer(),
                // Only show add transaction button if viewing current month
                if (isCurrentMonth)
                  TextButton.icon(
                    onPressed: _addNewTransaction,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Add Transaction"),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
              // Message for past months view
              if (!isCurrentMonth)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "You are viewing data for ${monthFormat.format(selectedMonth)}. Transactions cannot be added or modified for past months.",
                          style: const TextStyle(color: Colors.blue, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              // Only show welcome screen if budget is not set
              if (totalBudget == null)
                Center(
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
                        "Welcome to Verdant!",
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
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget indicator
                    _buildBudgetIndicator(),
                    const SizedBox(height: 24),

                    // Quick access shortcuts - Only show if viewing current month
                    if (isCurrentMonth)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Quick Access",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // Add expense shortcut
                                  _buildShortcutButton(
                                    "Add\nExpense",
                                    Icons.add_shopping_cart,
                                    Colors.orange,
                                        () => _quickAdd(context),
                                  ),
                                  // Go to reports
                                  _buildShortcutButton(
                                    "View\nReports",
                                    Icons.bar_chart,
                                    Colors.purple,
                                        () => Navigator.pushNamed(context, '/reports'),
                                  ),
                                  // Go to summary
                                  _buildShortcutButton(
                                    "View\nSummary",
                                    Icons.summarize,
                                    Colors.teal,
                                        () => Navigator.pushNamed(context, '/summary'),
                                  ),
                                  // Edit budget
                                  _buildShortcutButton(
                                    "Edit\nBudget",
                                    Icons.edit_note,
                                    Colors.blue,
                                    _editBudget,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isCurrentMonth) const SizedBox(height: 24),

                    // Recent transactions section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Transactions",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isCurrentMonth)
                          Text(
                            monthFormat.format(selectedMonth),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Show transactions or empty state
                    transactions.isEmpty
                        ? Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No transactions yet",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (isCurrentMonth)
                                ElevatedButton.icon(
                                  onPressed: () => _quickAdd(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text("Add Your First Transaction"),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                        : Column(
                      children: [
                        ...transactions
                            .take(5)
                            .map((tx) => _buildTransactionItem(tx))
                            .toList(),
                        if (transactions.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushNamed(context, '/transactions'),
                              child: const Text("View All Transactions"),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: (totalBudget == null || !isCurrentMonth)
          ? null
          : FloatingActionButton(
        onPressed: () => _quickAdd(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}