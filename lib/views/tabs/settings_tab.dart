import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/download_controller.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    final downloadController = Get.find<DownloadController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Theme Settings Card
          _buildSectionHeader('theme'.tr, isDark),
          _buildCard(
            children: [
              Obx(
                () => SwitchListTile(
                  title: Text('dark_mode'.tr),
                  secondary: Icon(
                    Icons.dark_mode_rounded,
                    color: isDark ? AppTheme.primary : Colors.grey,
                  ),
                  value: settingsController.rxIsDarkMode.value,
                  activeColor: AppTheme.primary,
                  onChanged: (bool val) {
                    settingsController.toggleTheme();
                  },
                ),
              ),
            ],
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Language Settings Card
          _buildSectionHeader('language'.tr, isDark),
          _buildCard(
            children: [
              Obx(
                () => RadioListTile<String>(
                  title: Text('english'.tr),
                  secondary: const Icon(Icons.language_rounded),
                  value: 'en',
                  groupValue: settingsController.rxLanguageCode.value,
                  activeColor: AppTheme.primary,
                  onChanged: (String? val) {
                    if (val != null) settingsController.changeLanguage(val);
                  },
                ),
              ),
              Divider(
                height: 1,
                color: isDark
                    ? AppTheme.darkSurface.withOpacity(0.5)
                    : AppTheme.lightSurface,
              ),
              Obx(
                () => RadioListTile<String>(
                  title: Text('bangla'.tr),
                  secondary: const Icon(Icons.language_rounded),
                  value: 'bn',
                  groupValue: settingsController.rxLanguageCode.value,
                  activeColor: AppTheme.primary,
                  onChanged: (String? val) {
                    if (val != null) settingsController.changeLanguage(val);
                  },
                ),
              ),
            ],
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Storage Settings Card
          _buildSectionHeader('Storage Management', isDark),
          _buildCard(
            children: [
              ListTile(
                title: const Text('Download Folder'),
                subtitle: Obx(() {
                  final path = settingsController.rxCustomDownloadPath.value;
                  return Text(
                    path.isEmpty
                        ? 'System Default (Downloads / Documents)'
                        : path,
                    style: const TextStyle(fontSize: 12),
                  );
                }),
                leading: const Icon(
                  Icons.folder_shared_rounded,
                  color: AppTheme.primary,
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  // Simulate choosing directory
                  Get.snackbar(
                    'Default Storage Location',
                    'Downloads will save to your system folder.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
              Divider(
                height: 1,
                color: isDark
                    ? AppTheme.darkSurface.withOpacity(0.5)
                    : AppTheme.lightSurface,
              ),
              ListTile(
                title: const Text('Clear Download History'),
                subtitle: const Text(
                  'Remove metadata records. Downloaded files remain.',
                ),
                leading: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.orangeAccent,
                ),
                onTap: () {
                  Get.dialog(
                    AlertDialog(
                      title: const Text('Clear History'),
                      content: const Text(
                        'Are you sure you want to clear your download history logs? The downloaded files will not be deleted from storage.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('cancel'.tr),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () {
                            downloadController.clearAllHistory();
                            Get.back();
                            Get.snackbar('Success', 'History cleared.');
                          },
                          child: const Text('Clear History'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Premium status card
          _buildSectionHeader('Premium Features', isDark),
          _buildCard(
            children: [
              Obx(() {
                final isPremium = settingsController.rxIsPremium.value;
                return ListTile(
                  title: Text(isPremium ? 'Premium Active' : 'Go Premium'),
                  subtitle: Text(
                    isPremium
                        ? 'Lifetime professional pass active'
                        : 'Click to unlock high-speed downloading',
                  ),
                  leading: Icon(
                    Icons.workspace_premium_rounded,
                    color: isPremium ? Colors.amber : Colors.grey,
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    if (isPremium) {
                      Get.snackbar('Pro Active', 'Thank you for your support!');
                    } else {
                      // Navigate to Premium tab (we trigger tab index switch by modifying home view,
                      // or just show package alert)
                      settingsController.activatePremium();
                      Get.snackbar(
                        'Premium Activated',
                        'Mock premium mode unlocked.',
                      );
                    }
                  },
                );
              }),
            ],
            isDark: isDark,
          ),
          const SizedBox(height: 36),

          // Footer version info
          Center(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'JronixDOWNLOADER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0 (Build 2026)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppTheme.darkSurface.withOpacity(0.5)
              : AppTheme.lightSurface,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
