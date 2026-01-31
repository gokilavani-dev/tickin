import 'package:flutter/material.dart';

class AttendanceTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const AttendanceTable({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        columnSpacing: 18,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
      ),
    );
  }
}
