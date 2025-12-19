import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/auth_controller.dart';
import 'package:mauzo/controllers/theme_controller.dart';
import 'package:mauzo/models/themes_model.dart';
import 'package:mauzo/utils/app_router.dart';
import 'package:mauzo/utils/languages.dart';
import 'firebase_options.dart';
import 'utils/preferences.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log or handle Flutter errors
    print('Flutter Error: ${details.exceptionAsString()}');
    print('Stack trace: ${details.stack}');
    FlutterError.presentError(details);
  };

  // Capture Dart runtime errors (async errors)
  runZonedGuarded(
        () async {
      await Preferences.init().then((value) {
       // Get.put(ProfileController(), permanent: true);
        print("ProfileController initialized");

        //Get.put(BusinessController(), permanent: true);
        print("BusinessController initialized");
      });

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).then((value) => Get.put(AuthController()));
      getLocale();

      runApp(const MyApp());
    },
        (error, stackTrace) {
      // Log or handle Dart errors
      print('Dart Error: $error');
      print('Stack trace: $stackTrace');
    },
  );
}

Locale locale = const Locale('sw', 'TZ');

void getLocale() {
  if (Preferences.getLanguage() == 'Kiswahili') {
    locale = const Locale('sw', 'TZ');
  }
  if (Preferences.getLanguage() == 'english') {
    locale = const Locale('en', 'US');
  } else if (Preferences.getLanguage() == 'russian') {
    locale = const Locale('ru', 'RU');
  } else if (Preferences.getLanguage() == 'uzbek') {
    locale = const Locale('uz', 'UZ');
  } else if (Preferences.getLanguage() == 'spanish') {
    locale = const Locale('es', 'ES');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.put(ThemeController());

    return GetMaterialApp(
      translations: Languages(),
      locale: locale,
      fallbackLocale: const Locale('sw', 'TZ'),
      debugShowCheckedModeBanner: false,
      title: 'mauzo',
      themeMode: themeController.theme,
      theme: Themes.lightTheme,
      darkTheme: Themes.darkTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
