import 'package:flutter/material.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Summary")),
      body: const Center(
        child: Text(
          "Summary Page Content",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
