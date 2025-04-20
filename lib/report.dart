import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  CategoryInfo(this.name, this.icon, this.color);
}

final List<CategoryInfo> availableCategories = [
  CategoryInfo("Food", Icons.fastfood, Colors.orange),
  CategoryInfo("Bills", Icons.receipt, Colors.blue),
  CategoryInfo("Entertainment", Icons.movie, Colors.purple),
  CategoryInfo("Transport", Icons.directions_car, Colors.teal),
  CategoryInfo("Shopping", Icons.shopping_cart, Colors.pink),
];

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  Future<List<_ChartData>> _fetchCategoryTotals() async {
    final txSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .get();

    final Map<String, double> categoryTotals = {};

    for (var doc in txSnapshot.docs) {
      final data = doc.data();
      final category = data['category'] ?? 'Unknown';
      final amount = (data['amount'] ?? 0).toDouble();
      categoryTotals.update(category, (value) => value + amount, ifAbsent: () => amount);
    }

    return categoryTotals.entries.map((entry) {
      final categoryInfo = availableCategories.firstWhere(
            (cat) => cat.name == entry.key,
        orElse: () => CategoryInfo(entry.key, Icons.category, Colors.grey),
      );
      return _ChartData(entry.key, entry.value, categoryInfo.color);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report")),
      body: FutureBuilder<List<_ChartData>>(
        future: _fetchCategoryTotals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No data to display."));
          }

          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SfCircularChart(
              title: ChartTitle(text: 'Expenses by Category'),
              legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <PieSeries<_ChartData, String>>[
                PieSeries<_ChartData, String>(
                  dataSource: data,
                  xValueMapper: (_ChartData d, _) => d.label,
                  yValueMapper: (_ChartData d, _) => d.amount,
                  pointColorMapper: (_ChartData d, _) => d.color,
                  dataLabelMapper: (_ChartData d, _) => '\$${d.amount.toStringAsFixed(2)}',
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                )
              ],
            ),
          );
        },
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




