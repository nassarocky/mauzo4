import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/debtHistory_model.dart';
import '../services/firestore_db.dart';

class DebtHistoryController extends GetxController {
  final debtHistories = <DebtHistory>[].obs;
  final searchDebtHistories = <DebtHistory>[].obs;
  final searchText = ''.obs;
  final filteredDebtHistories = <DebtHistory>[].obs;
  final filterStatus = <String>[].obs;
  final selectedClient = 'No client'.obs;
  final selectedStatus = 'No status'.obs;
  final RxBool isLoading = false.obs;

  StreamSubscription<List<DebtHistory>>? _debtHistorySubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _debtHistorySubscription = FirestoreDb().getDebtHistory().listen((data) {
        debtHistories.value = data;
        searchDebtHistories.value = data;
        filteredDebtHistories.value = data;
      });
    } catch (e) {
      print("Error initializing DebtHistoryController: $e");
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
        status: 'pending',
        comment: '',
      ),
    );
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
  double getTotalDebtFromTimestamp(Timestamp startTimestamp,Timestamp endDate) {
    double totalDebt = 0;
    Timestamp currentTimestamp = Timestamp.now();

    for (var debt in debtHistories) {
      // Ensure sale.date is of type Timestamp
      if (debt.dateIncurred is Timestamp) {
        Timestamp debtTimestamp = debt.dateIncurred;

        // Check if the saleTimestamp is within the specified range
        if (debtTimestamp.compareTo(startTimestamp) > 0 && debtTimestamp.compareTo(endDate) < 0) {
          totalDebt += debt.remainingDebtAmount;
        }
      } else {
        // If the date is not in a recognized format, log an error and skip
        print("Unrecognized date format for sale: ${debt.dateIncurred}");
        continue;
      }
    }

    return totalDebt;
  }
  double getTotalDebt() {
    double totalDebt = 0;

    for (var debt in debtHistories) {
      // Ensure debt.dateIncurred is of type Timestamp
      if (debt.dateIncurred is Timestamp) {
        // Simply sum up all the remaining debt amounts
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

  // Set status filter categories
  void setFilterStatus(List<String> statuses) {
    filterStatus.value = statuses;
    filteredDebtHistoriesList();
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
              // Check if the payment date is after the startTimestamp
              if (paymentTimestamp.compareTo(startTimestamp) > 0) {
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
