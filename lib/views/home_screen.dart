import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../controllers/settings_controller.dart';
import '../controllers/download_controller.dart';
import 'tabs/home_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/premium_tab.dart';
import 'tabs/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final SettingsController settingsController = Get.find<SettingsController>();
  final DownloadController downloadController = Get.find<DownloadController>();

  final List<Widget> _tabs = [
    const HomeTab(),
    const HistoryTab(),
    const PremiumTab(),
    const SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  // Detect and prompt user if a media link is in the clipboard
  Future<void> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text ?? '';
      if (text.isNotEmpty && (text.startsWith('http://') || text.startsWith('https://'))) {
        // Find HomeTab controller and suggest URL
        if (Get.isRegistered<HomeTabController>()) {
          Get.find<HomeTabController>().suggestClipboardUrl(text);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_rounded, color: AppTheme.primary, size: 26),
            const SizedBox(width: 8),
            Flexible(
              child: ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                child: Text(
                  'app_title'.tr,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Active downloads count badge
          Obx(() {
            final activeCount = downloadController.rxActiveTasks.length;
            if (activeCount == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = 1), // Navigate to history/downloads
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Premium badge
          Obx(() {
            if (settingsController.rxIsPremium.value) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'active'.tr.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              );
            }
            return IconButton(
              icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
              onPressed: () => setState(() => _currentIndex = 2), // Go to premium
            );
          }),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : Colors.grey.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
            indicatorColor: AppTheme.primary.withOpacity(0.15),
            elevation: 0,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded, color: AppTheme.primary),
                label: 'app_title'.tr.split(' ').first,
              ),
              NavigationDestination(
                icon: const Icon(Icons.download_for_offline_outlined),
                selectedIcon: const Icon(Icons.download_for_offline_rounded, color: AppTheme.primary),
                label: 'history'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.workspace_premium_outlined),
                selectedIcon: const Icon(Icons.workspace_premium_rounded, color: AppTheme.primary),
                label: 'premium'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded, color: AppTheme.primary),
                label: 'settings'.tr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
