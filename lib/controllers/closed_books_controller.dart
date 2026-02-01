import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/close_book_model.dart';
import '../services/firestore_db.dart';

class ClosedBooksController extends GetxController {
  final closedBooks = <CloseBook>[].obs;
  final searchClosedBooks = <CloseBook>[].obs;
  final searchText = ''.obs;
  final filteredClosedBooks = <CloseBook>[].obs;
  final filterCategories = <String>[].obs;
  final selectedCategory = 'No category'.obs;
  final selectedOwner = 'No owner'.obs;

  StreamSubscription<List<CloseBook>>? _closedBooksSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _closedBooksSubscription = FirestoreDb().getClosedBooks().listen((data) {
        closedBooks.value = data;
        searchClosedBooks.value = data;
        filteredClosedBooks.value = data;
      });
    } catch (e) {
      print("Error binding closed books stream: $e");
    }
  }

  @override
  void onClose() {
    _closedBooksSubscription?.cancel();
    super.onClose();
  }



  CloseBook getClosedBook(String bookId) {
    return closedBooks.firstWhere(
          (book) => book.id == bookId,
      orElse: () => CloseBook(
        id: '', // Default values for a new/empty CloseBook
        owner: '',
        totalSales: 0.0,
        totalPayment: 0.0,
        totalDebt: 0.0,
        expenses: 0.0,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        finalStock: 0.0,
        netProfit: 0.0,
        totalPurchase: 0.0,
        totalDiscounts: 0.0,
        currency: '',
        createdBy: '',
        createdAt: DateTime.now(),
        reserveString1: '',
        reserveString2: '',
        reserveDouble1: 0.0,
        reserveDouble2: 0.0,
        reserveList1: [],
        reserveList2: [],
        debt: 0.0,
      ),
    );
  }



  // Filter by category or criteria (similar to transactions)
  void filterByOwner(String ownerId) {
    filteredClosedBooks.value = closedBooks.where((book) {
      return book.owner == ownerId;
    }).toList();
  }

  void filteredBooks() {
    filteredClosedBooks.value = closedBooks;
    if (searchText.value.isNotEmpty) {
      filteredClosedBooks.value = closedBooks
          .where((book) => book.owner
          .toLowerCase()
          .contains(searchText.value.toLowerCase()))
          .toList();
    }
    if (filterCategories.isNotEmpty) {
      filteredClosedBooks.value = filteredClosedBooks.where((book) {
        return filterCategories.contains(book.owner);
      }).toList();
    }
  }

  // Function to get closed books by owner ID
  List<CloseBook> getClosedBooksByOwnerId(String ownerId) {
    return closedBooks.where((book) => book.owner == ownerId).toList();
  }

  void setFilterCategories(List<String> categories) {
    filterCategories.value = categories;
    filteredBooks();
  }

  void search(String searchValue) {
    searchText.value = searchValue;
    searchClosedBooks.value = closedBooks
        .where((book) =>
        book.owner.toLowerCase().contains(searchValue.toLowerCase()))
        .toList();
    filteredBooks();
  }


  void setCategory(String updatedCategory) {
    selectedCategory.value = updatedCategory;
  }


  void setOwner(String updatedOwner) {
    selectedOwner.value = updatedOwner;
  }
  void clearBooks(){
    closedBooks.value.clear();
    filteredClosedBooks.value.clear();
  }

  Future<void> deleteClosedBook(String businessId, String bookId) async {
    try {
      await FirebaseFirestore.instance
          .collection('closedbooks')
          .doc(businessId)
          .collection('userClosedBooks')
          .doc(bookId)
          .delete();
      print('✅ Closed book deleted successfully: $bookId');
    } catch (e) {
      print('❌ Error deleting closed book: $e');
      throw e;
    }
  }
}
