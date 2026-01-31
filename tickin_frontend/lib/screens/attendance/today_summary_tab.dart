import 'package:flutter/material.dart';
import '../../app_scope.dart';

class TodaySummaryTab extends StatefulWidget {
  const TodaySummaryTab({super.key});

  @override
  State<TodaySummaryTab> createState() => _TodaySummaryTabState();
}

class _TodaySummaryTabState extends State<TodaySummaryTab> {
  bool loading = true;
  List rows = [];

  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  Future<void> _load() async {
    final api = TickinAppScope.of(context).attendanceDashboardApi;
    final res = await api.todayAttendance();

    if (!mounted) return;
    setState(() {
      rows = res["data"] ?? [];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final today = DateTime.now().toString().split(" ")[0];

    return Column(
      children: [
        // 📅 TODAY BOX
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Text(
            "Today : $today",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade700,
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
                DataColumn(label: Text("Office")),
              ],
              rows: rows.map<DataRow>((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r["userName"] ?? "")),
                    DataCell(Text(r["attendanceRole"] ?? r["role"] ?? "")),
                    DataCell(Text(r["checkInAt"] ?? "-")),
                    DataCell(Text(r["checkOutAt"] ?? "-")),
                    DataCell(Text(r["locationId"] ?? "-")),
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
