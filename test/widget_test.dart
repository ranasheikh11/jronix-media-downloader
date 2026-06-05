import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/controllers/url_analyzer.dart';

void main() {
  group('URLAnalyzerController Tests', () {
    late URLAnalyzerController analyzer;

    setUp(() {
      analyzer = URLAnalyzerController();
    });

    test('Detects YouTube links correctly', () {
      expect(analyzer.detectPlatform('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'youtube');
      expect(analyzer.detectPlatform('https://youtu.be/dQw4w9WgXcQ'), 'youtube');
    });

    test('Detects Facebook links correctly', () {
      expect(analyzer.detectPlatform('https://www.facebook.com/watch/?v=1234567890'), 'facebook');
      expect(analyzer.detectPlatform('https://fb.watch/abcd/'), 'facebook');
    });

    test('Detects Instagram links correctly', () {
      expect(analyzer.detectPlatform('https://www.instagram.com/reel/C8PsdwIu6_x/'), 'instagram');
      expect(analyzer.detectPlatform('https://instagram.com/p/C8PsdwIu/'), 'instagram');
    });

    test('Detects TikTok links correctly', () {
      expect(analyzer.detectPlatform('https://www.tiktok.com/@user/video/72134567890'), 'tiktok');
      expect(analyzer.detectPlatform('https://vm.tiktok.com/ZMYxABCD/'), 'tiktok');
    });

    test('Detects Direct media formats correctly', () {
      expect(analyzer.detectPlatform('https://example.com/video.mp4'), 'direct_video');
      expect(analyzer.detectPlatform('http://example.com/audio.mp3'), 'direct_audio');
      expect(analyzer.detectPlatform('https://example.com/image.jpg'), 'direct_image');
      expect(analyzer.detectPlatform('https://example.com/photo.png'), 'direct_image');
    });
  });
}
