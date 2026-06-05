import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_yt_dlp/flutter_yt_dlp.dart';
import '../models/media_info.dart';

class URLAnalyzerController extends GetxController {
  final Dio _dio = Dio();
  final FlutterYtDlpClient _ytDlp = FlutterYtDlpClient();
  final rxIsAnalyzing = false.obs;
  final rxError = ''.obs;

  // Platform Regexes
  final RegExp _youtubeRegex = RegExp(r'(youtube\.com|youtu\.be|youtube-nocookie\.com)');
  final RegExp _facebookRegex = RegExp(r'(facebook\.com|fb\.watch|fb\.com)');
  final RegExp _instagramRegex = RegExp(r'(instagram\.com)');
  final RegExp _tiktokRegex = RegExp(r'(tiktok\.com)');
  final RegExp _twitterRegex = RegExp(r'(twitter\.com|x\.com)');

  bool isValidUrl(String url) {
    if (url.isEmpty) {
      debugPrint('[Analyzer] ❌ Empty URL');
      return false;
    }
    final uri = Uri.tryParse(url);
    final valid = uri != null && uri.hasScheme && uri.hasAuthority;
    debugPrint('[Analyzer] URL="$url" → valid=$valid scheme=${uri?.scheme} host=${uri?.host}');
    return valid;
  }

  String detectPlatform(String url) {
    final cleanUrl = url.toLowerCase();
    String platform = 'unknown';
    if (_youtubeRegex.hasMatch(cleanUrl)) platform = 'youtube';
    else if (_facebookRegex.hasMatch(cleanUrl)) platform = 'facebook';
    else if (_instagramRegex.hasMatch(cleanUrl)) platform = 'instagram';
    else if (_tiktokRegex.hasMatch(cleanUrl)) platform = 'tiktok';
    else if (_twitterRegex.hasMatch(cleanUrl)) platform = 'twitter';
    else {
      final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
      if (path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.mov') || path.endsWith('.webm')) platform = 'direct_video';
      else if (path.endsWith('.mp3') || path.endsWith('.wav') || path.endsWith('.m4a') || path.endsWith('.aac')) platform = 'direct_audio';
      else if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png') || path.endsWith('.gif') || path.endsWith('.webp')) platform = 'direct_image';
    }
    debugPrint('[Analyzer] detectPlatform → "$platform" for "$url"');
    return platform;
  }

  Future<MediaInfo?> analyzeURL(String url) async {
    debugPrint('\n[Analyzer] ══════════════════════════════');
    debugPrint('[Analyzer] analyzeURL called: "$url"');

    if (!isValidUrl(url)) {
      rxError.value = 'invalid_url'.tr;
      debugPrint('[Analyzer] ❌ URL validation failed');
      return null;
    }

    rxIsAnalyzing.value = true;
    rxError.value = '';

    try {
      final platform = detectPlatform(url);
      debugPrint('[Analyzer] ▶ Starting extraction for platform="$platform"');

      if (platform == 'unknown') {
        debugPrint('[Analyzer] Unknown platform → trying HEAD request for MIME type');
        try {
          final response = await _dio.head(url);
          final contentType = response.headers.value('content-type') ?? '';
          debugPrint('[Analyzer] HEAD content-type="$contentType"');
          if (contentType.startsWith('video/')) {
            return _createDirectMedia(url, 'direct_video', 'Video File', response.headers.value('content-length'));
          } else if (contentType.startsWith('audio/')) {
            return _createDirectMedia(url, 'direct_audio', 'Audio File', response.headers.value('content-length'));
          } else if (contentType.startsWith('image/')) {
            return _createDirectMedia(url, 'direct_image', 'Image File', response.headers.value('content-length'));
          }
        } catch (e) {
          debugPrint('[Analyzer] HEAD request failed: $e');
        }
        rxError.value = 'unsupported_platform'.tr;
        debugPrint('[Analyzer] ❌ Unsupported platform, returning null');
        return null;
      }

      // Try using flutter_yt_dlp first (unless it's a direct file link)
      if (platform != 'direct_video' && platform != 'direct_audio' && platform != 'direct_image') {
        try {
          debugPrint('[Analyzer] Attempting extraction via flutter_yt_dlp...');
          final info = await _ytDlp.getVideoInfo(url);
          debugPrint('[Analyzer] flutter_yt_dlp returned metadata successfully!');
          final mediaInfo = _mediaInfoFromYtDlp(url, platform, info);
          if (mediaInfo.formats.isNotEmpty) {
            debugPrint('[Analyzer] ✅ Success using flutter_yt_dlp');
            return mediaInfo;
          } else {
            debugPrint('[Analyzer] flutter_yt_dlp did not return any formats, falling back to scrapers');
          }
        } catch (e) {
          debugPrint('[Analyzer] flutter_yt_dlp failed or not supported: $e. Falling back to native scrapers.');
        }
      }

      MediaInfo? result;
      switch (platform) {
        case 'youtube':
          debugPrint('[Analyzer] → calling _fetchYoutubeInfo');
          result = await _fetchYoutubeInfo(url);
        case 'facebook':
          debugPrint('[Analyzer] → calling _scrapeFacebook');
          result = await _scrapeFacebook(url);
        case 'instagram':
          debugPrint('[Analyzer] → calling _scrapeInstagram');
          result = await _scrapeInstagram(url);
        case 'tiktok':
          debugPrint('[Analyzer] → calling _scrapeTikTok');
          result = await _scrapeTikTok(url);
        case 'twitter':
          debugPrint('[Analyzer] → calling _scrapeTwitter');
          result = await _scrapeTwitter(url);
        case 'direct_video':
          debugPrint('[Analyzer] → calling _fetchDirectMediaHeaders (video)');
          result = await _fetchDirectMediaHeaders(url, 'direct_video', 'Direct Video');
        case 'direct_audio':
          debugPrint('[Analyzer] → calling _fetchDirectMediaHeaders (audio)');
          result = await _fetchDirectMediaHeaders(url, 'direct_audio', 'Direct Audio');
        case 'direct_image':
          debugPrint('[Analyzer] → calling _fetchDirectMediaHeaders (image)');
          result = await _fetchDirectMediaHeaders(url, 'direct_image', 'Direct Image');
        default:
          debugPrint('[Analyzer] ❌ Unhandled platform: $platform');
      }

      if (result != null) {
        debugPrint('[Analyzer] ✅ Success: title="${result.title}" formats=${result.formats.length}');
        for (final f in result.formats) {
          debugPrint('[Analyzer]   format: quality="${f.quality}" ext=${f.formatExtension} url=${f.downloadUrl.substring(0, f.downloadUrl.length.clamp(0, 80))}...');
        }
      } else {
        debugPrint('[Analyzer] ❌ Extractor returned null. Error="${rxError.value}"');
      }
      return result;
    } catch (e, stack) {
      rxError.value = 'Error analyzing URL: ${e.toString()}';
      debugPrint('[Analyzer] 💥 UNHANDLED EXCEPTION: $e');
      debugPrint('[Analyzer] Stack: $stack');
    } finally {
      rxIsAnalyzing.value = false;
      debugPrint('[Analyzer] ══════════════════════════════\n');
    }
    return null;
  }

  MediaInfo _mediaInfoFromYtDlp(String url, String platform, Map<String, dynamic> info) {
    final title = info['title'] as String? ?? 'Downloaded Video';
    final description = info['description'] as String? ?? '';
    final thumbnailUrl = info['thumbnail'] as String? ?? '';
    final duration = info['duration_string'] as String? ?? info['duration']?.toString();

    final List<DownloadFormat> formatsList = [];
    final rawFormats = info['formats'] as List<dynamic>? ?? [];

    for (final rawF in rawFormats) {
      if (rawF is! Map) continue;
      final f = Map<String, dynamic>.from(rawF);
      final streamUrl = f['url'] as String?;
      if (streamUrl == null || streamUrl.isEmpty) continue;

      final ext = f['ext'] as String? ?? 'mp4';
      final resolution = f['resolution'] as String? ?? f['format_note'] as String? ?? '';
      final size = f['filesize'] as int? ?? f['filesize_approx'] as int? ?? f['size'] as int? ?? 0;
      final vcodec = f['vcodec'] as String? ?? 'none';
      final acodec = f['acodec'] as String? ?? 'none';

      String quality;
      if (vcodec != 'none' && acodec != 'none') {
        quality = '${resolution.isNotEmpty ? resolution : "Combined"} ($ext)';
      } else if (vcodec != 'none') {
        quality = 'Video Only - ${resolution.isNotEmpty ? resolution : "Video"} ($ext)';
      } else if (acodec != 'none') {
        final abr = f['abr'] as double? ?? f['bitrate'] as double? ?? 0.0;
        quality = 'Audio Only - ${abr > 0 ? "${abr.toInt()}kbps" : "Audio"} ($ext)';
      } else {
        quality = 'Format - ${f['format_id'] ?? "unknown"} ($ext)';
      }

      formatsList.add(DownloadFormat(
        quality: quality,
        formatExtension: ext,
        sizeBytes: size,
        downloadUrl: streamUrl,
      ));
    }

    if (formatsList.isEmpty) {
      final combined = info['rawVideoWithSoundFormats'] as List<dynamic>? ?? [];
      for (final rawF in combined) {
        if (rawF is! Map) continue;
        final f = Map<String, dynamic>.from(rawF);
        final streamUrl = f['url'] as String?;
        if (streamUrl == null || streamUrl.isEmpty) continue;
        formatsList.add(DownloadFormat(
          quality: '${f['resolution'] ?? "Combined"} (${f['ext'] ?? "mp4"})',
          formatExtension: f['ext'] as String? ?? 'mp4',
          sizeBytes: f['size'] as int? ?? f['filesize'] as int? ?? 0,
          downloadUrl: streamUrl,
        ));
      }
      final merge = info['mergeFormats'] as List<dynamic>? ?? [];
      for (final rawF in merge) {
        if (rawF is! Map) continue;
        final f = Map<String, dynamic>.from(rawF);
        final streamUrl = f['url'] as String?;
        if (streamUrl == null || streamUrl.isEmpty) continue;
        formatsList.add(DownloadFormat(
          quality: 'Merge Video - ${f['resolution'] ?? "Video"} (${f['ext'] ?? "mp4"})',
          formatExtension: f['ext'] as String? ?? 'mp4',
          sizeBytes: f['size'] as int? ?? f['filesize'] as int? ?? 0,
          downloadUrl: streamUrl,
        ));
      }
      final audios = info['rawAudioOnlyFormats'] as List<dynamic>? ?? [];
      for (final rawF in audios) {
        if (rawF is! Map) continue;
        final f = Map<String, dynamic>.from(rawF);
        final streamUrl = f['url'] as String?;
        if (streamUrl == null || streamUrl.isEmpty) continue;
        formatsList.add(DownloadFormat(
          quality: 'Audio Only - ${f['bitrate'] ?? "Audio"} (${f['ext'] ?? "mp3"})',
          formatExtension: f['ext'] as String? ?? 'mp3',
          sizeBytes: f['size'] as int? ?? f['filesize'] as int? ?? 0,
          downloadUrl: streamUrl,
        ));
      }
    }

    return MediaInfo(
      title: title,
      description: description,
      duration: duration,
      thumbnailUrl: thumbnailUrl,
      platform: platform,
      originalUrl: url,
      formats: formatsList,
    );
  }


  // Generate Direct Media Info
  Future<MediaInfo> _fetchDirectMediaHeaders(String url, String platform, String title) async {
    int length = 0;
    try {
      final response = await _dio.head(url);
      length = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
    } catch (_) {}
    return _createDirectMedia(url, platform, title, length.toString());
  }

  MediaInfo _createDirectMedia(String url, String platform, String title, String? contentLength) {
    final size = int.tryParse(contentLength ?? '0') ?? 15728640; // Default 15MB if headers failed
    final ext = platform == 'direct_audio' ? 'mp3' : (platform == 'direct_image' ? 'jpg' : 'mp4');
    final quality = platform == 'direct_audio' ? '320kbps' : (platform == 'direct_image' ? 'Original' : '1080p');

    return MediaInfo(
      title: title,
      description: 'Direct downloaded media source',
      thumbnailUrl: platform == 'direct_audio' 
          ? 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500' // General music image
          : (platform == 'direct_image' ? url : 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=500'), // Video player placeholder
      platform: platform,
      originalUrl: url,
      duration: platform == 'direct_audio' ? '04:12' : (platform == 'direct_image' ? null : '02:30'),
      formats: [
        DownloadFormat(
          quality: quality,
          formatExtension: ext,
          sizeBytes: size,
          downloadUrl: url,
        )
      ],
    );
  }

  // --- Platform Mock Data Generators ---

  // ─────────────────────────────────────────────────────────────
  // NATIVE SCRAPERS — no third-party services, pure HTTP + regex
  // ─────────────────────────────────────────────────────────────

  static const _browserHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
  };

  // ───────────────── TikTok ─────────────────
  // Parses SIGI_STATE / __NEXT_DATA__ embedded JSON in the page HTML
  Future<MediaInfo?> _scrapeTikTok(String url) async {
    try {
      // Resolve short URLs (vm.tiktok.com, vt.tiktok.com)
      String resolved = url;
      if (url.contains('vm.tiktok.com') || url.contains('vt.tiktok.com')) {
        final r = await _dio.get(url,
            options: Options(followRedirects: false, validateStatus: (_) => true,
                headers: _browserHeaders));
        resolved = r.headers['location']?.first ?? url;
      }

      final resp = await _dio.get(resolved,
          options: Options(headers: _browserHeaders, responseType: ResponseType.plain));
      final html = resp.data as String;

      // Try SIGI_STATE (TikTok's Next.js SSR data)
      final sigiMatch = RegExp(
              r'<script\s+id="SIGI_STATE"\s+type="application/json">(.*?)</script>',
              dotAll: true)
          .firstMatch(html);
      if (sigiMatch != null) {
        final data = jsonDecode(sigiMatch.group(1)!) as Map<String, dynamic>;
        final itemModule = data['ItemModule'] as Map<String, dynamic>?;
        if (itemModule != null && itemModule.isNotEmpty) {
          final item = itemModule.values.first as Map<String, dynamic>;
          final video = item['video'] as Map<String, dynamic>?;
          if (video != null) {
            final formats = <DownloadFormat>[];
            // bitrateInfo contains multiple quality streams
            final bitrateInfo = video['bitrateInfo'] as List?;
            if (bitrateInfo != null) {
              for (final b in bitrateInfo) {
                final bm = b as Map<String, dynamic>;
                final urlList = (bm['PlayAddr'] as Map)['UrlList'] as List?;
                if (urlList != null && urlList.isNotEmpty) {
                  final qualityType = bm['QualityType']?.toString() ?? '0';
                  formats.add(DownloadFormat(
                    quality: qualityType == '0' ? 'HD (No Watermark)' : 'SD',
                    formatExtension: 'mp4',
                    sizeBytes: int.tryParse(bm['DataSize']?.toString() ?? '0') ?? 0,
                    downloadUrl: urlList.first as String,
                  ));
                }
              }
            }
            // fallback to playAddr
            if (formats.isEmpty) {
              final pa = video['playAddr'] as String? ?? '';
              if (pa.isNotEmpty) {
                formats.add(DownloadFormat(quality: 'HD', formatExtension: 'mp4', sizeBytes: 0, downloadUrl: pa));
              }
            }
            if (formats.isNotEmpty) {
              final desc = item['desc'] as String? ?? 'TikTok Video';
              final author = (item['author'] as Map?)?['nickname'] as String? ?? '';
              return MediaInfo(
                title: desc.isEmpty ? 'TikTok Video' : desc,
                description: '@$author',
                thumbnailUrl: (video['cover'] as String?) ?? 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800',
                platform: 'tiktok', originalUrl: url, formats: formats,
              );
            }
          }
        }
      }

      // Fallback: __NEXT_DATA__
      final nextMatch = RegExp(
              r'<script\s+id="__NEXT_DATA__"\s+type="application/json">(.*?)</script>',
              dotAll: true)
          .firstMatch(html);
      if (nextMatch != null) {
        final data = jsonDecode(nextMatch.group(1)!) as Map<String, dynamic>;
        final struct = data['props']?['pageProps']?['itemInfo']?['itemStruct'] as Map<String, dynamic>?;
        final pa = (struct?['video'] as Map?)?['playAddr'] as String? ?? '';
        if (pa.isNotEmpty) {
          return MediaInfo(
            title: struct?['desc'] as String? ?? 'TikTok Video',
            description: 'TikTok', thumbnailUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800',
            platform: 'tiktok', originalUrl: url,
            formats: [DownloadFormat(quality: 'HD', formatExtension: 'mp4', sizeBytes: 0, downloadUrl: pa)],
          );
        }
      }

      rxError.value = 'TikTok: could not extract video. It may be private or require login.';
      return null;
    } catch (e) {
      debugPrint('TikTok scrape: $e');
      rxError.value = 'TikTok error: ${e.toString().split('\n').first}';
      return null;
    }
  }

  // ───────────────── Instagram ─────────────────
  // Tries: embed page JSON  →  unofficial /?__a=1 API  →  og:video meta
  Future<MediaInfo?> _scrapeInstagram(String url) async {
    final codeMatch = RegExp(r'/(?:p|reel|tv)/([A-Za-z0-9_-]+)').firstMatch(url);
    final code = codeMatch?.group(1);
    if (code == null) { rxError.value = 'Invalid Instagram URL'; return null; }

    // Attempt 1: embed page contains video_url JSON
    try {
      final embedResp = await _dio.get(
        'https://www.instagram.com/p/$code/embed/captioned/',
        options: Options(headers: {
          ..._browserHeaders,
          'Referer': 'https://www.instagram.com/',
        }, responseType: ResponseType.plain),
      );
      final html = embedResp.data as String;
      final vm = RegExp(r'"video_url":"(https[^"]+)"').firstMatch(html);
      if (vm != null) {
        final videoUrl = vm.group(1)!.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
        final tm = RegExp(r'"thumbnail_src":"([^"]+)"').firstMatch(html);
        final thumb = tm?.group(1)?.replaceAll(r'\/', '/') ?? 'https://images.unsplash.com/photo-1541462608141-2ffb6cc0e9e0?w=800';
        final cm = RegExp(r'"text":"([^"]{0,200})"').firstMatch(html);
        return MediaInfo(
          title: cm?.group(1) ?? 'Instagram Video',
          description: 'instagram.com/p/$code/',
          thumbnailUrl: thumb, platform: 'instagram', originalUrl: url,
          formats: [DownloadFormat(quality: 'Original', formatExtension: 'mp4', sizeBytes: 0, downloadUrl: videoUrl)],
        );
      }
    } catch (e) { debugPrint('Instagram embed: $e'); }

    // Attempt 2: unofficial JSON API
    try {
      final apiResp = await _dio.get(
        'https://www.instagram.com/p/$code/?__a=1&__d=dis',
        options: Options(headers: {
          'User-Agent': 'Instagram 219.0.0.12.117 Android',
          'Accept': 'application/json',
          'X-IG-App-ID': '936619743392459',
          'Referer': 'https://www.instagram.com/',
        }),
      );
      final data = apiResp.data as Map<String, dynamic>?;
      final item = (data?['items'] as List?)?.first as Map<String, dynamic>?;
      if (item != null) {
        final versions = item['video_versions'] as List?;
        if (versions != null && versions.isNotEmpty) {
          final thumb = ((item['image_versions2']?['candidates'] as List?)?.first as Map?)?['url'] as String?;
          final formats = versions.map((v) {
            final vm = v as Map<String, dynamic>;
            return DownloadFormat(
              quality: '${vm['width']}x${vm['height']}',
              formatExtension: 'mp4', sizeBytes: 0,
              downloadUrl: vm['url'] as String,
            );
          }).toList();
          return MediaInfo(
            title: (item['caption'] as Map?)?['text'] as String? ?? 'Instagram Video',
            description: 'instagram.com/p/$code/', thumbnailUrl: thumb ?? 'https://images.unsplash.com/photo-1541462608141-2ffb6cc0e9e0?w=800',
            platform: 'instagram', originalUrl: url, formats: formats,
          );
        }
      }
    } catch (e) { debugPrint('Instagram API: $e'); }

    rxError.value = 'Instagram: video not found. It may be private or require login.';
    return null;
  }

  // ───────────────── Facebook ─────────────────
  // Parses hd_src / sd_src JSON values and og:video meta tag from page HTML
  Future<MediaInfo?> _scrapeFacebook(String url) async {
    try {
      final resp = await _dio.get(url,
          options: Options(headers: {
            ..._browserHeaders,
            'Accept-Language': 'en-US,en;q=0.9',
          }, responseType: ResponseType.plain));
      final html = resp.data as String;
      final formats = <DownloadFormat>[];

      // hd_src / sd_src embedded in JSON
      final hdm = RegExp(r'"hd_src":"([^"]+)"').firstMatch(html);
      final sdm = RegExp(r'"sd_src":"([^"]+)"').firstMatch(html);
      if (hdm != null) formats.add(DownloadFormat(quality: 'HD Quality', formatExtension: 'mp4', sizeBytes: 0, downloadUrl: hdm.group(1)!.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&')));
      if (sdm != null) formats.add(DownloadFormat(quality: 'SD Quality', formatExtension: 'mp4', sizeBytes: 0, downloadUrl: sdm.group(1)!.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&')));

      // og:video fallback
      if (formats.isEmpty) {
        final ogm = RegExp(r'<meta\s+property="og:video(?::[^"]+)?"\s+content="([^"]+)"').firstMatch(html);
        if (ogm != null) formats.add(DownloadFormat(quality: 'Original', formatExtension: 'mp4', sizeBytes: 0, downloadUrl: ogm.group(1)!));
      }

      if (formats.isEmpty) {
        rxError.value = 'Facebook: no video found. Public videos only — login required for private.';
        return null;
      }

      final title = RegExp(r'<title>([^<]*)</title>').firstMatch(html)?.group(1) ?? 'Facebook Video';
      final thumb = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"').firstMatch(html)?.group(1);
      return MediaInfo(
        title: title, description: 'Facebook Video',
        thumbnailUrl: thumb ?? 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=800',
        platform: 'facebook', originalUrl: url, formats: formats,
      );
    } catch (e) {
      debugPrint('Facebook scrape: $e');
      rxError.value = 'Facebook error: ${e.toString().split('\n').first}';
      return null;
    }
  }

  // ───────────────── Twitter / X ─────────────────
  // Uses Twitter syndication API — public, no auth token needed
  Future<MediaInfo?> _scrapeTwitter(String url) async {
    final idMatch = RegExp(r'/status/?(\d+)').firstMatch(url);
    final tweetId = idMatch?.group(1);
    if (tweetId == null) { rxError.value = 'Invalid Twitter URL'; return null; }

    try {
      final resp = await _dio.get(
        'https://cdn.syndication.twimg.com/tweet-result?id=$tweetId&lang=en&token=0',
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://platform.twitter.com/',
          'Origin': 'https://platform.twitter.com',
        }),
      );
      final data = resp.data as Map<String, dynamic>;
      final mediaDetails = data['mediaDetails'] as List?;

      if (mediaDetails != null) {
        final formats = <DownloadFormat>[];
        String? thumb;
        for (final m in mediaDetails) {
          final media = m as Map<String, dynamic>;
          if (media['type'] == 'video') {
            thumb = media['media_url_https'] as String?;
            final variants = (media['video_info'] as Map?)?['variants'] as List? ?? [];
            for (final v in variants) {
              final vm = v as Map<String, dynamic>;
              if (vm['content_type'] == 'video/mp4') {
                final bitrate = vm['bitrate'] as int? ?? 0;
                formats.add(DownloadFormat(
                  quality: bitrate > 1500000 ? 'HD (720p)' : bitrate > 700000 ? 'SD (480p)' : 'Low (360p)',
                  formatExtension: 'mp4', sizeBytes: 0,
                  downloadUrl: vm['url'] as String,
                ));
              }
            }
            formats.sort((a, b) => b.quality.compareTo(a.quality));
          }
        }
        if (formats.isNotEmpty) {
          final user = data['user'] as Map<String, dynamic>?;
          final text = data['text'] as String? ?? 'Twitter Video';
          return MediaInfo(
            title: user != null ? 'Tweet by ${user['name']}' : text,
            description: text,
            thumbnailUrl: thumb ?? 'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?w=800',
            platform: 'twitter', originalUrl: url, formats: formats,
          );
        }
      }
      rxError.value = 'Twitter: no video found in this tweet.';
      return null;
    } catch (e) {
      debugPrint('Twitter scrape: $e');
      rxError.value = 'Twitter error: ${e.toString().split('\n').first}';
      return null;
    }
  }

  // --- Real YouTube Stream Extraction (no API key required) ---

  /// Normalises any YouTube URL variant into a clean watch?v= URL.
  /// Handles: Shorts (?si= tracking param), youtu.be, mobile share links.
  String _normalizeYoutubeUrl(String url) {
    // YouTube Shorts: youtube.com/shorts/VIDEO_ID  (with or without ?si= etc.)
    final shortsMatch =
        RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (shortsMatch != null) {
      return 'https://www.youtube.com/watch?v=${shortsMatch.group(1)}';
    }

    // Short link: youtu.be/VIDEO_ID
    final shortMatch =
        RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (shortMatch != null) {
      return 'https://www.youtube.com/watch?v=${shortMatch.group(1)}';
    }

    // Standard watch URL — strip all query params except v=
    final watchMatch =
        RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (watchMatch != null) {
      return 'https://www.youtube.com/watch?v=${watchMatch.group(1)}';
    }

    // Last resort: return as-is and let the library try
    return url;
  }

  Future<MediaInfo?> _fetchYoutubeInfo(String url) async {
    final yt = YoutubeExplode();
    try {
      final cleanUrl = _normalizeYoutubeUrl(url);
      debugPrint('YouTube: extracting → $cleanUrl');

      final video = await yt.videos.get(cleanUrl);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      final formats = <DownloadFormat>[];

      // Muxed streams = video + audio in one file — best for preview & simple download
      final muxed = manifest.muxed.sortByVideoQuality();
      for (final stream in muxed) {
        formats.add(DownloadFormat(
          quality: '${stream.videoQuality.name} (${stream.container.name.toUpperCase()})',
          formatExtension: stream.container.name,
          sizeBytes: stream.size.totalBytes,
          downloadUrl: stream.url.toString(),
        ));
      }

      // Best AAC audio-only stream
      if (manifest.audioOnly.isNotEmpty) {
        final bestAudio = manifest.audioOnly
            .where((s) => s.audioCodec.contains('mp4a') || s.audioCodec.contains('aac'))
            .toList()
          ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        final audio = bestAudio.isNotEmpty
            ? bestAudio.first
            : manifest.audioOnly.withHighestBitrate();
        formats.add(DownloadFormat(
          quality: 'Audio Only (${audio.bitrate.kiloBitsPerSecond.round()} kbps)',
          formatExtension: 'm4a',
          sizeBytes: audio.size.totalBytes,
          downloadUrl: audio.url.toString(),
        ));
      }

      // Duration formatting
      final dur = video.duration;
      final durationStr = dur == null
          ? null
          : '${dur.inMinutes.toString().padLeft(2, '0')}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';

      return MediaInfo(
        title: video.title,
        description: video.description.isNotEmpty
            ? video.description
            : 'YouTube video by ${video.author}',
        thumbnailUrl: video.thumbnails.highResUrl,
        platform: 'youtube',
        originalUrl: url,
        duration: durationStr,
        formats: formats,
      );
    } catch (e) {
      debugPrint('YouTube extraction error: $e');
      rxError.value = 'Could not extract YouTube stream: ${e.toString().split('\n').first}';
      return null;
    } finally {
      yt.close();
    }
  }

}
