import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/business_list_controller.dart';
import 'package:mauzo/controllers/bought_controller.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/employee_controller.dart';
import 'package:mauzo/controllers/expence_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/controllers/supplier_controller.dart';
import 'package:mauzo/controllers/supplier_debt_controller.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/debt_history_controller.dart';
import 'package:mauzo/controllers/invoice_controller.dart';
import 'package:mauzo/controllers/transaction_controller.dart';
import 'package:mauzo/controllers/closed_books_controller.dart';
import 'package:mauzo/controllers/auth_controller.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/payment_controller.dart';
import 'package:mauzo/models/business_model.dart';
import 'package:mauzo/ui/widgets/tiles/drawer_tile.dart';
import 'package:mauzo/ui/widgets/drawer/expandable_drawer_section.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/product_transfer_controller.dart';
import '../../controllers/store_controller.dart';
import '../../utils/preferences.dart';
import '../widgets/dialogs/payment_dialog.dart';
import '../widgets/screens_card.dart';
import '../widgets/tiles/info_tile.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProfileController _profileController =Get.put(ProfileController());
  final BusinessController _businessController = Get.put(BusinessController());
  String accountName = 'Customer service / Huduma kwa wateja';
  String accountEmail = '+255698720225/+255653422101';
  bool isAccountActive = true;
  bool isInitialized = false;
  bool isBuyingStock = Preferences.getStockDisplayPreference();
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  User? user = FirebaseAuth.instance.currentUser;


  @override
  void initState() {
    super.initState();
    if (!isInitialized) {
      _initialize();
    }
  }
  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }


  void _initialize() async {

   await _profileController.updateUserEmail(Preferences.getEmail());
    await _businessController.updateBusinessId(Preferences.getBusiness());

    // Initialize controllers
    Get.put(SupplierController());

    // Additional logic after ensuring all controllers are initialized
    if (_businessController.businessId.value.isNotEmpty) {
      await checkAccountStatus();
    }
    // Mark initialization as complete
   setState(() {
   isInitialized = true;
    });
    // Start necessary operations
    startTimer();
    _listenToUserChanges();
  }


  void _listenToUserChanges() {
    // Ensure businessId is not empty before setting up the listener
    if (_businessController.businessId.value.isNotEmpty) {
      _userSubscription = FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessController.businessId.value)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          // Get the current and previous values of 'reset_time'
          var currentResetTime = snapshot.data()?['reset_time'] as Timestamp?;
          var previousResetTime = _businessController.business['reset_time'] as Timestamp?;

          // Check if 'reset_time' has changed
          if (currentResetTime != previousResetTime) {
            // Update only if 'reset_time' has changed
            await _businessController.updateBusinessData();
          }

          // Check for 'subscriptionStatus' changes
          var currentSubscriptionStatus = snapshot.data()?['subscriptionStatus'];
          var previousSubscriptionStatus = _businessController.business['subscriptionStatus'];

          if (currentSubscriptionStatus != previousSubscriptionStatus) {
            await _businessController.updateBusinessData();
            await checkAccountStatus();
          }
        }
      });
    } else {
      print("Business ID is empty. Firestore listener not initialized.");
    }
  }




  int time = 0;
  void startTimer() {
    Timer.periodic(const Duration(seconds: 25), (timer) {
      if (mounted) {
        setState(() {
          time = time + 25;
        });
      }
    });
  }




  Future<void> checkAccountStatus() async {
    isAccountActive = await _businessController.isAccountActive();
    if (!isAccountActive ||
        _businessController.business['subscriptionStatus'] == null) {
      showAccountStatusDialog(_businessController.business['subscriptionStatus']);
    } else {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    }
  }

  void showAccountStatusDialog(String? status) {
    String message = '';
    if (status == null) {
      message = 'Subscription status is not set.'.tr;
    } else if (status == 'subscription_ended') {
      message = 'Your subscription has ended.'.tr;
    } else if (status == 'trial_expired') {
      message = 'Your trial has expired.'.tr;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
             // title: Text('${'Account Status:'.tr} ${_businessController.business['email']}'),
              title: Text('payment'.tr),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  const PaymentDialogContent(), // ← integrated payment UI here
                ],
              ),
            ),

          );
        },
      );
    });
  }

  double getFontSize(BuildContext context, double baseFontSize) {
    // Adjust font size based on screen width
    double screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 600 ? baseFontSize * 1.5 : baseFontSize; // Larger for tablets
  }



  void _showTotalSalesDialog(BuildContext context, SaleController _saleController,DebtHistoryController _debtHistoryController,BoughtController _boughtController, ExpenseController expenseController, Timestamp resetTime) {
    // double totalSales = _saleController.getTotalSalesFromTimestamp(resetTime);
    double totalPayments = _saleController.getTotalPaymentFromTimestamp(resetTime,Timestamp.now());
    double debt = _debtHistoryController.getTotalDebtFromTimestamp(resetTime,Timestamp.now());
    double purchases = _boughtController.getTotalSalesFromTimestamp(resetTime,Timestamp.now());
    //  double debtCollected = _debtHistoryController.getTotalDebtPaymentsBackTimestamp(resetTime);
    double totalExpenses = expenseController.getTotalExpensesFromTimestamp(resetTime,Timestamp.now());
    // Only deduct purchases funded by CASH from the cash-in-hand calculation
    final String mainCurrency = _businessController.business['mainCurrency'];
    double purchasesCashDeduction = 0.0;
    for (final b in _boughtController.sales) {
      if (b.date is Timestamp) {
        final Timestamp bt = b.date;
        if (bt.compareTo(resetTime) > 0 && bt.compareTo(Timestamp.now()) < 0) {
          // Deduct only if purchase fund source is explicitly cash
          if (b.fundSource == 'cash') {
            if (b.payments.isNotEmpty) {
              // Sum all payments (regardless of method) because the source was cash
              for (final p in b.payments) {
                final dynamic rawAmount = p['amount'];
                final double amt = rawAmount is int ? rawAmount.toDouble() : (rawAmount is num ? rawAmount.toDouble() : 0.0);
                final String currency = (p['currency'] ?? mainCurrency).toString();
                final double amtMain = currency == mainCurrency ? amt : amt * Preferences.getExchangeRateResult();
                purchasesCashDeduction += amtMain;
              }
            } else {
              // Fallback to aggregate payment amount
              if (b.payment > 0) {
                purchasesCashDeduction += b.payment;
              }
            }
          }
        }
      }
    }
    double netTotal = totalPayments  - totalExpenses - purchasesCashDeduction;

    // Compute payment totals by method within the same time window
    double cashTotal = 0.0;
    double bankTotal = 0.0;
    double mobileTotal = 0.0;
    // mainCurrency already defined above

    for (final sale in _saleController.sales) {
      if (sale.date is Timestamp) {
        final Timestamp saleTs = sale.date;
        if (saleTs.compareTo(resetTime) > 0 && saleTs.compareTo(Timestamp.now()) < 0) {
          if (sale.payments.isNotEmpty) {
            for (final p in sale.payments) {
              final dynamic rawAmount = p['amount'];
              final double amt = rawAmount is int
                  ? rawAmount.toDouble()
                  : (rawAmount is num ? rawAmount.toDouble() : 0.0);
              final String currency = (p['currency'] ?? mainCurrency).toString();
              final String method = (p['method'] ?? 'cash').toString();
              final double amtMain = currency == mainCurrency
                  ? amt
                  : amt * Preferences.getExchangeRateResult();

              if (method == 'bank') {
                bankTotal += amtMain;
              } else if (method == 'mobile') {
                mobileTotal += amtMain;
              } else {
                cashTotal += amtMain;
              }
            }
          } else {
            // Backward compatibility: attribute aggregated payment to cash
            cashTotal += sale.payment;
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                  Colors.green.shade50,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sales and Expenses Analysis'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Total Sales Card
                        _buildAnalyticsCard(
                          icon: Icons.trending_up,
                          iconColor: Colors.green,
                          title: 'TOTAL SALES'.tr,
                          amount: formatCurrency(totalPayments, _businessController.business['mainCurrency']),
                          gradient: [Colors.green.shade50, Colors.green.shade100],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Payment Methods Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payment, color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Payment Methods Breakdown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildPaymentMethodRow(
                                icon: Icons.money,
                                iconColor: Colors.green.shade600,
                                method: 'Cash',
                                amount: formatCurrency(cashTotal, _businessController.business['mainCurrency']),
                              ),
                              const SizedBox(height: 8),
                              _buildPaymentMethodRow(
                                icon: Icons.account_balance,
                                iconColor: Colors.blue.shade600,
                                method: 'Bank',
                                amount: formatCurrency(bankTotal, _businessController.business['mainCurrency']),
                              ),
                              const SizedBox(height: 8),
                              _buildPaymentMethodRow(
                                icon: Icons.phone_android,
                                iconColor: Colors.orange.shade600,
                                method: 'Mobile (Lipa Namba)',
                                amount: formatCurrency(mobileTotal, _businessController.business['mainCurrency']),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Other Metrics
                        _buildAnalyticsCard(
                          icon: Icons.account_balance_wallet,
                          iconColor: Colors.orange,
                          title: 'DEBT'.tr,
                          amount: formatCurrency(debt, _businessController.business['mainCurrency']),
                          gradient: [Colors.orange.shade50, Colors.orange.shade100],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        _buildAnalyticsCard(
                          icon: Icons.shopping_cart,
                          iconColor: Colors.purple,
                          title: 'PRODUCT PURCHASES'.tr,
                          amount: formatCurrency(purchases, _businessController.business['mainCurrency']),
                          gradient: [Colors.purple.shade50, Colors.purple.shade100],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        _buildAnalyticsCard(
                          icon: Icons.receipt_long,
                          iconColor: Colors.red,
                          title: 'EXPENSES'.tr,
                          amount: formatCurrency(totalExpenses, _businessController.business['mainCurrency']),
                          gradient: [Colors.red.shade50, Colors.red.shade100],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Net Total - Special styling
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: netTotal >= 0 
                                ? [Colors.green.shade600, Colors.green.shade800]
                                : [Colors.red.shade600, Colors.red.shade800],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (netTotal >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  netTotal >= 0 ? Icons.account_balance : Icons.warning,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL CASH IN HAND'.tr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatCurrency(netTotal, _businessController.business['mainCurrency']),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String amount,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow({
    required IconData icon,
    required Color iconColor,
    required String method,
    required String amount,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            method,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    //  loadDeveloperInfo();
    final bool canEditHome = _profileController.hasPermission('edit_home');
    final bool canEditBusiness = _profileController.hasPermission('edit_business');

    return GetBuilder<BusinessController>(
      init: BusinessController(),
      builder: (controller) {

        if (controller.business.isEmpty) {
          return Scaffold(
            body: Center(
              child: time < 25
                  ? const CircularProgressIndicator()
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Something went wrong'.tr),
                  TextButton(
                    child: Text(
                      'Login'.tr,
                      style: h5(
                        Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    onPressed: () {
                      Get.toNamed('/login');
                    },
                  ),
                ],
              ),
            ),
          );
        }




        final BusinessListController businessListController = Get.put(BusinessListController());
        final InvoiceController invoiceController = Get.put(InvoiceController());
        final ProductController productController = Get.put(ProductController());
        final ExpenseController expenceController = Get.put(ExpenseController());
        final StoreController storeController = Get.put(StoreController());
        final ClientController clientController = Get.put(ClientController());

        final SaleController _saleController = Get.put(SaleController());
        final ProductTransferController _transferController = Get.put(ProductTransferController());
        final CartController cartController = Get.put(CartController());
        final EmployeeController _employeeController = Get.put(EmployeeController());
        final DebtHistoryController _debtHistoryController = Get.put(DebtHistoryController());
        final SupplierDebtController _supplierDebtController = Get.put(SupplierDebtController());
        final ClosedBooksController closedBooksController = Get.put(ClosedBooksController());
        final BoughtController _boughtController = Get.put(BoughtController());
        final TransactionController transactionController = Get.put(TransactionController());

        void restartAllControllers() {
          // Delete all controllers
          Get.delete<ProductTransferController>(force: true);
          Get.delete<StoreController>(force: true);
          Get.delete<BusinessListController>(force: true);
          Get.delete<BoughtController>(force: true);
          Get.delete<DebtHistoryController>(force: true);
          Get.delete<BoughtController>(force: true);
          Get.delete<InvoiceController>(force: true);
          Get.delete<ProductController>(force: true);
          Get.delete<TransactionController>(force: true);
          Get.delete<ClientController>(force: true);
          Get.delete<SaleController>(force: true);
          Get.delete<ExpenseController>(force: true);
          Get.delete<CartController>(force: true);
          Get.delete<StoreController>(force: true);
          Get.delete<ClosedBooksController>(force: true);
          Get.delete<ClosedBooksController>(force: true);
          // Recreate controllers - ORDER MATTERS: Dependencies must be initialized first
          Get.put<ProductTransferController>(ProductTransferController());
          Get.put<StoreController>(StoreController());
          Get.put<BusinessListController>(BusinessListController());
          Get.put<InvoiceController>(InvoiceController());
          Get.put<DebtHistoryController>(DebtHistoryController());
          Get.put<SupplierDebtController>(SupplierDebtController());
          Get.put<ProductController>(ProductController());
          Get.put<ExpenseController>(ExpenseController()); // Must be before BoughtController
          Get.put<ClientController>(ClientController());
          // Initialize TransactionController after BusinessController is ready
          try {
            if (_businessController.businessId.value.isNotEmpty) {
              Get.put<TransactionController>(TransactionController());
            }
          } catch (e) {
            print('TransactionController restart failed: $e');
          }
          Get.put<SupplierController>(SupplierController());
          Get.put<SaleController>(SaleController());
          Get.put<CartController>(CartController());
          Get.put<EmployeeController>(EmployeeController());
          Get.put<BoughtController>(BoughtController()); // Depends on ExpenseController
          Get.put<ClosedBooksController>(ClosedBooksController());
        }

        _businessController.business['categories'].sort();
        void showAddBusinessDialog(BuildContext context) {
          final TextEditingController businessNameController = TextEditingController();
          bool isLoading = false; // Loading state

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return AlertDialog(
                    title: Text('add_new_business'.tr),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLoading)
                          Center(
                            child: CircularProgressIndicator(), // Show loading spinner
                          )
                        else
                          TextField(
                            controller: businessNameController,
                            decoration: InputDecoration(
                              hintText: 'business_name'.tr,
                              counterText: '', // Hides the character counter at the bottom
                            ),
                            maxLength: 25, // Set the maximum length to 25 characters
                          ),
                      ],
                    ),
                    actions: [
                      if (!isLoading) // Hide actions when loading
                        TextButton(
                          child: Text('cancel'.tr),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      if (!isLoading)
                        TextButton(
                          child: Text('save'.tr),
                          onPressed: () async {
                            if (businessNameController.text.isNotEmpty) {
                              setState(() {
                                isLoading = true; // Show loading spinner
                              });
                              try {
                                // Simulate business creation logic
                                await businessListController.addNewBusiness(businessNameController.text);
                                await _profileController.updateUserData();
                                restartAllControllers();

                              } catch (e) {
                                // Handle error here
                                print("Error: $e");
                              } finally {
                                setState(() {
                                  Navigator.of(context).pop();
                                  isLoading = false; // Hide loading spinner
                                });
                              }
                            } else {
                              print("Business name is empty");
                            }
                          },
                        ),
                    ],
                  );
                },
              );
            },
          );
        }

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Obx(() {
              return Row(
                mainAxisSize: MainAxisSize.min, // Keeps the row as small as possible
                children: [
                  // Display the selected business name
                  GestureDetector(
                    onTap: () {
                      // Trigger dropdown manually when tapping on the business name
                      // if needed in future, currently it only shows the name
                    },
                    child: Text(
                      _businessController.business['name'] ?? 'Select Business',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  SizedBox(width: 8),
                  // Allow business switching for users with edit_business permission OR multi-business employees
                  if(canEditBusiness || ((_profileController.user['business'] as List<dynamic>?)?.length ?? 0) > 1)
                    GestureDetector(
                      onTap: () {
                        // Simulate a DropdownButton by showing the menu when the icon is clicked
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(100, 100, 0, 0), // Adjust this for proper positioning
                          items: [
                            ...businessListController.businesses.map((business) {
                              return PopupMenuItem<BusinessModel>(
                                value: business,
                                child: Text(business.name),
                              );
                            }).toList(),
                            // Add the "Add New Business" option
                            PopupMenuItem<BusinessModel>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('add_new_business'.tr),
                                ],
                              ),
                            ),
                          ],
                        ).then((newBusiness) async {
                          if (newBusiness != null) {
                            if (newBusiness.id == 'add_new') {
                              // Show dialog to add a new business
                              if (_profileController.user['maxBusiness'] > ((_profileController.user['business'] as List<dynamic>?)?.length ?? 0)) {
                                showAddBusinessDialog(context);} else {

                                print("Exceeded max business limit");
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('business_limit_reached'.tr),
                                      content: Text( '${'max_business_reached_message'.tr} (${_profileController.user['maxBusiness']})',),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            print("Dialog closed");
                                            Navigator.of(context).pop();
                                          },
                                          child: Text('ok_caps'.tr),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            } else {
                              // Update the business ID and restart controllers

                              await _businessController.updateBusinessId(newBusiness.id);
                              await Preferences.setBusiness(newBusiness.id);
                              restartAllControllers();

                            }
                          }
                        });
                      },
                      child: Icon(Icons.arrow_drop_down, color: Colors.white),
                    ),
                ],
              );
            }),
          ),


          drawer: isAccountActive
              ? SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: Drawer(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    UserAccountsDrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                      margin: EdgeInsets.zero,
                      accountName: Text(
                        accountName,
                        style:  TextStyle(
                          fontSize:getFontSize(context, 20),
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      accountEmail: Text(
                        accountEmail,
                        style:  TextStyle(
                          color: Colors.white, // Set the phone number color to red
                          fontSize: getFontSize(context, 10), // You can adjust the font size as needed
                        ),
                      ),
                    ),
                    
                    // HR & PAYROLL SECTION
                    if(canEditBusiness)
                      ExpandableDrawerSection(
                        title: 'HR & Payroll',
                        icon: Icons.people,
                        initiallyExpanded: false,
                        items: [
                          DrawerMenuItem(
                            title: 'Employees'.tr,
                            icon: Icons.person_add,
                            route: 'addemployee',
                          ),
                          if(_profileController.hasPermission('manage_payroll'))
                            DrawerMenuItem(
                              title: 'Pay Roles'.tr,
                              icon: Icons.payment,
                              route: 'pay-roles',
                            ),
                          if(_profileController.hasPermission('manage_payroll'))
                            DrawerMenuItem(
                              title: 'Payment Management'.tr,
                              icon: Icons.account_balance,
                              route: 'payment-management',
                            ),
                        ].where((item) => item != null).cast<DrawerMenuItem>().toList(),
                      ),

                    // INVENTORY & PRODUCTS SECTION
                    ExpandableDrawerSection(
                      title: 'Inventory & Products',
                      icon: Icons.inventory,
                      initiallyExpanded: false,
                      items: [
                        if (canEditBusiness)
                          DrawerMenuItem(
                            title: 'Products in Store'.tr,
                            icon: Icons.production_quantity_limits_rounded,
                            route: 'store/add',
                          ),
                        DrawerMenuItem(
                          title: 'Transfer Requests'.tr,
                          icon: Icons.swap_horiz,
                          route: 'transfer_requests',
                        ),
                        if (_businessController.business['purchases']=='true')
                          DrawerMenuItem(
                            title: 'Purchases'.tr,
                            icon: Icons.import_export,
                            route: 'bought',
                          ),
                      ].where((item) => item != null).cast<DrawerMenuItem>().toList(),
                    ),

                    // FINANCE & ACCOUNTING SECTION
                    ExpandableDrawerSection(
                      title: 'Finance & Accounting',
                      icon: Icons.account_balance,
                      initiallyExpanded: false,
                      items: [
                        DrawerMenuItem(
                          title: 'expenses'.tr,
                          icon: Icons.account_balance_wallet,
                          route: 'expenses',
                        ),
                        DrawerMenuItem(
                          title: 'Debt Records'.tr,
                          icon: Icons.money,
                          route: 'debt',
                        ),
                        DrawerMenuItem(
                          title: 'Supplier Debts'.tr,
                          icon: Icons.account_balance_wallet,
                          route: 'supplier-debt',
                        ),
                        DrawerMenuItem(
                          title: 'Suppliers'.tr,
                          icon: Icons.local_shipping,
                          route: 'suppliers',
                        ),
                      ],
                    ),

                    // REPORTS & ANALYTICS SECTION
                    if(canEditBusiness)
                      ExpandableDrawerSection(
                        title: 'Reports & Analytics',
                        icon: Icons.analytics,
                        initiallyExpanded: false,
                        items: [
                          DrawerMenuItem(
                            title: 'Generate Reports'.tr,
                            icon: Icons.description,
                            route: 'reports',
                          ),
                          DrawerMenuItem(
                            title: 'Statistics'.tr,
                            icon: Icons.bar_chart,
                            route: 'statistics',
                          ),
                        ],
                      ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(),
                    ),

                    // SETTINGS & SUPPORT (Direct items)
                    DrawerTile(
                      title: 'Settings'.tr,
                      icon: Icons.settings,
                      route: 'settings',
                    ),
                    DrawerTile(
                      title: 'Support'.tr,
                      icon: Icons.help_outline,
                      route: 'support',
                    ),
                  ],
                ),
              ),
            ),
          )
              : null,
          body: SingleChildScrollView(
            child: Column(
              children: [
            Container(
            padding: const EdgeInsets.all(20),
            color: primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 25),
                if (canEditBusiness)
        InfoTile(
          onTap: () async {
            isBuyingStock = !isBuyingStock; // Toggle the value
            await Preferences.setStockDisplayPreference(isBuyingStock); // Save the new preference

            // Display the appropriate snackbar
            Get.snackbar(
              'Switched',
              isBuyingStock
                  ? 'Displaying STOCK by BUYING PRICE'
                  : 'Displaying STOCK by SELLING PRICE',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.green,
              colorText: Colors.white,
            );

            // Update the UI or recalculate stock values
            setState(() {});
          },
          title: "total_stock".tr,
          trailing: formatCurrency(
            isBuyingStock
                ? productController.calculateTotalStockBuying()
                : productController.calculateTotalStock(),
            _businessController.business['mainCurrency'],
          ),
        ),
                InfoTile(
                  onTap: () {
                    _showTotalSalesDialog(
                      context,
                      _saleController,
                      _debtHistoryController,
                      _boughtController,
                      expenceController,
                      _businessController.business['reset_time'],
                    );
                  },
                  title: "total_sales".tr,
                  trailing: formatCurrency(
                    _saleController.getTotalPaymentFromTimestamp(
                        _businessController.business['reset_time'],Timestamp.now()),
                    _businessController.business['mainCurrency'],
                  ),
                ),
                // Only show service sales InfoTile if value > 0
                Builder(
                  builder: (context) {
                    final serviceSales = _saleController.getTotalServiceSalesFromTimestamp(
                      _businessController.business['reset_time'], Timestamp.now());
                    if (serviceSales > 0) {
                      return InfoTile(
                        onTap: () {},
                        title: "service_sales".tr,
                        trailing: formatCurrency(
                          serviceSales,
                          _businessController.business['mainCurrency'],
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
                ),
                const SizedBox(height: 16),
                  InfoTile(
                    onTap: () {
                      DateTimeRange range = DateTimeRange(
                        start: DateUtils.dateOnly(DateTime.now()),
                        end: DateTime.now(),
                      );
                      _saleController.setSelectedDateRange(range);
                      Navigator.pushNamed(context, '/sales');
                    },
                    title: "today_sales".tr,
                    trailing: formatCurrency(
                      _saleController.getTodaySales(),
                      _businessController.business['mainCurrency'],
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),

                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ScreensCard(
                              title: 'all_sales'.tr,
                              backgroundColor: const Color(0xFFFDF0D6),
                              route: '/sales',
                              child: const Icon(
                                Icons.receipt,
                                color: Color(0xFFE49639),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ScreensCard(
                              title: 'products'.tr,
                              backgroundColor: const Color(0xFFFCE2E6),
                              route: '/products',
                              child: Image.asset(
                                'assets/images/products.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ScreensCard(
                              title: 'clients'.tr,
                              backgroundColor: const Color(0xFFDFF7FF),
                              route: '/clients',
                              child: const Icon(
                                Icons.people,
                                color: Color(0xFF00C2FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ScreensCard(
                              title: 'New Sale'.tr,
                              backgroundColor: const Color(0xFFDAF9DA),
                              route: '/sale/add',
                              child: const Icon(
                                Icons.shopping_basket,
                                color: Color(0xFF64BE62),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ScreensCard(
                              title: 'all_invoices'.tr,
                              backgroundColor: const Color(0xFFFDF0D6),
                              route: '/invoices',
                              child: const Icon(
                                Icons.receipt,
                                color: Color(0xFFE49639),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Obx(() {
                              final pendingCount = _transferController.incomingTransferRequests
                                  .where((request) => request.status == 'pending')
                                  .length;
                              return Stack(
                                children: [
                                  ScreensCard(
                                    title: 'Transfer Requests'.tr,
                                    backgroundColor: const Color(0xFFE8F4FD),
                                    route: '/transfer_requests',
                                    child: const Icon(
                                      Icons.swap_horiz,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                  if (pendingCount > 0)
                                    Positioned(
                                      top: 20,
                                      right: 20,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        child: Text(
                                          pendingCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
