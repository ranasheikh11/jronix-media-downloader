import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../controllers/download_controller.dart';
import '../../models/download_task.dart';
import '../../models/media_info.dart';
import '../preview_screen.dart'; // To open preview player if clicked

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final DownloadController downloadController = Get.find<DownloadController>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
            child: TabBar(
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              tabs: [
                Tab(text: 'download_queue'.tr),
                Tab(text: 'recent_downloads'.tr),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            // Search Bar for completed downloads
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search downloads...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Active Downloads Tab
                  Obx(() {
                    final activeTasks = downloadController.rxActiveTasks;
                    if (activeTasks.isEmpty) {
                      return _buildEmptyState(
                        Icons.downloading_rounded,
                        'No active downloads',
                        'Paste a link on the Home page to start downloading.',
                        isDark,
                      );
                    }
                    return ListView.builder(
                      itemCount: activeTasks.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final task = activeTasks[index];
                        return _buildActiveTaskCard(task, isDark);
                      },
                    );
                  }),

                  // Completed Downloads Tab
                  Obx(() {
                    var completedTasks = downloadController.rxHistoryTasks;
                    if (_searchQuery.isNotEmpty) {
                      completedTasks = completedTasks
                          .where((t) => t.title.toLowerCase().contains(_searchQuery))
                          .toList()
                          .obs;
                    }

                    if (completedTasks.isEmpty) {
                      return _buildEmptyState(
                        Icons.folder_off_rounded,
                        'no_downloads'.tr,
                        'empty_history_desc'.tr,
                        isDark,
                      );
                    }
                    return ListView.builder(
                      itemCount: completedTasks.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final task = completedTasks[index];
                        return _buildHistoryTaskCard(task, isDark);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Active Task Queue Cards
  Widget _buildActiveTaskCard(DownloadTask task, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: isDark ? 0 : 2,
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Thumbnail/Platform Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: task.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          task.thumbnailUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlatformIcon(task.platform),
                        )
                      : _buildPlatformIcon(task.platform),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildPlatformMiniBadge(task.platform),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              task.quality,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Play/Pause & Cancel buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.status == DownloadStatus.downloading)
                      IconButton(
                        icon: const Icon(Icons.pause_circle_outline, color: AppTheme.primary, size: 28),
                        onPressed: () => downloadController.pauseDownload(task.id),
                      )
                    else if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed)
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline, color: AppTheme.primary, size: 28),
                        onPressed: () => downloadController.resumeDownload(task.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 24),
                      onPressed: () => downloadController.cancelDownload(task.id),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 6,
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            // Speed / Size / ETA Text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.status == DownloadStatus.downloading
                      ? '${'speed'.tr}: ${task.speed}'
                      : task.status.name.capitalizeFirst!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(task.progress * 100).toStringAsFixed(1)}% of ${task.sizeString}',
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
                Text(
                  '${'remaining'.tr}: ${task.eta}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // History Completed Task Cards
  Widget _buildHistoryTaskCard(DownloadTask task, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: isDark ? 0 : 2,
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDownloadedMedia(task),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail/Platform Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: task.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        task.thumbnailUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlatformIcon(task.platform),
                      )
                    : _buildPlatformIcon(task.platform),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildPlatformMiniBadge(task.platform),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${task.quality} • ${task.formatExtension.toUpperCase()} • ${task.sizeString}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Play/Share/Delete options
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 20, color: AppTheme.accent),
                    onPressed: () => _shareMedia(task),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                    onPressed: () => _showDeleteConfirmDialog(task),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Opens media player in App or launches external player
  void _openDownloadedMedia(DownloadTask task) {
    if (task.savePath.isEmpty || !File(task.savePath).existsSync()) {
      Get.snackbar('Error', 'File not found locally. It may have been deleted.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Since our PreviewScreen includes an interactive video player, audio wave player, and image zoom,
    // we can reuse the PreviewScreen for saved files! This provides a stellar integrated local media player experience!
    // We will build a dummy MediaInfo corresponding to this task and direct it.
    final mockInfo = mediaInfoFromTask(task);
    Get.to(() => PreviewScreen(mediaInfo: mockInfo, localFilePath: task.savePath), transition: Transition.zoom, duration: const Duration(milliseconds: 300));
  }

  // Share downloaded file
  void _shareMedia(DownloadTask task) {
    if (task.savePath.isNotEmpty && File(task.savePath).existsSync()) {
      Share.shareXFiles([XFile(task.savePath)], text: task.title);
    } else {
      Get.snackbar('Error', 'File not found to share.', snackPosition: SnackPosition.BOTTOM);
    }
  }

  // Show delete confirm dialog
  void _showDeleteConfirmDialog(DownloadTask task) {
    Get.dialog(
      AlertDialog(
        title: Text('delete'.tr),
        content: Text('Are you sure you want to delete "${task.title}" from history?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              downloadController.deleteFromHistory(task, false); // Keep file
              Get.back();
            },
            child: const Text('Delete History Only', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              downloadController.deleteFromHistory(task, true); // Delete file too
              Get.back();
            },
            child: const Text('Delete File & History'),
          ),
        ],
      ),
    );
  }

  // Platform styling helpers
  Widget _buildPlatformIcon(String platform) {
    IconData iconData = Icons.cloud_download_rounded;
    Color color = Colors.grey;

    switch (platform) {
      case 'youtube':
        iconData = Icons.video_library_rounded;
        color = Colors.red;
        break;
      case 'facebook':
        iconData = Icons.facebook_rounded;
        color = Colors.blue;
        break;
      case 'instagram':
        iconData = Icons.camera_alt_rounded;
        color = Colors.purple;
        break;
      case 'tiktok':
        iconData = Icons.music_note_rounded;
        color = Colors.teal;
        break;
      case 'twitter':
        iconData = Icons.alternate_email_rounded;
        color = Colors.lightBlue;
        break;
    }

    return Container(
      width: 50,
      height: 50,
      color: color.withOpacity(0.15),
      child: Icon(iconData, color: color),
    );
  }

  Widget _buildPlatformMiniBadge(String platform) {
    String name = platform.toUpperCase();
    Color color = Colors.grey;

    switch (platform) {
      case 'youtube':
        color = Colors.red;
        break;
      case 'facebook':
        color = Colors.blue;
        break;
      case 'instagram':
        color = Colors.purple;
        break;
      case 'tiktok':
        color = Colors.teal;
        break;
      case 'twitter':
        color = Colors.lightBlue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String desc, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: isDark ? AppTheme.darkSurface : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

MediaInfo mediaInfoFromTask(DownloadTask task) {
  return MediaInfo(
    title: task.title,
    description: 'Downloaded locally to ${task.savePath}',
    thumbnailUrl: task.thumbnailUrl,
    platform: task.platform,
    originalUrl: task.downloadUrl,
    formats: [
      DownloadFormat(
        quality: task.quality,
        formatExtension: task.formatExtension,
        sizeBytes: task.totalSizeBytes,
        downloadUrl: task.downloadUrl,
      )
    ],
  );
}
