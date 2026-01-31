import 'package:flutter/material.dart';
import '../../app_scope.dart';

class WeeklySummaryTab extends StatefulWidget {
  const WeeklySummaryTab({super.key});

  @override
  State<WeeklySummaryTab> createState() => _WeeklySummaryTabState();
}

class _WeeklySummaryTabState extends State<WeeklySummaryTab> {
  bool calculating = false;
  List users = [];

  DateTime? fromDate;
  DateTime? toDate;

  Future<void> _pickFromDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: fromDate ?? DateTime.now(),
    );
    if (d != null) setState(() => fromDate = d);
  }

  Future<void> _pickToDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: toDate ?? DateTime.now(),
    );
    if (d != null) setState(() => toDate = d);
  }

  Future<void> _applyFilter() async {
    if (fromDate == null || toDate == null) return;

    setState(() {
      calculating = true;
      users = [];
    });

    final api = TickinAppScope.of(context).attendanceDashboardApi;
    final Map<String, dynamic> map = {};

    DateTime d = fromDate!;
    while (!d.isAfter(toDate!)) {
      final date =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      final res = await api.attendanceByDate(date: date);

      for (final r in res["data"] ?? []) {
        final uid = r["PK"] ?? "USER#${r["userName"]}";
        map.putIfAbsent(
          uid,
          () => {
            "name": r["userName"],
            // 🔥 USE attendanceRole FIRST
            "role": r["attendanceRole"] ?? r["role"] ?? "-",
            "presentDays": 0,
            "office2Visits": 0, // 🔥 ADD THIS
            "totalBata": 0,
            "nightAllowance": 0,
          },
        );
        if (r["locationId"] == "OFFICE2") {
          map[uid]["office2Visits"]++;
        }
        map[uid]["presentDays"]++;
        map[uid]["totalBata"] += r["bataAmount"] ?? 0;
        map[uid]["nightAllowance"] += r["nightAllowance"] ?? 0;
      }

      d = d.add(const Duration(days: 1));
    }

    final days = toDate!.difference(fromDate!).inDays + 1;

    setState(() {
      users = map.values
          .map(
            (u) => {
              ...u,
              "absentDays": days - u["presentDays"],
              "totalAmount": u["totalBata"] + u["nightAllowance"],
            },
          )
          .toList();
      calculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (calculating) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 📅 FILTER
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _pickFromDate,
                    child: Text(
                      "From: ${fromDate?.toString().split(' ')[0] ?? 'Select'}",
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                  ),
                  InkWell(
                    onTap: _pickToDate,
                    child: Text(
                      "To: ${toDate?.toString().split(' ')[0] ?? 'Select'}",
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _applyFilter,
                child: const Text("Apply"),
              ),
            ],
          ),
        ),

        // 📋 TABLE
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.purple.shade100),
              columns: const [
                DataColumn(label: Text("Name")),
                DataColumn(label: Text("Role")),
                DataColumn(label: Text("Present")),
                DataColumn(label: Text("Absent")),
                DataColumn(label: Text("OFFICE2 Days")),
                DataColumn(label: Text("Bata")),
                DataColumn(label: Text("Night")),
                DataColumn(label: Text("Total")),
              ],
              rows: users.map<DataRow>((u) {
                return DataRow(
                  cells: [
                    DataCell(Text(u["name"])),
                    DataCell(Text(u["role"])),
                    DataCell(Text("${u["presentDays"]}")),
                    DataCell(Text("${u["absentDays"]}")),
                    // ✅ IMPORTANT LINE
                    DataCell(
                      Text(
                        "${u["office2Visits"] ?? 0}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(Text("₹${u["totalBata"]}")),
                    DataCell(Text("₹${u["nightAllowance"]}")),
                    DataCell(
                      Text(
                        "₹${u["totalAmount"]}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
