import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../controllers/url_analyzer.dart';
import '../preview_screen.dart';

class HomeTabController extends GetxController {
  final urlController = TextEditingController();
  final rxClipboardUrl = ''.obs;
  final rxShowClipboardBanner = false.obs;

  void suggestClipboardUrl(String url) {
    if (urlController.text != url) {
      rxClipboardUrl.value = url;
      rxShowClipboardBanner.value = true;
    }
  }

  void acceptClipboardSuggestion() {
    urlController.text = rxClipboardUrl.value;
    rxShowClipboardBanner.value = false;
  }

  void clearClipboardSuggestion() {
    rxShowClipboardBanner.value = false;
  }

  @override
  void onClose() {
    urlController.dispose();
    super.onClose();
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeTabController());
    final analyzer = Get.put(URLAnalyzerController());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              const SizedBox(height: 10),
              Text(
                'paste_prompt'.tr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Clipboard Banner (Animated slide down)
              Obx(() {
                if (!controller.rxShowClipboardBanner.value) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_returned_rounded, color: AppTheme.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'detected_clipboard'.tr,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              controller.rxClipboardUrl.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.primary.withOpacity(0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: controller.acceptClipboardSuggestion,
                        child: Text('yes'.tr, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: controller.clearClipboardSuggestion,
                      ),
                    ],
                  ),
                );
              }),

              // Input Field Glassmorphic Container
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (isDark)
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.05),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: TextField(
                  controller: controller.urlController,
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.primary),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller.urlController,
                      builder: (context, value, child) {
                        final showClear = value.text.isNotEmpty;
                        return SizedBox(
                          width: showClear ? 96 : 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.paste_rounded, color: AppTheme.primary),
                                onPressed: () async {
                                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                                  if (data?.text != null) {
                                    controller.urlController.text = data!.text!;
                                  }
                                },
                              ),
                              if (showClear)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () => controller.urlController.clear(),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  onSubmitted: (url) => _analyzeLink(context, analyzer, url),
                ),
              ),
              const SizedBox(height: 20),

              // Download Button with glowing gradient
              SizedBox(
                width: double.infinity,
                height: 58,
                child: Obx(() {
                  final isAnalyzing = analyzer.rxIsAnalyzing.value;
                  return ElevatedButton(
                    onPressed: isAnalyzing
                        ? null
                        : () => _analyzeLink(context, analyzer, controller.urlController.text),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: isAnalyzing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'analyzing'.tr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'download_button'.tr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Error messages
              Obx(() {
                if (analyzer.rxError.value.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    analyzer.rxError.value,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
              const SizedBox(height: 36),

              // Supported Platforms List
              Text(
                'popular_platforms'.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildPlatformCard('YouTube', Icons.video_library_rounded, Colors.red, isDark),
                  _buildPlatformCard('Facebook', Icons.facebook_rounded, Colors.blue, isDark),
                  _buildPlatformCard('Instagram', Icons.camera_alt_rounded, Colors.purple, isDark),
                  _buildPlatformCard('TikTok', Icons.music_note_rounded, Colors.teal, isDark),
                  _buildPlatformCard('Twitter/X', Icons.alternate_email_rounded, Colors.lightBlue, isDark),
                  _buildPlatformCard('Direct Link', Icons.cloud_download_rounded, Colors.indigo, isDark),
                ],
              ),
              const SizedBox(height: 40),

              // Safety / Copyright Disclaimer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard.withOpacity(0.5) : AppTheme.lightSurface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'terms_service'.tr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'disclaimer'.tr,
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle link analysis
  Future<void> _analyzeLink(BuildContext context, URLAnalyzerController analyzer, String url) async {
    final trimmed = url.trim();
    debugPrint('[HomeTab] _analyzeLink called with: "$trimmed"');
    if (trimmed.isEmpty) {
      Get.snackbar('invalid_url'.tr, 'paste_prompt'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final info = await analyzer.analyzeURL(trimmed);
    debugPrint('[HomeTab] analyzeURL returned: ${info == null ? "NULL" : "OK title=${info.title}"}');
    if (info != null) {
      Get.to(() => PreviewScreen(mediaInfo: info), transition: Transition.rightToLeft, duration: const Duration(milliseconds: 300));
    } else {
      // Show the error that was set by the analyzer
      final errMsg = analyzer.rxError.value;
      if (errMsg.isNotEmpty) {
        Get.snackbar(
          'Extraction Failed',
          errMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.all(12),
        );
      }
    }
  }


  Widget _buildPlatformCard(String label, IconData icon, Color color, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkSurface.withOpacity(0.5) : AppTheme.lightSurface,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
