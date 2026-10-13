import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

class UniversityComparisonGrid extends StatefulWidget {
  final List<Map<String, dynamic>> universities;
  final String Function(Map<String, dynamic>, String) value;
  const UniversityComparisonGrid(
      {super.key, required this.universities, required this.value});

  @override
  State<UniversityComparisonGrid> createState() =>
      _UniversityComparisonGridState();
}

class _UniversityComparisonGridState extends State<UniversityComparisonGrid> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Widget cell(String text, {bool header = false, bool label = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
        child: Text(text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              height: 1.6,
              fontWeight: header || label ? FontWeight.w700 : FontWeight.w500,
              color: header
                  ? Colors.white
                  : label
                      ? AppColors.navy
                      : AppColors.textPrimary,
            )),
      );

  @override
  Widget build(BuildContext context) {
    const fields = {
      'country': 'الدولة',
      'city': 'المدينة',
      'language': 'لغة الدراسة',
      'ranking': 'التصنيف',
      'tuitionRange': 'نطاق الرسوم',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Icon(Icons.swipe_rounded, size: 18, color: AppColors.orange),
            SizedBox(width: 8),
            Expanded(
                child: Text('اسحب الجدول أفقيًا لعرض جميع الجامعات',
                    style: AppTextStyles.caption)),
          ])),
      LayoutBuilder(builder: (context, constraints) {
        final width = (124 + widget.universities.length * 174).toDouble();
        return Scrollbar(
          controller: scroll,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: width < constraints.maxWidth
                      ? constraints.maxWidth
                      : width,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16)),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {0: FixedColumnWidth(124)},
                    border: const TableBorder(
                        horizontalInside: BorderSide(color: AppColors.border),
                        verticalInside: BorderSide(color: AppColors.border)),
                    children: [
                      TableRow(
                          decoration:
                              const BoxDecoration(color: AppColors.navy),
                          children: [
                            cell('وجه المقارنة', header: true),
                            for (final university in widget.universities)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 20),
                                  child: Column(children: [
                                    Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: .12),
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: const Icon(
                                            Icons.account_balance_rounded,
                                            color: AppColors.orange,
                                            size: 23)),
                                    const SizedBox(height: 10),
                                    Text('${university['name']}',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.cardTitle.copyWith(
                                            color: Colors.white, height: 1.5)),
                                  ])),
                          ]),
                      for (final entry in fields.entries.indexed)
                        TableRow(
                            decoration: BoxDecoration(
                                color: entry.$1.isEven
                                    ? Colors.white
                                    : AppColors.background),
                            children: [
                              cell(entry.$2.value, label: true),
                              for (final university in widget.universities)
                                cell(widget.value(university, entry.$2.key)),
                            ]),
                    ],
                  ),
                )),
          ),
        );
      }),
    ]);
  }
}
