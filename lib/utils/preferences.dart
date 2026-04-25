import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static SharedPreferences? _prefs;
  static final ProfileController _profileController = Get.find();

  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  static Future<void> setUserId(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
  }
  static Future<void> setBusinessId(String businessId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('businessId', businessId);
  }
  static Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  static Future<String?> getBusinessId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('businessId');
  }

  // Existing methods for setPhone, setPassword, setLoggedIn, etc.
  static String? getUserId() {
    final SharedPreferences prefs = SharedPreferences.getInstance() as SharedPreferences;
    return prefs.getString('userId');
  }
  // * Profile data
  static bool isLoggedIn() {
    return _prefs?.getBool('isLoggedIn') ?? false;
  }

  static setLoggedIn(bool value) async {
    await _prefs?.setBool('isLoggedIn', value);
  }

  static String getPhone() {
    return _prefs?.getString('phone') ?? '';
  }
  static String getEmail() {
    return _prefs?.getString('email') ?? '';
  }
  static String getBusiness() {
    return _prefs?.getString('business') ?? '';
  }
  static String getPassword() {
    return _prefs?.getString('password') ?? '';
  }
  static setPhone(String value) async {
    await _prefs?.setString('phone', value);
  }

  static setEmail(String value) async {
    await _prefs?.setString('email', value);
  }
  static setBusiness(String value) async {
    await _prefs?.setString('business', value);
  }
  static setPassword(String value) async {
    await _prefs?.setString('password', value);
  }

  static getCurrencies() {
    final List<String> currencies = [
      _profileController.user['mainCurrency'],
      _profileController.user['secondaryCurrency'],
    ];
    return currencies;
  }

  // * Exchange rates
  static Future setExchangeRate(double value) async {
    await _prefs?.setDouble('rate', value);
  }

  static getExchangeRate() => _prefs?.getDouble('rate') ?? 0;

  static Future setExchangeRateDate(String value) async {
    await _prefs?.setString('rateDate', value);
  }

  static getExchangeRateDate() => _prefs?.getString('rateDate') ?? '';

  static Future setExchangeRateAdjustment(double value) async {
    await _prefs?.setDouble('rateAdjustment', value);
  }

  static getExchangeRateAdjustment() =>
      _prefs?.getDouble('rateAdjustment') ?? 0;

  static Future setExchangeRateType(String value) async {
    await _prefs?.setString('rateType', value);
  }

  static getExchangeRateType() => _prefs?.getString('rateType') ?? 'auto';

  static getExchangeRateResult() {
    return getExchangeRate() + getExchangeRateAdjustment();
  }

  // * Themes
  static Future setTheme(value) async {
    await _prefs?.setBool('isDarkMode', value);
  }

  static getTheme() => _prefs?.getBool('isDarkMode') ?? false;
  // * Notification

  static Future setNotification(value) async {
    await _prefs?.setBool('isNotificationEnabled', value);
  }
  static Future setEnabletDebt(value) async {
    await _prefs?.setBool('isDebtEnabled', value);
  }
  static Future setSalesvesView(value) async {
    await _prefs?.setBool('isSalesViewEnabled', value);
  }
  static getNotification() => _prefs?.getBool('isNotificationEnabled') ?? false;
  static getEnableDebt() => _prefs?.getBool('isDebtEnabled') ?? false;
  static getSalesvesView() => _prefs?.getBool('isSalesViewEnabled') ?? false;
  // * Language
  static Future setLanguage(value) async {
    await _prefs?.setString('language', value);
  }

  static getLanguage() => _prefs?.getString('language') ?? 'kiswahili';

// Add to Preferences class
  static Future<void> setStockDisplayPreference(bool isBuyingStock) async {
    await _prefs?.setBool('stockDisplayPreference', isBuyingStock);
  }

  static bool getStockDisplayPreference() {
    return _prefs?.getBool('stockDisplayPreference') ?? false; // Default to selling price
  }

  // Save the 'isPurchasesEnabled' setting as a String
  static Future<void> setEnablePurchases(String value) async {
    await _prefs?.setString('isPurchasesEnabledd', value);
  }

  // Retrieve the 'isPurchasesEnabled' setting as a String
  static String getEnablePurchases() {
    return _prefs?.getString('isPurchasesEnabledd') ?? 'false';
  }

  // Usage example in a widget (convert String to bool if needed)
  static bool isPurchasesEnabled() {
    return getEnablePurchases() == 'true';
  }
}
