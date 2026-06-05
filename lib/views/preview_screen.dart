import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../controllers/download_controller.dart';
import '../models/media_info.dart';
import '../services/webview_extractor.dart';

class PreviewScreen extends StatefulWidget {
  final MediaInfo mediaInfo;
  final String? localFilePath;

  const PreviewScreen({
    super.key,
    required this.mediaInfo,
    this.localFilePath,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final DownloadController downloadController = Get.find<DownloadController>();

  // media_kit player
  Player? _player;
  VideoController? _videoController;

  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  bool _hasPlaybackError = false;
  Duration _videoDuration = Duration.zero;
  Duration _videoPosition = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _showControls = true;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': 'https://www.google.com/',
  };

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final mediaType = widget.mediaInfo.platform;
    if (mediaType == 'direct_image') return;

    // Pick preview URL
    String previewUrl = '';
    if (widget.mediaInfo.formats.isNotEmpty) {
      final videoFormat = widget.mediaInfo.formats.firstWhere(
        (f) => f.formatExtension == 'mp4',
        orElse: () => widget.mediaInfo.formats.first,
      );
      previewUrl = videoFormat.downloadUrl;
    }

    if (widget.localFilePath == null && previewUrl.isEmpty) return;

    try {
      _player = Player();

      // libmpv on Android bundles its own OpenSSL which doesn't trust the system
      // CA store. Disabling TLS verification lets it open any HTTPS stream.
      final platform = _player!.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('tls-verify', 'no');
        await platform.setProperty('user-agent',
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/122.0.0.0 Mobile Safari/537.36');
      }

      _videoController = VideoController(_player!);

      // Listen to stream updates
      _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
      _player!.stream.duration.listen((dur) {
        if (mounted) setState(() => _videoDuration = dur);
      });
      _player!.stream.position.listen((pos) {
        if (mounted) setState(() => _videoPosition = pos);
      });
      _player!.stream.error.listen((err) {
        if (err.isNotEmpty && mounted) {
          debugPrint('media_kit error: $err');
          setState(() => _hasPlaybackError = true);
        }
      });

      Media media;
      if (widget.localFilePath != null) {
        media = Media('file://${widget.localFilePath}');
      } else {
        media = Media(previewUrl, httpHeaders: _headers);
      }

      await _player!.open(media, play: false);

      if (mounted) {
        setState(() => _isPlayerInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) setState(() => _hasPlaybackError = true);
    }
  }

  /// Opens a real WebView that executes JavaScript like Chrome.
  /// Intercepts the video stream URL and replays it in media_kit.
  Future<void> _extractViaWebView() async {
    final pageUrl = widget.mediaInfo.originalUrl;
    final result = await extractStreamViaWebView(context, pageUrl);
    if (result == null || !mounted) return;

    // Reset player with the intercepted URL + captured headers
    setState(() {
      _hasPlaybackError = false;
      _isPlayerInitialized = false;
    });

    await _player?.dispose();
    _player = Player();

    final platform = _player!.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('tls-verify', 'no');
      await platform.setProperty('user-agent',
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/122 Mobile Safari/537.36');
    }
    _videoController = VideoController(_player!);

    _player!.stream.playing.listen((p) { if (mounted) setState(() => _isPlaying = p); });
    _player!.stream.duration.listen((d) { if (mounted) setState(() => _videoDuration = d); });
    _player!.stream.position.listen((p) { if (mounted) setState(() => _videoPosition = p); });
    _player!.stream.error.listen((err) {
      if (err.isNotEmpty && mounted) {
        debugPrint('WebView stream error: $err');
        setState(() => _hasPlaybackError = true);
      }
    });

    final mergedHeaders = {
      ..._headers,
      ...result.headers,
      'Referer': pageUrl,
    };

    await _player!.open(
      Media(result.url, httpHeaders: mergedHeaders),
      play: true,
    );

    if (mounted) setState(() => _isPlayerInitialized = true);
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _player?.playOrPause();
  }

  void _seekTo(double value) {
    _player?.seek(Duration(milliseconds: value.toInt()));
  }

  void _changeSpeed() {
    double nextSpeed = 1.0;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else if (_playbackSpeed == 2.0) {
      nextSpeed = 0.5;
    } else {
      nextSpeed = 1.0;
    }
    _player?.setRate(nextSpeed);
    setState(() => _playbackSpeed = nextSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final platform = widget.mediaInfo.platform;
    final isLocal = widget.localFilePath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLocal ? 'Media Player' : 'preview'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewViewport(platform, isDark),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildPlatformBadge(platform),
                      const SizedBox(width: 8),
                      if (widget.mediaInfo.duration != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.mediaInfo.duration!,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.mediaInfo.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.mediaInfo.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isLocal) ...[
                    Text(
                      'select_quality'.tr,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.mediaInfo.formats.length,
                      itemBuilder: (context, index) {
                        final format = widget.mediaInfo.formats[index];
                        return _buildFormatRow(format, isDark);
                      },
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkSurface.withValues(alpha: 0.5)
                              : AppTheme.lightSurface,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Local Path:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Expanded(
                                child: Text(
                                  widget.localFilePath!,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.primary),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            icon: const Icon(Icons.share_rounded),
                            label: Text('share'.tr),
                            onPressed: () {
                              Share.shareXFiles(
                                  [XFile(widget.localFilePath!)],
                                  text: widget.mediaInfo.title);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewViewport(String platform, bool isDark) {
    if (platform == 'direct_image') {
      return Container(
        height: 250,
        width: double.infinity,
        color: Colors.black,
        child: InteractiveViewer(
          maxScale: 5.0,
          child: Image.network(
            widget.mediaInfo.originalUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_rounded,
                  size: 64, color: Colors.grey),
            ),
          ),
        ),
      );
    } else if (platform == 'direct_audio' || platform.contains('audio')) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                12,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: _isPlaying
                      ? (20.0 + (index % 3) * 15 + (index % 4) * 8)
                      : 8.0,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildPlayerControlsBar(isDark),
          ],
        ),
      );
    } else {
      // --- Video player ---
      if (_hasPlaybackError) {
        return Container(
          height: 220,
          width: double.infinity,
          decoration: const BoxDecoration(color: Colors.black),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orangeAccent, size: 40),
              const SizedBox(height: 10),
              const Text(
                'Direct stream failed',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'The platform blocked direct stream extraction.\nUse the browser below — it works exactly like Chrome.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Open & Extract via Browser'),
                onPressed: _extractViaWebView,
              ),
            ],
          ),
        );
      }

      if (!_isPlayerInitialized || _videoController == null) {
        return Container(
          height: 220,
          width: double.infinity,
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );
      }

      return GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // media_kit native video surface
              Video(
                controller: _videoController!,
                controls: NoVideoControls,
              ),
              if (_showControls)
                Container(
                  color: Colors.black45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox.shrink(),
                      IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                        onPressed: _togglePlay,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildVideoProgressSlider(),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_videoPosition),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                TextButton(
                                  onPressed: _changeSpeed,
                                  child: Text(
                                    '${_playbackSpeed}x',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_videoDuration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildPlayerControlsBar(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppTheme.primary,
              thumbColor: AppTheme.primary,
            ),
            child: Slider(
              min: 0.0,
              max: _videoDuration.inMilliseconds.toDouble(),
              value: _videoPosition.inMilliseconds
                  .toDouble()
                  .clamp(0.0, _videoDuration.inMilliseconds.toDouble()),
              onChanged: _seekTo,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_videoPosition),
                  style: const TextStyle(fontSize: 11)),
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
                onPressed: _togglePlay,
              ),
              Text(_formatDuration(_videoDuration),
                  style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoProgressSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        activeTrackColor: AppTheme.primary,
        thumbColor: AppTheme.primary,
        inactiveTrackColor: Colors.white24,
      ),
      child: Slider(
        min: 0.0,
        max: _videoDuration.inMilliseconds.toDouble(),
        value: _videoPosition.inMilliseconds
            .toDouble()
            .clamp(0.0, _videoDuration.inMilliseconds.toDouble()),
        onChanged: _seekTo,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildFormatRow(DownloadFormat format, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.darkSurface.withValues(alpha: 0.5)
              : AppTheme.lightSurface,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    format.formatExtension.toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        format.quality,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        format.sizeString,
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              downloadController.startDownload(widget.mediaInfo, format);
              Get.back();
            },
            child: const Icon(Icons.download_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(String platform) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
