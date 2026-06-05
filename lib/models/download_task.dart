enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  final String id;
  final String title;
  final String platform;
  final String thumbnailUrl;
  final String quality;
  final String formatExtension;
  final String downloadUrl;
  String savePath;
  double progress;
  String speed;
  String eta;
  DownloadStatus status;
  final DateTime dateAdded;
  final int totalSizeBytes;
  int downloadedBytes;

  DownloadTask({
    required this.id,
    required this.title,
    required this.platform,
    required this.thumbnailUrl,
    required this.quality,
    required this.formatExtension,
    required this.downloadUrl,
    required this.savePath,
    this.progress = 0.0,
    this.speed = '0 KB/s',
    this.eta = '--',
    this.status = DownloadStatus.queued,
    required this.dateAdded,
    required this.totalSizeBytes,
    this.downloadedBytes = 0,
  });

  String get sizeString {
    if (totalSizeBytes <= 0) return 'Unknown Size';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double doubleSize = totalSizeBytes.toDouble();
    while (doubleSize >= 1024 && i < suffixes.length - 1) {
      doubleSize /= 1024;
      i++;
    }
    return '${doubleSize.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'platform': platform,
      'thumbnailUrl': thumbnailUrl,
      'quality': quality,
      'formatExtension': formatExtension,
      'downloadUrl': downloadUrl,
      'savePath': savePath,
      'progress': progress,
      'status': status.index,
      'dateAdded': dateAdded.toIso8601String(),
      'totalSizeBytes': totalSizeBytes,
      'downloadedBytes': downloadedBytes,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      platform: json['platform'] ?? 'direct',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      quality: json['quality'] ?? 'Original',
      formatExtension: json['formatExtension'] ?? 'mp4',
      downloadUrl: json['downloadUrl'] ?? '',
      savePath: json['savePath'] ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: DownloadStatus.values[(json['status'] as int?) ?? 3], // defaults to completed if loaded from history
      dateAdded: json['dateAdded'] != null 
          ? DateTime.parse(json['dateAdded']) 
          : DateTime.now(),
      totalSizeBytes: json['totalSizeBytes'] ?? 0,
      downloadedBytes: json['downloadedBytes'] ?? 0,
    );
  }

  DownloadTask copyWith({
    double? progress,
    String? speed,
    String? eta,
    DownloadStatus? status,
    int? downloadedBytes,
    String? savePath,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      platform: platform,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
      formatExtension: formatExtension,
      downloadUrl: downloadUrl,
      savePath: savePath ?? this.savePath,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      status: status ?? this.status,
      dateAdded: dateAdded,
      totalSizeBytes: totalSizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    );
  }
}
