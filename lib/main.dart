import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme.dart';
import 'core/translations.dart';
import 'controllers/settings_controller.dart';
import 'controllers/download_controller.dart';
import 'views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage
  await GetStorage.init();

  // Initialize media_kit (required before any Player/VideoController usage)
  MediaKit.ensureInitialized();

  // Instantiate global controllers
  Get.put(SettingsController(), permanent: true);
  Get.put(DownloadController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Obx(() {
      final isDark = settingsController.rxIsDarkMode.value;
      final lang = settingsController.rxLanguageCode.value;

      return GetMaterialApp(
        title: 'Jronix Downloader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        translations: AppTranslations(),
        locale: Locale(lang),
        fallbackLocale: const Locale('en'),
        home: const SplashScreen(),
      );
    });
  }
}
