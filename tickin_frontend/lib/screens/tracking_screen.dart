// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'order_unified_tracking_screen.dart';

class TrackingScreen extends StatelessWidget {
  final List<String> distributorCodes;
  final String role;

  const TrackingScreen({
    super.key,
    required this.distributorCodes,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final codesText =
        distributorCodes.isEmpty ? "No distributor assigned" : distributorCodes.join(", ");

    return Scaffold(
      appBar: AppBar(title: const Text("Tracking")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Role: $role", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text("Distributor Codes: $codesText"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
