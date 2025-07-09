import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mauzo/controllers/closed_books_controller.dart';
import 'package:mauzo/controllers/employee_controller.dart';
import 'package:mauzo/models/business_model.dart';
import '../../controllers/Transaction_controller.dart';
import '../../controllers/bought_controller.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/business_list_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/client_controller.dart';
import '../../controllers/debt_history_controller.dart';
import '../../controllers/expence_controller.dart';
import '../../controllers/invoice_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/product_transfer_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sale_controller.dart';
import '../../controllers/store_controller.dart';
import '../../secret.dart';
import '../../utils/constants.dart';
import '../../utils/preferences.dart';
import '../widgets/dialogs/payment_dialog.dart';
import '../widgets/screens_card.dart';
import '../widgets/tiles/drawer_tile.dart';
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
  String accountEmail = '+255750549026/+255698720225';
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
    double netTotal = totalPayments  - totalExpenses-purchases;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sales and Expenses'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${'TOTAL SALES:'.tr} ${formatCurrency(totalPayments, _businessController.business['mainCurrency'])}'),
              Text('${'DEBT:'.tr} ${formatCurrency(debt, _businessController.business['mainCurrency'])}'),
              Text('${'PRODUCT PURCHASES:'.tr} ${formatCurrency(purchases, _businessController.business['mainCurrency'])}'),
              Text('${'EXPENSES:'.tr} ${formatCurrency(totalExpenses, _businessController.business['mainCurrency'])}'),
              Text('${'TOTAL CASH IN HAND:'.tr} ${formatCurrency(netTotal, _businessController.business['mainCurrency'])}'),

            ],
          ),
          actions: [

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'.tr),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    //  loadDeveloperInfo();
    final bool passwordMatches =
        _profileController.role.value == 'owner';


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
        final TransactionController _TransactionController = Get.put(TransactionController());
        final ClientController clientController = Get.put(ClientController());
        final SaleController _saleController = Get.put(SaleController());
        final ProductTransferController _transferController = Get.put(ProductTransferController());
        final CartController cartController = Get.put(CartController());
        final EmployeeController _employeeController = Get.put(EmployeeController());
        final DebtHistoryController _debtHistoryController = Get.put(DebtHistoryController());
        final ClosedBooksController closedBooksController = Get.put(ClosedBooksController());
        final BoughtController _boughtController = Get.put(BoughtController());


        void restartAllControllers() {
          // Delete all controllers
          Get.delete<ProductTransferController>(force: true);
          Get.delete<StoreController>(force: true);
          Get.delete<BusinessListController>(force: true);
          Get.delete<BoughtController>(force: true);
          Get.delete<DebtHistoryController>(force: true);
          Get.delete<InvoiceController>(force: true);
          Get.delete<ProductController>(force: true);
          Get.delete<TransactionController>(force: true);
          Get.delete<ClientController>(force: true);
          Get.delete<SaleController>(force: true);
          Get.delete<ExpenseController>(force: true);
          Get.delete<CartController>(force: true);
          Get.delete<EmployeeController>(force: true);
          Get.delete<ClosedBooksController>(force: true);
          // Recreate controllersProductTransferController
          Get.put<ProductTransferController>(ProductTransferController());
          Get.put<StoreController>(StoreController());
          Get.put<BoughtController>(BoughtController());
          Get.put<BusinessListController>(BusinessListController());
          Get.put<InvoiceController>(InvoiceController());
          Get.put<DebtHistoryController>(DebtHistoryController());
          Get.put<ProductController>(ProductController());
          Get.put<ExpenseController>(ExpenseController());
          Get.put<TransactionController>(TransactionController());
          Get.put<ClientController>(ClientController());
          Get.put<SaleController>(SaleController());
          Get.put<CartController>(CartController());
          Get.put<EmployeeController>(EmployeeController());
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
                    title: Text('Add New Business'),
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
                              hintText: 'Business Name',
                              counterText: '', // Hides the character counter at the bottom
                            ),
                            maxLength: 25, // Set the maximum length to 25 characters
                          ),
                      ],
                    ),
                    actions: [
                      if (!isLoading) // Hide actions when loading
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      if (!isLoading)
                        TextButton(
                          child: Text('Save'),
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
                  if(passwordMatches)
                    GestureDetector(
                      onTap: () {
                        // Simulate a DropdownButton by showing the menu when the icon is clicked
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(100, 100, 0, 0), // Adjust this for proper positioning
                          items: [
                            ...businessListController.businesses.map((BusinessModel business) {
                              return PopupMenuItem<BusinessModel>(
                                value: business,
                                child: Text(business.name),
                              );
                            }).toList(),
                            // Add the "Add New Business" option
                            PopupMenuItem<BusinessModel>(
                              value: BusinessModel(
                                id: 'add_new',
                                name: 'Add New Business',
                                phone: '',
                                tin: 'TIN',
                                email: '',
                                reset_time: Timestamp.now(),
                                subscriptionStatus: '',
                                mainCurrency: '',
                                secondaryCurrency: '',
                                date: DateTime.now(),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Add New Business'),
                                ],
                              ),
                            ),
                          ],
                        ).then((newBusiness) async {
                          if (newBusiness != null) {
                            if (newBusiness.id == 'add_new') {
                              // Show dialog to add a new business
                              if (_profileController.user['maxBusiness'] > (_profileController.user['business'] as List).length) {
                                showAddBusinessDialog(context);} else {

                                print("Exceeded max business limit");
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Limit Reached'),
                                      content: Text( '${'max_business_reached_message'.tr} (${_profileController.user['maxBusiness']})',),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            print("Dialog closed");
                                            Navigator.of(context).pop();
                                          },
                                          child: Text('OK'),
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
                    if(passwordMatches)
                      DrawerTile(
                        title: 'Employees'.tr,
                        icon: Icons.people,
                        route: 'addemployee',
                      ),

                    if(passwordMatches)
                      DrawerTile(
                        title: 'Generate Reports'.tr,
                        icon: Icons.account_balance,
                        route: 'reports',
                      ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(),
                    ),
                    DrawerTile(
                      title: 'expenses'.tr,
                      icon: Icons.account_balance_wallet,
                      route: 'expenses',
                    ),
                    if (passwordMatches)
                      DrawerTile(
                        title: 'Products in Store'.tr,
                        icon: Icons.production_quantity_limits_rounded,
                        route: 'store/add',
                      ),
                    if (passwordMatches)
                      DrawerTile(
                        title: 'Services'.tr,
                        icon: Icons.design_services,
                        route: '/services',
                      ),

                    DrawerTile(
                      title: 'Debt Records'.tr,
                      icon: Icons.money,
                      route: 'debt',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(),
                    ),
/*
                    DrawerTile(
                      title: 'Products report'.tr,
                      icon: Icons.money,
                      route: 'report',
                    ),*/

                    if(passwordMatches)
                    DrawerTile(
                      title: 'Statistics'.tr,
                      icon: Icons.bar_chart,
                      route: 'statistics',
                    ),
                    DrawerTile(
                      title: 'Settings'.tr,
                      icon: Icons.settings,
                      route: 'settings',
                    ),
                    if (_businessController.business['purchases']=='true')
                      DrawerTile(
                        title: 'Purchases'.tr,
                        icon: Icons.import_export,
                        route: 'bought',
                      ),
                    DrawerTile(
                      title: 'Transfer Requests'.tr,
                      icon: Icons.swap_horiz,
                      route: 'transfer_requests',
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
                if (passwordMatches)
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
