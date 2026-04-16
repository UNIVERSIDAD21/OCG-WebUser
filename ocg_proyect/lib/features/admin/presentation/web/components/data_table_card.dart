import 'package:flutter/material.dart';

import '../../../../../shared/theme/ocg_colors.dart';

class DataTableCard extends StatelessWidget {
  const DataTableCard({super.key, required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OcgColors.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.ink.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: OcgColors.bronze.withOpacity(0.18),
            dataTableTheme: DataTableThemeData(
              headingTextStyle: const TextStyle(
                color: OcgColors.espresso,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              dataTextStyle: TextStyle(
                color: OcgColors.ink.withOpacity(0.92),
                fontSize: 13,
              ),
            ),
          ),
          child: DataTable(columns: columns, rows: rows),
        ),
      ),
    );
  }
}
