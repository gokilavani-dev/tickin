// ignore_for_file: unused_import

import 'package:book_yours/screens/driver_orders.dart';
import 'package:flutter/material.dart';

import 'create_order_screen.dart';
import 'slots/slot_booking_screen.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Dashboard")),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _card(context, Icons.account_tree, "My Orders", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverOrdersScreen()),
            );
          }),
          _card(context, Icons.add_box_rounded, "Create Order", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext ctx,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
