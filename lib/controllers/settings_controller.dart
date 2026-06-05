import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../core/storage_keys.dart';

class SettingsController extends GetxController {
  final _storage = GetStorage();
  
  final rxIsDarkMode = true.obs;
  final rxLanguageCode = 'en'.obs;
  final rxIsPremium = false.obs;
  final rxCustomDownloadPath = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Load saved settings or use defaults
    rxIsDarkMode.value = _storage.read(StorageKeys.isDarkMode) ?? true;
    rxLanguageCode.value = _storage.read(StorageKeys.languageCode) ?? 'en';
    rxIsPremium.value = _storage.read(StorageKeys.isPremium) ?? false;
    rxCustomDownloadPath.value = _storage.read(StorageKeys.downloadFolder) ?? '';
    
    // Apply theme & language
    _applyTheme();
    _applyLocale();
  }

  void toggleTheme() {
    rxIsDarkMode.value = !rxIsDarkMode.value;
    _storage.write(StorageKeys.isDarkMode, rxIsDarkMode.value);
    _applyTheme();
  }

  void changeLanguage(String langCode) {
    if (langCode == 'en' || langCode == 'bn') {
      rxLanguageCode.value = langCode;
      _storage.write(StorageKeys.languageCode, langCode);
      _applyLocale();
    }
  }

  void activatePremium() {
    rxIsPremium.value = true;
    _storage.write(StorageKeys.isPremium, true);
  }

  void resetPremium() {
    rxIsPremium.value = false;
    _storage.write(StorageKeys.isPremium, false);
  }

  void setDownloadPath(String path) {
    rxCustomDownloadPath.value = path;
    _storage.write(StorageKeys.downloadFolder, path);
  }

  void _applyTheme() {
    Get.changeThemeMode(rxIsDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  void _applyLocale() {
    Get.updateLocale(Locale(rxLanguageCode.value));
  }
}
