import 'package:flutter/material.dart';
import '../../app_scope.dart';

class DaywiseSummaryTab extends StatefulWidget {
  const DaywiseSummaryTab({super.key});

  @override
  State<DaywiseSummaryTab> createState() => _DaywiseSummaryTabState();
}

class _DaywiseSummaryTabState extends State<DaywiseSummaryTab> {
  DateTime selected = DateTime.now();
  List rows = [];

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: selected,
    );

    if (d == null) return;

    selected = d;

    final date =
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final api = TickinAppScope.of(context).attendanceDashboardApi;
    final res = await api.attendanceByDate(date: date);

    setState(() => rows = res["data"] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final selectedStr = selected.toString().split(" ")[0];

    return Column(
      children: [
        // 📅 DATE PICKER BOX
        InkWell(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Date : $selectedStr",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                const Icon(Icons.calendar_today),
              ],
            ),
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
                DataColumn(label: Text("Check-In")),
                DataColumn(label: Text("Check-Out")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Office")),
                DataColumn(label: Text("Bata")),
                DataColumn(label: Text("Night")),
              ],
              rows: rows.map<DataRow>((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r["userName"] ?? "")),
                    DataCell(Text(r["attendanceRole"] ?? r["role"] ?? "")),
                    DataCell(Text(r["checkInAt"] ?? "-")),
                    DataCell(Text(r["checkOutAt"] ?? "-")),
                    DataCell(Text(r["status"] ?? "")),
                    DataCell(Text(r["locationId"] ?? "-")),
                    DataCell(Text("₹${r["bataAmount"] ?? 0}")),
                    DataCell(Text("₹${r["nightAllowance"] ?? 0}")),
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
