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
  String selectedPerson = 'All'; // Filter by person who added expense
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
    // Allow all roles except agent to add expenses
    final String userRole = _profileController.user['role'] ?? '';
    final bool canManageExpenses = userRole != 'agent';
    
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

        // Filter by category
        if (selectedCategory != 'All'.tr) {
          filteredExpenses = filteredExpenses.where((expense) {
            return expense.category == selectedCategory;
          }).toList();
        }

        // Filter by person who added the expense
        if (selectedPerson != 'All'.tr) {
          filteredExpenses = filteredExpenses.where((expense) {
            return expense.addedByName == selectedPerson;
          }).toList();
        }

        // Filter by date range
        if (selectedDateRange != null) {
          filteredExpenses = filteredExpenses.where((expense) {
            DateTime expenseDate = expense.date.toDate();
            return expenseDate.isAfter(selectedDateRange!.start) &&
                expenseDate.isBefore(selectedDateRange!.end.add(Duration(days: 1)));
          }).toList();
        }

        final groupedExpenses = groupExpensesByDate(filteredExpenses);

        // Calculate total expenses for filtered results
        final totalExpenses = filteredExpenses.fold<double>(0.0, (sum, expense) => sum + (expense.amount ?? 0.0));
        
        return Column(
          children: [
            _buildFilterOptions(context),
            _buildTotalExpensesSummary(context, totalExpenses, filteredExpenses.length),
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
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Preferences.getTheme() ? mediumGrayColor : whiteColor,
                                  Preferences.getTheme() ? mediumGrayColor.withOpacity(0.8) : whiteColor.withOpacity(0.95),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row with time and menu
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Preferences.getTheme() ? primaryLightColor.withOpacity(0.2) : primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        DateFormat("hh:mm a", 'en_US').format(time.toDate()),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Preferences.getTheme() ? primaryLightColor : primaryColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Category chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        expense.category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Fund source chip with tooltip (shows note when 'other')
                                    Tooltip(
                                      message: expense.fundSource == 'other' && (expense.fundSourceNote.isNotEmpty)
                                          ? expense.fundSourceNote
                                          : 'Source of Funds'.tr,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              size: 12,
                                              color: Colors.purple[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              expense.fundSource == 'mobile'
                                                  ? 'Lipa Namba (Mobile)'.tr
                                                  : (expense.fundSource == 'bank'
                                                      ? 'Bank'.tr
                                                      : (expense.fundSource == 'other'
                                                          ? 'Other Source'.tr
                                                          : 'Cash'.tr)),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.purple[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Only show menu for owners and managers
                                    if (_canEditExpenses())
                                      PopupMenuButton(
                                        child: Icon(
                                          Icons.more_vert,
                                          color: Preferences.getTheme()
                                              ? primaryLightColor
                                              : primaryColor,
                                          size: 20,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'Edit') {
                                            _editExpense(expense);
                                          } else if (value == 'Delete') {
                                            _showDeleteConfirmation(expense);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) =>
                                        <PopupMenuEntry<String>>[
                                          PopupMenuItem<String>(
                                            value: 'Edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, color: Colors.blue, size: 18),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Edit'.tr,
                                                  style: bodyText(Colors.blue),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'Delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: redColor, size: 18),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Delete'.tr,
                                                  style: bodyText(redColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Title
                                Text(
                                  expense.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (expense.fundSource == 'other' && (expense.fundSourceNote.isNotEmpty)) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 14, color: Colors.purple),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          expense.fundSourceNote,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).textTheme.bodyMedium!.color?.withOpacity(0.7),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                const SizedBox(height: 4),
                                // Amount and person info
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Amount'.tr,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).textTheme.bodyMedium!.color?.withOpacity(0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatCurrency(
                                              (expense.amount is int) ? (expense.amount as int).toDouble() : (expense.amount ?? 0),
                                              _businessController.business['mainCurrency']
                                            ),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (expense.addedByName != null && expense.addedByName!.isNotEmpty)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Added by'.tr,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).textTheme.bodyMedium!.color?.withOpacity(0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    size: 14,
                                                    color: Colors.green[700],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    expense.addedByName!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.green[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
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



  Widget _buildTotalExpensesSummary(BuildContext context, double totalExpenses, int expenseCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Expenses'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_businessController.business['mainCurrency'] ?? ''} ${totalExpenses.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOptions(BuildContext context) {
    return Container(
      color: Preferences.getTheme() ? Theme.of(context).scaffoldBackgroundColor : whiteColor,
      height: 40,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        children: [
          selectedCategory != 'All' || selectedPerson != 'All' || selectedDateRange != null
              ? Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = 'All';
                    selectedPerson = 'All';
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
                  expenseController: _expenseController,
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
          // Person Filter
          GestureDetector(
            onTap: () {
              _showPersonFilterDialog(context);
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
                    selectedPerson == 'All' ? 'Any Person'.tr : selectedPerson,
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

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Expense'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this expense?'.tr),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(
                      (expense.amount is int) ? (expense.amount as int).toDouble() : (expense.amount ?? 0),
                      _businessController.business['mainCurrency']
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              _expenseController.deleteExpense(expense.id);
              Navigator.pop(context);
              Get.snackbar(
                'Success'.tr,
                'Expense deleted successfully'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: Text('Delete'.tr, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Check if current user can edit expenses (owner or manager only)
  bool _canEditExpenses() {
    final String userRole = _profileController.user['role'] ?? '';
    return userRole == 'owner' || userRole == 'manager';
  }

  // Navigate to edit expense screen
  void _editExpense(Expense expense) {
    Navigator.pushNamed(
      context,
      '/edit-expense',
      arguments: expense,
    ).then((_) {
      // Refresh the expense list after editing
      setState(() {});
    });
  }

  void _showPersonFilterDialog(BuildContext context) {
    // Get unique list of people who added expenses
    Set<String> uniquePeople = {'All'};
    for (var expense in _expenseController.expenses) {
      if (expense.addedByName != null && expense.addedByName!.isNotEmpty) {
        uniquePeople.add(expense.addedByName!);
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Person'.tr),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: uniquePeople.map((person) {
            return RadioListTile(
              contentPadding: EdgeInsets.zero,
              value: person,
              title: Text(person == 'All' ? 'All People'.tr : person),
              groupValue: selectedPerson,
              activeColor: Preferences.getTheme() ? primaryLightColor : primaryColor,
              onChanged: (String? value) {
                setState(() {
                  selectedPerson = value!;
                });
                Navigator.pop(context);
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
  final ExpenseController expenseController;

  SelectCategoryDialog({
    required this.selectedCategory, 
    required this.onCategorySelected,
    required this.expenseController,
  });

  @override
  _SelectCategoryDialogState createState() => _SelectCategoryDialogState();
}

class _SelectCategoryDialogState extends State<SelectCategoryDialog> {
  late String localSelectedCategory;
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    localSelectedCategory = widget.selectedCategory;
    super.initState();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Select Category'.tr),
          IconButton(
            icon: Icon(Icons.add, color: Colors.green),
            onPressed: _showAddCategoryDialog,
            tooltip: 'Add Category'.tr,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.all(16),
      content: Container(
        width: double.maxFinite,
        child: Obx(() {
          final allCategories = ['All'.tr, ...widget.expenseController.getAllCategories()];
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allCategories.length,
                  itemBuilder: (context, index) {
                    final category = allCategories[index];
                    final isCustom = widget.expenseController.getExpenseCategories().contains(category.replaceAll('.tr', ''));
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Radio<String>(
                        value: category,
                        groupValue: localSelectedCategory,
                        activeColor: Preferences.getTheme() ? primaryLightColor : primaryColor,
                        onChanged: (String? value) {
                          setState(() {
                            localSelectedCategory = value!;
                          });
                        },
                      ),
                      title: Text(category),
                      trailing: isCustom ? IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _confirmDeleteCategory(category.replaceAll('.tr', '')),
                        tooltip: 'Delete Category'.tr,
                      ) : null,
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Custom Category'.tr),
        content: TextField(
          controller: _newCategoryController,
          decoration: InputDecoration(
            labelText: 'Category Name'.tr,
            hintText: 'Enter category name'.tr,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newCategoryController.clear();
              Navigator.pop(context);
            },
            child: Text('Cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              final categoryName = _newCategoryController.text.trim();
              if (categoryName.isNotEmpty) {
                try {
                  await widget.expenseController.addExpenseCategory(categoryName);
                  _newCategoryController.clear();
                  Navigator.pop(context);
                  Get.snackbar(
                    'Success'.tr,
                    'Category added successfully'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error'.tr,
                    'Failed to add category: $e',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              }
            },
            child: Text('Add'.tr),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'.tr),
        content: Text('Are you sure you want to delete "$category"?'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.expenseController.removeExpenseCategory(category);
                Navigator.pop(context);
                Get.snackbar(
                  'Success'.tr,
                  'Category deleted successfully'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar(
                  'Error'.tr,
                  'Failed to delete category: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Delete'.tr, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}


