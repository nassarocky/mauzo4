import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/ui/screens/purchases_blocked_screen.dart';
import 'package:mauzo/utils/purchases_access.dart';
import 'package:mauzo/privacy_policy_screen.dart';
import 'package:mauzo/ui/screens/auth/login_screen.dart';
import 'package:mauzo/ui/screens/categories_screen.dart';
import 'package:mauzo/ui/screens/auth/register_screen.dart';
import 'package:mauzo/ui/screens/client/add_client_screen.dart';
import 'package:mauzo/ui/screens/expences/add_expences_screen.dart';
import 'package:mauzo/ui/screens/expences/edit_expense_screen.dart';
import 'package:mauzo/ui/screens/my_account_screen.dart';
import 'package:mauzo/ui/screens/product/add_product_screen.dart';
import 'package:mauzo/ui/screens/product/store_screen.dart';
import 'package:mauzo/ui/screens/product/transfer_requests_screen.dart';
import 'package:mauzo/ui/screens/report_screen.dart';
import 'package:mauzo/ui/screens/sale/add_sale_view_screen.dart';
import 'package:mauzo/ui/screens/sale/sales_screen.dart';
import 'package:mauzo/ui/screens/cart_screen.dart';
import 'package:mauzo/ui/screens/client/clients_screen.dart';
import 'package:mauzo/ui/screens/home_screen.dart';
import 'package:mauzo/ui/screens/client/select_client_screen.dart';
import 'package:mauzo/ui/screens/statistics_screen.dart';
import 'package:mauzo/ui/screens/sale/add_sale_screen.dart';
import 'package:mauzo/ui/screens/product/products_screen.dart';
import 'package:mauzo/ui/screens/settings_screen.dart';
import 'package:mauzo/ui/screens/sms/sms_credits_screen.dart';
import 'package:mauzo/ui/screens/subscription_screen.dart';
import 'package:mauzo/ui/screens/loading_screen.dart';
import 'package:mauzo/ui/screens/support_screen.dart';
import '../ui/screens/Buy_Product_cart_screen.dart';
import '../ui/screens/Debt_history_screen.dart';
import '../ui/screens/auth/reset_password_screen.dart';
import '../ui/screens/buy/bought_screen.dart';
import '../ui/screens/buy/buy_product_screen.dart';
import '../ui/screens/closed_books_screen.dart';
import '../ui/screens/employee/add_employee_screen.dart';
import '../ui/screens/employee/employee_screen.dart';
import '../ui/screens/expences/expences_list_screen.dart';
import '../ui/screens/invoices/invoices_screen.dart';
import 'package:mauzo/ui/screens/service/services_screen.dart';
import '../ui/screens/supplier/suppliers_screen.dart';
import '../ui/screens/supplier/add_supplier_screen.dart';
import '../ui/screens/supplier/edit_supplier_screen.dart';
import '../ui/screens/supplier/select_supplier_screen.dart';
import '../ui/screens/supplier_debt_screen.dart';
import '../ui/screens/sale/edit_sale.screen.dart';
import '../ui/screens/pay_role_management_screen.dart';
import '../ui/screens/select_employee_for_pay_role_screen.dart';
import '../ui/screens/payment_management_screen.dart';
import 'package:mauzo/ui/screens/ledger_history_screen.dart';
import 'package:mauzo/ui/screens/assets_screen.dart';
import '../ui/screens/inventory_loss_screen.dart';
import '../ui/widgets/app_back_scope.dart';

class AppRouter {
  static CupertinoPageRoute<void> _page(
    Widget screen, {
    RouteSettings? settings,
    bool backToHome = true,
  }) {
    return CupertinoPageRoute<void>(
      settings: settings,
      builder: (_) =>
          backToHome ? AppBackScope(child: screen) : screen,
    );
  }

  static bool _purchasesRouteAllowed(String? routeName) {
    if (!PurchasesAccess.isGuardedRoute(routeName)) return true;
    if (!Get.isRegistered<BusinessController>()) return true;
    return PurchasesAccess.isEnabled;
  }

  static Route onGenerateRoute(RouteSettings settings) {
    if (!_purchasesRouteAllowed(settings.name)) {
      return _page(const PurchasesBlockedScreen(), settings: settings);
    }

    switch (settings.name) {
      case '/debt':
        return _page(DebtHistoryScreen());
      case '/supplier-debt':
        return _page(const SupplierDebtScreen(), settings: settings);
      case '/login':
        return _page(const LoginScreen(), backToHome: false);
      case '/addemployee':
        return _page(EmployeesScreen());
      case '/invoices':
        return _page(const InvoicesScreen());
      case '/register':
        return _page(RegisterScreen(), backToHome: false);
      case '/expenses':
        return _page(const ExpenseListScreen(), settings: settings);
      case '/report':
        return _page(ReportScreen());
      case '/add-expense':
        return _page(AddExpenseScreen());
      case '/edit-expense':
        return _page(EditExpenseScreen(), settings: settings);
      case '/home':
        return _page(const HomeScreen(), backToHome: false);
      case '/sale/add':
        final args = settings.arguments;
        if (args is Map && args['userData'] is UserData) {
          return _page(DualScreenApp(userData: args['userData']));
        }
        return _page(DualScreenApp());
      case '/sales':
        return _page(const SalesScreen());
      case '/cart':
        return _page(const CartScreen());
      case '/buycart':
        return _page(const BuyProductCartScreen());
      case '/buy':
        return _page(const BuyProductScreen());
      case '/privacy-policy':
        return _page(PrivacyPolicyPage());
      case '/resetPassword':
        return _page(ResetPasswordScreen(), backToHome: false);
      case '/bought':
        return _page(const BoughtScreen());
      case '/products':
        return _page(const ProductsScreen());
      case '/product/add':
        return _page(const AddProductScreen());
      case '/store/add':
        return _page(const StoreScreen());
      case '/transfer_requests':
        return _page(const TransferRequestsScreen());
      case '/statistics':
        return _page(const StatisticsScreen());
      case '/clients':
        return _page(const ClientsScreen());
      case '/reports':
        return _page(CloseBookScreen());
      case '/client/select':
        return _page(const SelectClientScreen());
      case '/client/add':
        return _page(const AddClientScreen());
      case '/suppliers':
        return _page(const SuppliersScreen());
      case '/supplier/select':
        return _page(const SelectSupplierScreen());
      case '/supplier/add':
        return _page(const AddSupplierScreen());
      case '/supplier/edit':
        return _page(const EditSupplierScreen(), settings: settings);
      case '/employee/add':
        return _page(AddEmployeeScreen());
      case '/categories':
        return _page(const CategoriesScreen());
      case '/settings':
        return _page(const SettingsScreen());
      case '/subscription':
        return _page(SubscriptionScreen());
      case '/sms-credits':
        return _page(const SmsCreditsScreen());
      case '/support':
        return _page(const SupportScreen());
      case '/account':
        return _page(AccountScreen());
      case '/services':
        return _page(const ServicesScreen());
      case '/pay-roles':
        return _page(const PayRoleManagementScreen());
      case '/select-employee-pay-role':
        return _page(const SelectEmployeeForPayRoleScreen());
      case '/payment-management':
        return _page(const PaymentManagementScreen());
      case '/ledger':
        return _page(const LedgerHistoryScreen());
      case '/assets':
        return _page(const AssetsScreen());
      case '/inventory-losses':
        return _page(const InventoryLossScreen());
      default:
        return _page(const LoadingScreen(), backToHome: false);
    }
  }
}
