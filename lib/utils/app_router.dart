import 'package:flutter/cupertino.dart';
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

class AppRouter {
  static Route onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/debt':
        return CupertinoPageRoute(builder: (_) => DebtHistoryScreen());
      case '/supplier-debt':
        return CupertinoPageRoute(builder: (_) => const SupplierDebtScreen(), settings: settings);
      case '/login':
        return CupertinoPageRoute(builder: (_) => const LoginScreen());
      case '/addemployee':
        return CupertinoPageRoute(builder: (_) => EmployeesScreen());
      case '/invoices':
        return CupertinoPageRoute(builder: (_) => const InvoicesScreen());
      case '/register':
        return CupertinoPageRoute(builder: (_) => RegisterScreen());
      case '/expenses':
        return CupertinoPageRoute(builder: (_) =>  const ExpenseListScreen(), settings: settings);
      case '/report':
        return CupertinoPageRoute(builder: (_) =>   ReportScreen());
      case '/add-expense':
    return CupertinoPageRoute(builder: (_) => AddExpenseScreen());
      case '/edit-expense':
        return CupertinoPageRoute(
          builder: (_) => EditExpenseScreen(),
          settings: settings, // Pass settings to ensure arguments are available
        );
      case '/home':
        return CupertinoPageRoute(
          builder: (_) => const HomeScreen());
    case '/sale/add':
        final args = settings.arguments;
        if (args is Map && args['userData'] is UserData) {
          return CupertinoPageRoute(builder: (_) => DualScreenApp(userData: args['userData']));
        }
        return CupertinoPageRoute(builder: (_) => DualScreenApp());
      case '/sales':
        return CupertinoPageRoute(builder: (_) => const SalesScreen());
      case '/cart':
        return CupertinoPageRoute(builder: (_) => const CartScreen());
      case '/buycart':
        return CupertinoPageRoute(builder: (_) => const BuyProductCartScreen());
      case '/buy':
        return CupertinoPageRoute(builder: (_) => const BuyProductScreen());
      case '/privacy-policy':
        return CupertinoPageRoute(builder: (_) =>  PrivacyPolicyPage());
      case '/resetPassword':
        return CupertinoPageRoute(builder: (_) => ResetPasswordScreen());
      case '/bought':
        return CupertinoPageRoute(builder: (_) => const BoughtScreen());
      case '/products':
        return CupertinoPageRoute(builder: (_) => const ProductsScreen());
      case '/product/add':
        return CupertinoPageRoute(builder: (_) => const AddProductScreen());
      case '/store/add':
        return CupertinoPageRoute(builder: (_) => const StoreScreen());
      case '/transfer_requests':
        return CupertinoPageRoute(builder: (_) => const TransferRequestsScreen());
      case '/statistics':
        return CupertinoPageRoute(builder: (_) => const StatisticsScreen());
      case '/clients':
        return CupertinoPageRoute(builder: (_) => const ClientsScreen());
      case '/reports':
        return CupertinoPageRoute(builder: (_) =>  CloseBookScreen());
      case '/client/select':
        return CupertinoPageRoute(builder: (_) => const SelectClientScreen());
      case '/client/add':
        return CupertinoPageRoute(
          builder: (_) => const AddClientScreen());
      case '/suppliers':
        return CupertinoPageRoute(builder: (_) => const SuppliersScreen());
      case '/supplier/select':
        return CupertinoPageRoute(builder: (_) => const SelectSupplierScreen());
      case '/supplier/add':
        return CupertinoPageRoute(
          builder: (_) => const AddSupplierScreen());
      case '/supplier/edit':
        return CupertinoPageRoute(
          settings: settings,
          builder: (_) => const EditSupplierScreen());
      case '/employee/add':
        return CupertinoPageRoute(
            builder: (_) =>  AddEmployeeScreen());
      case '/categories':
        return CupertinoPageRoute(builder: (_) => const CategoriesScreen());
      case '/settings':
        return CupertinoPageRoute(builder: (_) => const SettingsScreen());
      case '/support':
        return CupertinoPageRoute(builder: (_) => const SupportScreen());
      case '/account':
        return CupertinoPageRoute(builder: (_) =>  AccountScreen());
      case '/services':
        return CupertinoPageRoute(builder: (_) => const ServicesScreen());
      case '/pay-roles':
        return CupertinoPageRoute(builder: (_) => const PayRoleManagementScreen());
      case '/select-employee-pay-role':
        return CupertinoPageRoute(builder: (_) => const SelectEmployeeForPayRoleScreen());
      case '/payment-management':
        return CupertinoPageRoute(builder: (_) => const PaymentManagementScreen());
      case '/ledger':
        return CupertinoPageRoute(builder: (_) => const LedgerHistoryScreen());
      case '/assets':
        return CupertinoPageRoute(builder: (_) => const AssetsScreen());
      case '/inventory-losses':
        return CupertinoPageRoute(builder: (_) => const InventoryLossScreen());
      default:
        return CupertinoPageRoute(
          builder: (_) => const LoadingScreen(),
        );
    }
  }
}
