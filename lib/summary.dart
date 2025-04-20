import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late Future<List<Map<String, dynamic>>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _fetchTransactions();
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    final txSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .get();

    return txSnapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Summary")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No transactions found."));
          }

          final transactions = snapshot.data!;
          final now = DateTime.now();

          // Group by day
          Map<String, List<Map<String, dynamic>>> dailyGroups = {};
          for (var tx in transactions) {
            final txDate = tx['timestamp'] != null
                ? (tx['timestamp'] as Timestamp).toDate()
                : now;
            final dateKey = DateFormat('yyyy-MM-dd').format(txDate);
            dailyGroups.putIfAbsent(dateKey, () => []).add(tx);
          }

          double totalSpent = 0;
          double todaySpent = 0;
          double currentWeekSpent = 0;
          int streak = 0;
          final today = DateFormat('yyyy-MM-dd').format(now);
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

          List<DateTime> sortedDates = dailyGroups.keys
              .map((d) => DateTime.parse(d))
              .toList()
            ..sort((a, b) => b.compareTo(a));

          for (var entry in transactions) {
            final amount = (entry['amount'] ?? 0).toDouble();
            final txDate = entry['timestamp'] != null
                ? (entry['timestamp'] as Timestamp).toDate()
                : now;
            final formatted = DateFormat('yyyy-MM-dd').format(txDate);

            totalSpent += amount;

            if (formatted == today) {
              todaySpent += amount;
            }
            if (txDate.isAfter(startOfWeek) || txDate.isAtSameMomentAs(startOfWeek)) {
              currentWeekSpent += amount;
            }
          }

          for (var date in sortedDates) {
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            if (dailyGroups[dateKey]!.isNotEmpty) {
              streak++;
            } else {
              break;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Time-Based Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Total Spent: \$${totalSpent.toStringAsFixed(2)}"),
                Text("Today: \$${todaySpent.toStringAsFixed(2)}"),
                Text("This Week: \$${currentWeekSpent.toStringAsFixed(2)}"),
                const SizedBox(height: 20),

                const Text("Smart Insights", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (todaySpent > 0.3 * totalSpent)
                  const Text("\u26A0 You spent over 30% of your budget today!", style: TextStyle(color: Colors.red)),
                if (currentWeekSpent > 0.7 * totalSpent)
                  const Text("\u26A0 You're close to your weekly budget limit.", style: TextStyle(color: Colors.orange)),
                const SizedBox(height: 20),

                const Text("Spending Streak", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("You've recorded transactions for $streak day(s) in a row."),
              ],
            ),
          );
        },
      ),
    );
  }
}
