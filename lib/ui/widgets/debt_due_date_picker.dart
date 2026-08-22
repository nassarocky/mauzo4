import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/utils/sale_debt_due_date.dart';

class DebtDueDatePicker extends StatelessWidget {
  const DebtDueDatePicker({
    Key? key,
    required this.dueDate,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  }) : super(key: key);

  final DateTime dueDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPicked;

  DateTime get _initialDate {
    final start = SaleDebtDueDate.startOfDay(firstDate);
    final end = SaleDebtDueDate.startOfDay(lastDate);
    final current = SaleDebtDueDate.startOfDay(dueDate);
    if (current.isBefore(start)) return start;
    if (current.isAfter(end)) return end;
    return current;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _initialDate,
          firstDate: SaleDebtDueDate.startOfDay(firstDate),
          lastDate: SaleDebtDueDate.startOfDay(lastDate),
        );
        if (picked != null) {
          onPicked(SaleDebtDueDate.startOfDay(picked));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Preferences.getTheme() ? mediumGrayColor : borderColor,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${'sale_debt_due_date'.tr}: ${DateFormat('dd/MM/yyyy').format(dueDate)}',
              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
            ),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}
