import 'package:flutter/material.dart';
import '../models/slot_models.dart';

class SlotRulesCard extends StatelessWidget {
  final SlotRules rules;
  final bool isManager;
  final VoidCallback? onEditThreshold;
  final VoidCallback? onToggleNightSlot;

  // ✅ NEW: location selector inputs
  final String? selectedLocationId; // "1".."6"
  final ValueChanged<String?>? onLocationChanged;

  const SlotRulesCard({
    super.key,
    required this.rules,
    this.isManager = false,
    this.onEditThreshold,
    this.onToggleNightSlot,

    // ✅ NEW
    this.selectedLocationId,
    this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Threshold
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Threshold: ₹${rules.maxAmount.toStringAsFixed(0)}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (isManager)
                  ElevatedButton(
                    onPressed: onEditThreshold,
                    child: const Text("Edit"),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ✅ Night Slot toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Night Slot Enabled: ${rules.lastSlotEnabled ? "YES" : "NO"}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (isManager)
                  OutlinedButton(
                    onPressed: onToggleNightSlot,
                    child: Text(rules.lastSlotEnabled ? "Disable" : "Enable"),
                  )
              ],
            ),

            const SizedBox(height: 8),
            Text(
              "Night slot opens after: ${rules.lastSlotOpenAfter}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
