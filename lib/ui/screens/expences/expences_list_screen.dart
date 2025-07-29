// lib/screens/expense_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mauzo/controllers/expence_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import '../../../controllers/business_controller.dart';
import '../../../models/expences.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../../widgets/dashed_seperator.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({Key? key}) : super(key: key);

  @override
  _ExpenseListScreenState createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final ExpenseController _expenseController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  String selectedCategory = 'All';
  DateTimeRange? selectedDateRange;

  @override
  void initState() {
    super.initState();

    // Set default DateTimeRange using reset_time from ProfileController
    if (_businessController.business['reset_time'] != null) {
      DateTime resetTime = _businessController.business['reset_time'].toDate();
      selectedDateRange = DateTimeRange(
        start: resetTime,
        end: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageExpenses = _profileController.hasPermission('manage_expenses');
    
    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      floatingActionButton: canManageExpenses ? FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-expense');
        },
        child: const Icon(Icons.add),
      ) : null,
      appBar: AppBar(
        title: Text('expenses'.tr),
        elevation: 0,
      ),
      body: Obx(() {
        if (_expenseController.expenses.isEmpty) {
          return Center(child: Text('No expenses yet!'.tr));
        }

        List<Expense> filteredExpenses = _expenseController.expenses;

        if (selectedCategory != 'All'.tr) {
          filteredExpenses = filteredExpenses.where((expense) {
            return expense.category == selectedCategory;
          }).toList();
        }

        if (selectedDateRange != null) {
          filteredExpenses = filteredExpenses.where((expense) {
            DateTime expenseDate = expense.date.toDate();
            return expenseDate.isAfter(selectedDateRange!.start) &&
                expenseDate.isBefore(selectedDateRange!.end.add(Duration(days: 1)));
          }).toList();
        }

        final groupedExpenses = groupExpensesByDate(filteredExpenses);

        return Column(
          children: [
            _buildFilterOptions(context),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: groupedExpenses.length,
                itemBuilder: (context, index) {
                  final date = groupedExpenses.keys.elementAt(index);
                  final expenses = groupedExpenses[date]!;

                  return StickyHeader(
                    header: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.maxFinite,
                      height: 48,
                      color: const Color(0xFFFFEA9F),
                      child: Row(
                        children: [
                          Text(
                            DateFormat("dd.MM.yyyy", 'en_US').format(date),
                            style: h5(textDarkColor),
                          ),
                          const Spacer(),
                          Text(
                            '${'Total'.tr}: ${formatCurrency(
                              expenses.fold<double>(0, (sum, e) => sum + ((e.amount is int) ? (e.amount as int).toDouble() : (e.amount ?? 0))),
                              _businessController.business['mainCurrency']
                            )}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textPlaceholderColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    content: Column(
                      children: expenses.map((expense) {
                        final time = expense.date;
                        return Container(
                          color: Preferences.getTheme() ? mediumGrayColor : whiteColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat("hh:mm a", 'en_US').format(time.toDate()),
                                    style: h6(
                                      Theme.of(context).textTheme.bodyLarge!.color,
                                    ),
                                  ),
                                  const Spacer(),
                                  PopupMenuButton(
                                    child: Icon(
                                      Icons.more_vert,
                                      color: Preferences.getTheme()
                                          ? primaryLightColor
                                          : primaryColor,
                                      size: 24,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'Delete') {
                                        _expenseController.deleteExpense(expense.id);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'Delete',
                                        child: Text(
                                          'Delete',
                                          style: bodyText(redColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                expense.title,
                                style: bodyText(
                                  Theme.of(context).textTheme.bodyLarge!.color,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const DashedSeperator(),
                              const SizedBox(height: 12),
                              Text(
                                '${'Amount'.tr}: ${formatCurrency(
                                  (expense.amount is int) ? (expense.amount as int).toDouble() : (expense.amount ?? 0),
                                  _businessController.business['mainCurrency']
                                )}',
                                style: h6(Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

// (Rest of the class remains unchanged)



  Widget _buildFilterOptions(BuildContext context) {
    return Container(
      color: Preferences.getTheme() ? Theme.of(context).scaffoldBackgroundColor : whiteColor,
      height: 40,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        children: [
          selectedCategory != 'All' || selectedDateRange != null
              ? Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = 'All';
                    selectedDateRange = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.cancel,
                    color: Preferences.getTheme() ? lightGrayColor : iconGrayColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          )
              : Container(),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => SelectCategoryDialog(
                  selectedCategory: selectedCategory,
                  onCategorySelected: (category) {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    selectedCategory,
                    style: bodyText(
                      Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    color: iconGrayColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              ).then(
                    (DateTimeRange? value) {
                  if (value != null) {
                    setState(() {
                      selectedDateRange = value;
                    });

                    final String range =
                        '${DateFormat('dd/MM/yyyy').format(value.start)} - ${DateFormat('dd/MM/yyyy').format(value.end)}';
                    successSnackbar("${'Date'.tr}: $range");
                  }
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    selectedDateRange != null
                        ? '${DateFormat('dd/MM/yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.end)}'
                        : 'Any Date'.tr,
                    style: bodyText(
                      Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    color: iconGrayColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<Expense>> groupExpensesByDate(List<Expense> expenses) {
    final Map<DateTime, List<Expense>> groupedExpenses = {};
    for (var expense in expenses) {
      final date = DateTime(expense.date.toDate().year, expense.date.toDate().month, expense.date.toDate().day);
      if (groupedExpenses.containsKey(date)) {
        groupedExpenses[date]!.add(expense);
      } else {
        groupedExpenses[date] = [expense];
      }
    }
    return groupedExpenses;
  }
}

class SelectCategoryDialog extends StatefulWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  SelectCategoryDialog({required this.selectedCategory, required this.onCategorySelected});

  @override
  _SelectCategoryDialogState createState() => _SelectCategoryDialogState();
}
class _SelectCategoryDialogState extends State<SelectCategoryDialog> {
  late String localSelectedCategory;

  @override
  void initState() {
    localSelectedCategory = widget.selectedCategory;
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    final categories = ['All'.tr, 'Food'.tr, 'Transport'.tr, 'Electricity'.tr, 'Water'.tr, 'TV bills'.tr, 'Other'.tr];

    return AlertDialog(
      title: Text('Select Category'.tr),
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.map((category) {
          return RadioListTile(
            contentPadding: EdgeInsets.zero,
            value: category,
            title: Text(category.tr),
            groupValue: localSelectedCategory,
            activeColor: Preferences.getTheme() ? primaryLightColor : primaryColor,
            onChanged: (String? value) {
              setState(() {
                localSelectedCategory = value!;
              });
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Cancel'.tr),
        ),
        TextButton(
          onPressed: () {
            widget.onCategorySelected(localSelectedCategory);
            Navigator.pop(context);
          },
          child: Text('Apply'.tr),
        ),
      ],
    );
  }
}


