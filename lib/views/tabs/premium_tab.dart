import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../controllers/settings_controller.dart';

class PremiumTab extends StatelessWidget {
  const PremiumTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // Header Badge & Title
              Obx(() {
                final isPremium = settingsController.rxIsPremium.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPremium ? Icons.verified_rounded : Icons.star_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPremium ? 'premium_active'.tr : 'premium'.tr.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'premium_subtitle'.tr,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Feature Cards list
              _buildFeatureItem(Icons.bolt_rounded, 'faster_speed'.tr, 'Bypass limits and download at maximum bandwidth.', Colors.amber),
              _buildFeatureItem(Icons.all_inclusive_rounded, 'unlimited_downloads'.tr, 'Download files as much as you want without count caps.', Colors.greenAccent),
              _buildFeatureItem(Icons.block_rounded, 'no_ads'.tr, 'Zero annoying banner or full-screen advertisements.', Colors.pinkAccent),
              _buildFeatureItem(Icons.queue_play_next_rounded, 'Batch Downloads', 'Paste list of URLs and download all simultaneously.', Colors.cyanAccent),

              const SizedBox(height: 40),

              // Pricing Tiers
              Obx(() {
                final isPremium = settingsController.rxIsPremium.value;
                if (isPremium) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'You are a Pro Member!',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enjoy unlimited and lightning-fast downloads.',
                          style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () => settingsController.resetPremium(),
                          child: const Text('Cancel Mock Subscription', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Best Value Card (Monthly)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  topRight: Radius.circular(22),
                                ),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monthly Pass',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Full access for 30 days',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                const Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('\$4.99', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                                    Text('/ month', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: () => _purchasePremium(settingsController),
                                    child: Text('go_premium'.tr),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Other packages
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallTierCard(
                            'Weekly Pass',
                            '\$1.99',
                            '/ week',
                            () => _purchasePremium(settingsController),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSmallTierCard(
                            'Lifetime Access',
                            '\$19.99',
                            'one-time',
                            () => _purchasePremium(settingsController),
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () {},
                child: Text('restore_purchase'.tr, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 13)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _purchasePremium(SettingsController controller) {
    controller.activatePremium();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 28),
            SizedBox(width: 10),
            Text('Success'),
          ],
        ),
        content: const Text('Thank you! Premium has been unlocked successfully.'),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Awesome'),
          )
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTierCard(String name, String price, String interval, VoidCallback onTap, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkSurface.withOpacity(0.5) : AppTheme.lightSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(interval, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              child: const Text('Select', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
