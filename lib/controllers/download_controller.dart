import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/storage_keys.dart';
import '../models/media_info.dart';
import '../models/download_task.dart';

class DownloadController extends GetxController {
  final Dio _dio = Dio();
  final _storage = GetStorage();
  
  final rxActiveTasks = <DownloadTask>[].obs;
  final rxHistoryTasks = <DownloadTask>[].obs;

  // Track active dio CancelTokens by task ID
  final Map<String, CancelToken> _cancelTokens = {};
  
  // Track speed calculation variables by task ID
  final Map<String, _SpeedTracker> _speedTrackers = {};

  @override
  void onInit() {
    super.onInit();
    _loadHistory();
  }

  void _loadHistory() {
    final List<dynamic>? stored = _storage.read(StorageKeys.downloadHistory);
    if (stored != null) {
      rxHistoryTasks.assignAll(
        stored.map((json) => DownloadTask.fromJson(json as Map<String, dynamic>)).toList()
      );
    }
  }

  void _saveHistory() {
    _storage.write(
      StorageKeys.downloadHistory,
      rxHistoryTasks.map((t) => t.toJson()).toList(),
    );
  }

  // Check and request storage permission correctly for each Android version
  Future<bool> requestStoragePermission() async {
    if (Platform.isIOS) return true;

    // Android 13+ (API 33+): READ_EXTERNAL_STORAGE is deprecated.
    // Use granular media permissions instead.
    if (await _isAndroid13OrAbove()) {
      final video = await Permission.videos.request();
      final audio = await Permission.audio.request();
      // We only need one to succeed since we save to /Download directly
      if (video.isGranted || audio.isGranted) return true;

      // Fallback: try MANAGE_EXTERNAL_STORAGE for full access
      if (await Permission.manageExternalStorage.isGranted) return true;
      final manage = await Permission.manageExternalStorage.request();
      return manage.isGranted;
    }

    // Android < 13: classic WRITE_EXTERNAL_STORAGE
    var status = await Permission.storage.status;
    if (status.isGranted) return true;
    status = await Permission.storage.request();
    if (status.isGranted) return true;

    // If permanently denied, open app settings
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<bool> _isAndroid13OrAbove() async {
    if (!Platform.isAndroid) return false;
    // DeviceInfoPlugin alternative: check via permission API availability
    // videos permission only exists on Android 13+
    return await Permission.videos.status != PermissionStatus.restricted;
  }

  // Start a new download
  Future<void> startDownload(MediaInfo media, DownloadFormat format) async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      Get.snackbar(
        'storage_permission'.tr,
        'storage_permission_denied'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final taskId = '${DateTime.now().millisecondsSinceEpoch}';
    
    // Choose appropriate save folder (Documents for ease of sandboxing, or Downloads on Android)
    Directory? saveDir;
    if (Platform.isAndroid) {
      saveDir = Directory('/storage/emulated/0/Download');
      if (!await saveDir.exists()) {
        saveDir = await getExternalStorageDirectory();
      }
    } else {
      saveDir = await getApplicationDocumentsDirectory();
    }

    final safeTitle = media.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String savePath = '${saveDir!.path}/$safeTitle.${format.formatExtension}';

    final task = DownloadTask(
      id: taskId,
      title: media.title,
      platform: media.platform,
      thumbnailUrl: media.thumbnailUrl,
      quality: format.quality,
      formatExtension: format.formatExtension,
      downloadUrl: format.downloadUrl,
      savePath: savePath,
      status: DownloadStatus.queued,
      dateAdded: DateTime.now(),
      totalSizeBytes: format.sizeBytes,
    );

    rxActiveTasks.add(task);
    Get.snackbar(
      'download_started'.tr,
      media.title,
      snackPosition: SnackPosition.BOTTOM,
    );

    _runTask(task);
  }

  // Run or Resume a task
  Future<void> _runTask(DownloadTask task) async {
    final index = rxActiveTasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    rxActiveTasks[index] = task.copyWith(
      status: DownloadStatus.downloading,
      speed: '0 KB/s',
      eta: '--',
    );

    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    final tracker = _SpeedTracker();
    _speedTrackers[task.id] = tracker;

    final String url = task.downloadUrl;
    final String path = task.savePath;

    try {
      int startBytes = 0;
      final file = File(path);

      // Simple Range check (to support real pausing and resuming if server permits it)
      final bool exists = await file.exists();
      if (exists && task.downloadedBytes > 0) {
        startBytes = await file.length();
        // sanity check
        if (startBytes > task.totalSizeBytes) {
          startBytes = 0;
          await file.delete();
        }
      } else {
        if (exists) await file.delete();
      }

      tracker.start(startBytes);

      // Options for range download
      Options options = Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': 'https://www.google.com/',
          if (startBytes > 0) 'Range': 'bytes=$startBytes-',
        },
      );

      final response = await _dio.get(
        url,
        cancelToken: cancelToken,
        options: options,
      );

      // Open file in append or write mode
      final IOSink sink = file.openWrite(mode: startBytes > 0 ? FileMode.append : FileMode.write);
      int downloaded = startBytes;
      
      final ResponseBody responseBody = response.data as ResponseBody;
      
      await for (final List<int> chunk in responseBody.stream) {
        if (cancelToken.isCancelled) {
          await sink.flush();
          await sink.close();
          return;
        }

        sink.add(chunk);
        downloaded += chunk.length;
        
        // Calculate progress, speed, and remaining time
        final timeNow = DateTime.now();
        final stats = tracker.update(downloaded, timeNow, task.totalSizeBytes);
        
        final taskIndex = rxActiveTasks.indexWhere((t) => t.id == task.id);
        if (taskIndex != -1) {
          rxActiveTasks[taskIndex] = rxActiveTasks[taskIndex].copyWith(
            progress: task.totalSizeBytes > 0 ? (downloaded / task.totalSizeBytes) : 0.0,
            downloadedBytes: downloaded,
            speed: stats.speedString,
            eta: stats.etaString,
          );
        }
      }

      await sink.flush();
      await sink.close();

      // Download completed
      final finalIndex = rxActiveTasks.indexWhere((t) => t.id == task.id);
      if (finalIndex != -1) {
        final completedTask = rxActiveTasks[finalIndex].copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          speed: '0 KB/s',
          eta: '0s',
        );
        
        rxActiveTasks.removeAt(finalIndex);
        
        // Add to history
        rxHistoryTasks.insert(0, completedTask);
        _saveHistory();

        Get.snackbar(
          'download_completed'.tr,
          completedTask.title,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      
      _cleanTrackers(task.id);

    } catch (e) {
      _cleanTrackers(task.id);
      
      if (CancelToken.isCancel(e as DioException)) {
        // Paused or Cancelled
        return;
      }

      // Failed
      final errIndex = rxActiveTasks.indexWhere((t) => t.id == task.id);
      if (errIndex != -1) {
        final failedTask = rxActiveTasks[errIndex].copyWith(
          status: DownloadStatus.failed,
          speed: '0 KB/s',
          eta: '--',
        );
        rxActiveTasks[errIndex] = failedTask;
        
        Get.snackbar(
          'download_failed'.tr,
          failedTask.title,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  // Pause download
  void pauseDownload(String taskId) {
    final index = rxActiveTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = rxActiveTasks[index];
    if (task.status == DownloadStatus.downloading) {
      _cancelTokens[taskId]?.cancel('paused');
      rxActiveTasks[index] = task.copyWith(
        status: DownloadStatus.paused,
        speed: '0 KB/s',
        eta: '--',
      );
      _cleanTrackers(taskId);
    }
  }

  // Resume download
  void resumeDownload(String taskId) {
    final index = rxActiveTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = rxActiveTasks[index];
    if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed) {
      _runTask(task);
    }
  }

  // Cancel download
  void cancelDownload(String taskId) {
    final index = rxActiveTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    _cancelTokens[taskId]?.cancel('cancelled');
    rxActiveTasks.removeAt(index);
    _cleanTrackers(taskId);
  }

  // Delete from History
  void deleteFromHistory(DownloadTask task, bool deleteFile) {
    rxHistoryTasks.removeWhere((t) => t.id == task.id);
    _saveHistory();

    if (deleteFile && task.savePath.isNotEmpty) {
      try {
        final file = File(task.savePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  void clearAllHistory() {
    rxHistoryTasks.clear();
    _saveHistory();
  }

  void _cleanTrackers(String taskId) {
    _cancelTokens.remove(taskId);
    _speedTrackers.remove(taskId);
  }
}

class _SpeedTracker {
  late DateTime _startTime;
  late int _startBytes;
  late DateTime _lastUpdateTime;
  late int _lastBytes;
  double _currentSpeedBytesPerSec = 0.0;

  void start(int bytes) {
    _startTime = DateTime.now();
    _startBytes = bytes;
    _lastUpdateTime = _startTime;
    _lastBytes = bytes;
  }

  _SpeedStats update(int currentBytes, DateTime now, int totalBytes) {
    final intervalMs = now.difference(_lastUpdateTime).inMilliseconds;
    
    // Update speed every 500ms to avoid high volatility
    if (intervalMs >= 500) {
      final bytesSinceLast = currentBytes - _lastBytes;
      final double speed = (bytesSinceLast / (intervalMs / 1000.0));
      // exponential smoothing
      _currentSpeedBytesPerSec = _currentSpeedBytesPerSec == 0 
          ? speed 
          : (_currentSpeedBytesPerSec * 0.7) + (speed * 0.3);

      _lastUpdateTime = now;
      _lastBytes = currentBytes;
    }

    // Format speed string
    String speedStr = '0 KB/s';
    if (_currentSpeedBytesPerSec > 0) {
      if (_currentSpeedBytesPerSec >= 1024 * 1024) {
        speedStr = '${(_currentSpeedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      } else {
        speedStr = '${(_currentSpeedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
      }
    }

    // Format ETA
    String etaStr = '--';
    if (_currentSpeedBytesPerSec > 0 && totalBytes > currentBytes) {
      final remainingBytes = totalBytes - currentBytes;
      final secondsRemaining = (remainingBytes / _currentSpeedBytesPerSec).round();
      
      if (secondsRemaining < 60) {
        etaStr = '${secondsRemaining}s';
      } else {
        final minutes = (secondsRemaining / 60).floor();
        final seconds = secondsRemaining % 60;
        etaStr = '${minutes}m ${seconds}s';
      }
    }

    return _SpeedStats(speedString: speedStr, etaString: etaStr);
  }
}

class _SpeedStats {
  final String speedString;
  final String etaString;

  _SpeedStats({required this.speedString, required this.etaString});
}
