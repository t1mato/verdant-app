import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double totalBudget = 1000.0;
  double currentBalance = 650.0;
  Map<String, double> categories = {
    "Food": 200.0,
    "Bills": 300.0,
    "Entertainment": 150.0,
  };

  void _addCategory() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController categoryController = TextEditingController();
        TextEditingController amountController = TextEditingController();

        return AlertDialog(
          title: const Text("Add Category"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: "Category Name"),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  String category = categoryController.text.trim();
                  double amount = double.tryParse(amountController.text) ?? 0.0;

                  if (category.isNotEmpty && amount > 0) {
                    categories[category] = amount;
                    currentBalance -= amount;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _deleteCategory(String category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Category"),
          content: Text("Are you sure you want to delete '$category'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  currentBalance += categories[category] ?? 0.0;
                  categories.remove(category);
                });
                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double percentage = (currentBalance / totalBudget).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            CircularPercentIndicator(
              radius: 120.0,
              lineWidth: 13.0,
              percent: percentage,
              center: Text(
                "\$${currentBalance.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              progressColor: Colors.green,
              backgroundColor: Colors.grey[300]!,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: categories.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.key),
                    trailing: Text("\$${entry.value.toStringAsFixed(2)}"),
                    onLongPress: () => _deleteCategory(entry.key),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}




