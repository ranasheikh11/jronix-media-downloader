class MediaInfo {
  final String title;
  final String description;
  final String? duration;
  final String thumbnailUrl;
  final String platform;
  final String originalUrl;
  final List<DownloadFormat> formats;

  MediaInfo({
    required this.title,
    required this.description,
    this.duration,
    required this.thumbnailUrl,
    required this.platform,
    required this.originalUrl,
    required this.formats,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'duration': duration,
      'thumbnailUrl': thumbnailUrl,
      'platform': platform,
      'originalUrl': originalUrl,
      'formats': formats.map((f) => f.toJson()).toList(),
    };
  }

  factory MediaInfo.fromJson(Map<String, dynamic> json) {
    return MediaInfo(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      duration: json['duration'],
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      platform: json['platform'] ?? '',
      originalUrl: json['originalUrl'] ?? '',
      formats: (json['formats'] as List<dynamic>?)
              ?.map((f) => DownloadFormat.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DownloadFormat {
  final String quality;
  final String formatExtension; // e.g., 'mp4', 'mp3', 'jpg'
  final int sizeBytes;
  final String downloadUrl;

  DownloadFormat({
    required this.quality,
    required this.formatExtension,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  String get sizeString {
    if (sizeBytes <= 0) return 'Unknown Size';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double doubleSize = sizeBytes.toDouble();
    while (doubleSize >= 1024 && i < suffixes.length - 1) {
      doubleSize /= 1024;
      i++;
    }
    return '${doubleSize.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Map<String, dynamic> toJson() {
    return {
      'quality': quality,
      'formatExtension': formatExtension,
      'sizeBytes': sizeBytes,
      'downloadUrl': downloadUrl,
    };
  }

  factory DownloadFormat.fromJson(Map<String, dynamic> json) {
    return DownloadFormat(
      quality: json['quality'] ?? '',
      formatExtension: json['formatExtension'] ?? '',
      sizeBytes: json['sizeBytes'] ?? 0,
      downloadUrl: json['downloadUrl'] ?? '',
    );
  }
}
