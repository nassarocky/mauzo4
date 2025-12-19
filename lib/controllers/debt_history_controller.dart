import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/debtHistory_model.dart';
import '../services/firestore_db.dart';
import 'profile_controller.dart';

class DebtHistoryController extends GetxController {
  final debtHistories = <DebtHistory>[].obs;
  final searchDebtHistories = <DebtHistory>[].obs;
  final searchText = ''.obs;
  final filteredDebtHistories = <DebtHistory>[].obs;
  final filterStatus = <String>[].obs;
  final selectedClient = 'No client'.obs;
  final selectedStatus = 'No status'.obs;
  final RxBool isLoading = false.obs;
  
  // Current status being viewed (default: PENDING for optimization)
  final currentStatus = 'PENDING'.obs;

  StreamSubscription<List<DebtHistory>>? _debtHistorySubscription;

  @override
  void onInit() {
    super.onInit();
    
    final ProfileController _profileController = Get.find();
    final String userRole = _profileController.user['role'] ?? '';
    
    // Load client debts for all roles except agents (cashiers and sales persons need to track client debts)
    if (userRole != 'agent') {
      // Load pending debts by default (optimized)
      loadDebtsByStatus('PENDING');
    } else {
      // Set empty data for agents (no error)
      debtHistories.value = [];
      filteredDebtHistories.value = [];
      print('DebtHistoryController: Agents cannot view client debts, skipping data initialization');
    }
  }

  @override
  void onClose() {
    _debtHistorySubscription?.cancel();
    super.onClose();
  }


  // Method to get a specific debt history by ID
  DebtHistory getDebtHistoryById(String debtId) {
    return debtHistories.firstWhere(
          (debt) => debt.id == debtId,
      orElse: () => DebtHistory(
        client: '',
        name: '',
        owner: '',
        id: '',
        initialDebtAmount: 0.0,
        remainingDebtAmount: 0.0,
        paymentRecords: [],
        dateIncurred: Timestamp.now(),
        status: 'PENDING',
        comment: '',
      ),
    );
  }



  // Switch to different status (queries database) - optimized to reduce reads
  void loadDebtsByStatus(String status) async {
    currentStatus.value = status;
    
    try {
      // Cancel previous subscription
      await _debtHistorySubscription?.cancel();
      
      // Query database for specific status only
      _debtHistorySubscription = FirestoreDb().getDebtHistory(status: status).listen((data) {
        debtHistories.value = data;
        searchDebtHistories.value = data;
        filteredDebtHistories.value = data;
      });
    } catch (e) {
      print("Error loading debts by status $status: $e");
    }
  }
  
  // Filter by debt status (e.g., 'pending', 'paid')
  void filterByStatus(String status) {
    filteredDebtHistories.value = debtHistories.where((debt) {
      return debt.status == status;
    }).toList();
  }
// Search functionality for debt history by client name
  void searchByClientName(String searchValue) {
    searchText.value = searchValue;
    filteredDebtHistories.value = debtHistories
        .where((debt) =>
        debt.name.toLowerCase().contains(searchValue.toLowerCase()))
        .toList();
  }

  // Filter debts based on search and status
  void filteredDebtHistoriesList() {
    filteredDebtHistories.value = debtHistories;

    // Apply search filter
    if (searchText.value.isNotEmpty) {
      filteredDebtHistories.value = debtHistories
          .where((debt) => debt.id
          .toLowerCase()
          .contains(searchText.value.toLowerCase()))
          .toList();
    }

    // Apply status filter if not empty
    if (filterStatus.isNotEmpty) {
      filteredDebtHistories.value = filteredDebtHistories.where((debt) {
        return filterStatus.contains(debt.status);
      }).toList();
    }
  }
  // Calculate total debt created within a date range
  // Uses PENDING debts only (loaded via loadDebtsByStatus('PENDING'))
  // Returns sum of remainingDebtAmount for debts incurred in the date range
  // Note: Only PENDING debts count as actual debt - PAID debts are already converted to sales
  double getTotalDebtFromTimestamp(Timestamp startTimestamp,Timestamp endDate) {
    double totalDebt = 0;

    for (var debt in debtHistories) {
      // Ensure debt.dateIncurred is of type Timestamp
      if (debt.dateIncurred is Timestamp) {
        Timestamp debtTimestamp = debt.dateIncurred;

        // Check if the debt was incurred within the specified date range (INCLUSIVE boundaries)
        if (debtTimestamp.compareTo(startTimestamp) >= 0 && debtTimestamp.compareTo(endDate) <= 0) {
          totalDebt += debt.remainingDebtAmount;
        }
      } else {
        // If the date is not in a recognized format, log an error and skip
        print("Unrecognized date format for debt: ${debt.dateIncurred}");
        continue;
      }
    }

    return totalDebt;
  }
  // Calculate total debt across all loaded debts (typically PENDING status)
  // Uses remainingDebtAmount for each debt
  // Note: Only PENDING debts are actual outstanding debt
  double getTotalDebt() {
    double totalDebt = 0;

    for (var debt in debtHistories) {
      // Ensure debt.dateIncurred is of type Timestamp
      if (debt.dateIncurred is Timestamp) {
        // Sum up all the remaining debt amounts
        totalDebt += debt.remainingDebtAmount;
      } else {
        // If the date is not in a recognized format, log an error and skip
        print("Unrecognized date format for debt: ${debt.dateIncurred}");
        continue;
      }
    }

    return totalDebt;
  }
  // Get debt histories by client ID
  List<DebtHistory> getDebtHistoriesByClientId(String clientId) {
    return debtHistories.where((debt) => debt.client == clientId).toList();
  }

  // Set status filter categories - now switches database query for optimization
  void setFilterStatus(List<String> statuses) {
    filterStatus.value = statuses;
    
    // If a single status is selected, query database for that status
    if (statuses.length == 1) {
      loadDebtsByStatus(statuses.first);
    } else if (statuses.isEmpty) {
      // Default to PENDING if no status selected
      loadDebtsByStatus('PENDING');
    } else {
      // For multiple statuses, we still need to filter in memory
      // This is not common, but we'll handle it
      filteredDebtHistoriesList();
    }
  }
  // Search debt history by sale ID or any other field
  void search(String searchValue) {
    searchText.value = searchValue;
    searchDebtHistories.value = debtHistories
        .where((debt) =>
        debt.id.toLowerCase().contains(searchValue.toLowerCase()))
        .toList();
    filteredDebtHistoriesList();
  }

  void setClient(String updatedClient) {
    selectedClient.value = updatedClient;
  }

  void setStatus(String updatedStatus) {
    selectedStatus.value = updatedStatus;
  }
  double getTotalDebtPaymentsBackTimestamp(Timestamp startTimestamp,Timestamp endDate) {
    double totalPayments = 0;

    for (var debtHistory in debtHistories) {
      // Ensure debtHistory['dateIncurred'] is of type Timestamp
        Timestamp dateIncurred = debtHistory.dateIncurred;

        // Check if the dateIncurred is before the startTimestamp
        if (dateIncurred.compareTo(startTimestamp) < 0) {
          for (var payment in debtHistory.paymentRecords) {
            // Ensure payment['date'] is of type Timestamp
            if (payment['date'] is Timestamp) {
              Timestamp paymentTimestamp = payment['date'];
              // Check if the payment date is within the selected window (start, end) (INCLUSIVE boundaries)
              if (paymentTimestamp.compareTo(startTimestamp) >= 0 && paymentTimestamp.compareTo(endDate) <= 0) {
                totalPayments += payment['amount'];
              }
            } else {
              // If the date is not in a recognized format, log an error and skip
              print("Unrecognized date format for payment: ${payment['date']}");
              continue;
            }
          }
        }
    }
    return totalPayments;
  }
  void clearDebt(){

    debtHistories.value.clear();
    filteredDebtHistories.value.clear();
  }
}
