import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Domains/patterns that are known video stream CDNs for each platform.
const _videoPatterns = [
  // TikTok CDNs
  'v19-webapp.tiktok.com',
  'v26-webapp.tiktok.com',
  'v19.tiktokcdn.com',
  'v26.tiktokcdn.com',
  'api19-normal-c-useast1a.tiktokv.com',
  // Instagram / Facebook CDNs
  'cdninstagram.com',
  'fbcdn.net',
  'facebook.com/video',
  // Twitter
  'video.twimg.com',
  // Generic
  '.mp4',
  '.m4v',
  '.m3u8',
  '.webm',
];

/// Mime types that signal a video stream.
const _videoMimes = ['video/mp4', 'video/webm', 'video/ogg', 'application/x-mpegURL', 'video/MP2T'];

bool _isVideoUrl(String url, {String? mimeType}) {
  if (mimeType != null && _videoMimes.any((m) => mimeType.contains(m))) return true;
  final lower = url.toLowerCase();
  return _videoPatterns.any((p) => lower.contains(p));
}

class ExtractedStream {
  final String url;
  final Map<String, String> headers;
  ExtractedStream({required this.url, required this.headers});
}

/// Opens a full-screen browser-like WebView on [pageUrl].
/// Intercepts every network request; the first matching video stream URL
/// is returned to the caller.
Future<ExtractedStream?> extractStreamViaWebView(
    BuildContext context, String pageUrl) {
  return showModalBottomSheet<ExtractedStream?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WebViewExtractorSheet(pageUrl: pageUrl),
  );
}

class _WebViewExtractorSheet extends StatefulWidget {
  final String pageUrl;
  const _WebViewExtractorSheet({required this.pageUrl});

  @override
  State<_WebViewExtractorSheet> createState() => _WebViewExtractorSheetState();
}

class _WebViewExtractorSheetState extends State<_WebViewExtractorSheet> {
  String _status = 'Loading page…';
  double _loadProgress = 0;
  bool _found = false;

  // Common mobile browser headers passed to every request
  static const _defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.119 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white38, borderRadius: BorderRadius.circular(2)),
          ),
          // Status bar
          Container(
            color: const Color(0xFF1A1D2E),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Expanded(
                child: Text(_status,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_loadProgress > 0 && _loadProgress < 1)
                SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(
                      value: _loadProgress,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF6C63FF)),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
              ),
            ]),
          ),
          // WebView — runs full JavaScript like a real browser
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.pageUrl),
                headers: _defaultHeaders,
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useOnLoadResource: true,
                useShouldInterceptRequest: true,
                userAgent:
                    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.119 Mobile Safari/537.36',
              ),
              onWebViewCreated: (ctrl) {},
              onProgressChanged: (_, progress) {
                if (mounted) setState(() => _loadProgress = progress / 100.0);
              },
              onLoadStart: (_, url) {
                if (mounted) setState(() => _status = 'Loading: ${url?.host ?? ''}');
              },
              onLoadStop: (_, __) {
                if (mounted) setState(() => _status = 'Tap ▶ to play — intercepting stream…');
              },
              onLoadResource: (ctrl, resource) async {
                if (_found) return;
                final resUrl = resource.url?.toString() ?? '';
                if (_isVideoUrl(resUrl)) {
                  _captureStream(resUrl, {});
                }
              },
              // shouldInterceptRequest fires for EVERY request the WebView makes
              shouldInterceptRequest: (ctrl, request) async {
                if (_found) return null;
                final reqUrl = request.url.toString();
                if (_isVideoUrl(reqUrl)) {
                  final hdrs = Map<String, String>.from(
                      request.headers?.cast<String, String>() ?? {});
                  _captureStream(reqUrl, hdrs);
                }
                return null; // let it proceed normally
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _captureStream(String videoUrl, Map<String, String> headers) {
    if (_found || !mounted) return;
    _found = true;
    debugPrint('WebView captured stream: $videoUrl');
    if (mounted) setState(() => _status = '✅ Stream found!');
    // Brief delay so user sees the success message
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.of(context).pop(ExtractedStream(url: videoUrl, headers: headers));
      }
    });
  }
}
