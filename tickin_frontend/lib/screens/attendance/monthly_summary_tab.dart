import 'package:flutter/material.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../../app_scope.dart';

class MonthlySummaryTab extends StatefulWidget {
  const MonthlySummaryTab({super.key});

  @override
  State<MonthlySummaryTab> createState() => _MonthlySummaryTabState();
}

class _MonthlySummaryTabState extends State<MonthlySummaryTab> {
  bool calculating = false;
  List users = [];

  DateTime? selectedMonth;

  // 📅 Pick Month (using date picker)
  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(
      context: context,
      initialDate: selectedMonth ?? DateTime.now(),
      firstDate: DateTime(2024, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  // 🚀 APPLY MONTHLY FILTER
  Future<void> _applyFilter() async {
    if (selectedMonth == null) return;

    setState(() {
      calculating = true;
      users = [];
    });

    final api = TickinAppScope.of(context).attendanceDashboardApi;
    final Map<String, dynamic> map = {};

    final firstDay = DateTime(selectedMonth!.year, selectedMonth!.month, 1);
    final lastDay = DateTime(selectedMonth!.year, selectedMonth!.month + 1, 0);

    int totalWorkingDays = 0;

    DateTime d = firstDay;
    while (!d.isAfter(lastDay)) {
      // ❌ Skip Sunday
      if (d.weekday != DateTime.sunday) {
        totalWorkingDays++;

        final date =
            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

        final res = await api.attendanceByDate(date: date);

        for (final r in res["data"] ?? []) {
          final uid = r["PK"] ?? "USER#${r["userName"]}";

          map.putIfAbsent(
            uid,
            () => {
              "name": r["userName"],
              "role": r["attendanceRole"] ?? r["role"] ?? "-",
              "presentDays": 0,
            },
          );

          map[uid]["presentDays"]++;
        }
      }

      d = d.add(const Duration(days: 1));
    }

    setState(() {
      users = map.values
          .map(
            (u) => {
              ...u,
              "totalDays": totalWorkingDays,
              "absentDays": totalWorkingDays - u["presentDays"],
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
        // 📅 MONTH FILTER
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: _pickMonth,
                child: Text(
                  selectedMonth == null
                      ? "Select Month"
                      : "Month: ${selectedMonth!.year}-${selectedMonth!.month.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
              columns: const [
                DataColumn(label: Text("Name")),
                DataColumn(label: Text("Role")),
                DataColumn(label: Text("Total Days")),
                DataColumn(label: Text("Present")),
                DataColumn(label: Text("Absent")),
              ],
              rows: users.map<DataRow>((u) {
                return DataRow(
                  cells: [
                    DataCell(Text(u["name"])),
                    DataCell(Text(u["role"])),
                    DataCell(Text("${u["totalDays"]}")),
                    DataCell(
                      Text(
                        "${u["presentDays"]}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(Text("${u["absentDays"]}")),
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
