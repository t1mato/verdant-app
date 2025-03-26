import 'package:flutter/material.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report")),
      body: const Center(
        child: Text(
          "Report Page Content",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
