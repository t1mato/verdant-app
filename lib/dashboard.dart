import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  CategoryInfo(this.name, this.icon, this.color);
}

class TransactionItem {
  final String name;
  final double amount;
  final CategoryInfo category;

  TransactionItem({
    required this.name,
    required this.amount,
    required this.category,
  });
}

final List<CategoryInfo> availableCategories = [
  CategoryInfo("Food", Icons.fastfood, Colors.orange),
  CategoryInfo("Bills", Icons.receipt, Colors.blue),
  CategoryInfo("Entertainment", Icons.movie, Colors.purple),
  CategoryInfo("Transport", Icons.directions_car, Colors.teal),
  CategoryInfo("Shopping", Icons.shopping_cart, Colors.pink),
];

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double? totalBudget;
  double currentBalance = 0.0;
  List<TransactionItem> transactions = [];
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (userDoc.exists) {
      final budget = userDoc.data()?['totalBudget'] ?? 0.0;
      final txSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .get();

      setState(() {
        totalBudget = budget;
        currentBalance = budget;
        transactions = txSnapshot.docs.map((doc) {
          final data = doc.data();
          final category = availableCategories.firstWhere(
            (cat) => cat.name == data['category'],
            orElse: () => availableCategories[0],
          );
          currentBalance -= data['amount'];
          return TransactionItem(
            name: data['name'],
            amount: data['amount'],
            category: category,
          );
        }).toList();
      });
    }
  }

  Future<void> _saveBudgetToFirestore() async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'totalBudget': totalBudget,
    });
  }

  Future<void> _addTransactionToFirestore(String name, double amount, String categoryName) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions').add({
      'name': name,
      'amount': amount,
      'category': categoryName,
    });
  }

  void _setBudget() {
    TextEditingController budgetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Set Budget"),
          content: TextField(
            controller: budgetController,
            decoration: const InputDecoration(labelText: "Enter total budget"),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                final enteredBudget = double.tryParse(budgetController.text);
                if (enteredBudget != null && enteredBudget > 0) {
                  setState(() {
                    totalBudget = enteredBudget;
                    currentBalance = enteredBudget;
                  });
                  await _saveBudgetToFirestore();
                  Navigator.pop(context);
                }
              },
              child: const Text("Set"),
            ),
          ],
        );
      },
    );
  }

  void _editBudget() {
    TextEditingController budgetController = TextEditingController(
      text: totalBudget?.toStringAsFixed(2) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Budget"),
          content: TextField(
            controller: budgetController,
            decoration: const InputDecoration(labelText: "New total budget"),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                final newBudget = double.tryParse(budgetController.text);
                if (newBudget != null && newBudget >= 0) {
                  setState(() {
                    double used = totalBudget! - currentBalance;
                    totalBudget = newBudget;
                    currentBalance = (newBudget - used).clamp(0, newBudget);
                  });
                  await _saveBudgetToFirestore();
                  Navigator.pop(context);
                }
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  void _addTransaction() {
    CategoryInfo? selectedCategory;
    TextEditingController amountController = TextEditingController();
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Add Transaction"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Transaction Name"),
                ),
                const SizedBox(height: 10),
                DropdownButton<CategoryInfo>(
                  value: selectedCategory,
                  hint: const Text("Select a category"),
                  isExpanded: true,
                  onChanged: (CategoryInfo? newValue) {
                    setStateDialog(() => selectedCategory = newValue);
                  },
                  items: availableCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon, color: category.color),
                          const SizedBox(width: 10),
                          Text(category.name),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: "Amount"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(
                onPressed: () async {
                  String transactionName = nameController.text.trim();
                  double amount = double.tryParse(amountController.text) ?? 0.0;

                  if (selectedCategory != null && transactionName.isNotEmpty && amount > 0 && currentBalance - amount >= 0) {
                    setState(() {
                      transactions.add(TransactionItem(
                        name: transactionName,
                        amount: amount,
                        category: selectedCategory!,
                      ));
                      currentBalance -= amount;
                    });
                    await _addTransactionToFirestore(transactionName, amount, selectedCategory!.name);
                    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    double percentage = totalBudget != null && totalBudget! > 0
        ? (currentBalance / totalBudget!).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Budget',
            onPressed: _editBudget,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: totalBudget == null
            ? const Center(child: Text("No budget set."))
            : Column(
                children: [
                  CircularPercentIndicator(
                    radius: 120.0,
                    lineWidth: 13.0,
                    percent: percentage,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "\$${currentBalance.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "of \$${totalBudget!.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    progressColor: Colors.green,
                    backgroundColor: Colors.grey[300]!,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: transactions.isEmpty
                        ? const Center(child: Text("No transactions added."))
                        : ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: tx.category.color, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(tx.category.icon, color: tx.category.color),
                                  title: Text(
                                    tx.name,
                                    style: TextStyle(
                                      color: tx.category.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "${tx.category.name} • \$${tx.amount.toStringAsFixed(2)}",
                                    style: TextStyle(color: tx.category.color),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: totalBudget == null ? _setBudget : _addTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}






