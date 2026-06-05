# 🚀 Jronix Media Downloader

A premium, state-of-the-art media downloader application built with **Flutter**, featuring a high-fidelity glassmorphic dark-themed UI, multi-threaded downloading, a built-in playback engine, and a resilient hybrid extraction pipeline.

---

## 🌟 Key Features

1. **Smart URL Auto-Detection**
   * Auto-recognizes links from **YouTube, TikTok, Facebook, Instagram, Twitter (X)**, and direct media files (MP4, MP3, JPEG, PNG, etc.).
   * One-click clipboard detection prompts you to analyze copied links instantly.

2. **Resilient Hybrid Extraction Pipeline**
   * **Stage 1 (Native Python Wrapper):** Uses `flutter_yt_dlp` via Chaquopy to run standard Python `yt-dlp` scripts locally.
   * **Stage 2 (Pure Dart Scrapers):** Fallback pure HTTP/Regex parsers that extract video and audio streams from SSR pages.
   * **Stage 3 (In-App WebView Interception):** Standard Chromium browser interceptor that listens to network traffic and captures secure CDN urls directly as soon as the media begins playing.

3. **Advanced Download Queue Manager**
   * Custom download manager built using **Dio** and `CancelToken`.
   * Displays real-time download speeds (MB/s), progress bars, and accurate Estimated Time of Arrival (ETA).
   * Supports **Pause**, **Resume**, and **Cancel** operations.

4. **Premium Playback & Preview Engine**
   * Uses **media_kit** for native player rendering on Android and iOS (bypassing Android SSL/TLS trust issues).
   * Audio players feature dynamic mock waves/visualizers.
   * Images include pinch-to-zoom interactive controls.

5. **Theme & Localization**
   * Curated glassmorphic dark/light designs with premium neon accents.
   * Fully bilingual supporting dynamic **English (en)** and **Bangla (bn)** translation keys.

---

## 🛠️ Architecture & Folder Structure

```
lib/
├── core/
│   ├── theme.dart          # Glassmorphic themes & neon gradients
│   └── translations.dart   # English & Bangla localization dictionaries
├── models/
│   ├── media_info.dart     # Parsed stream format representations
│   └── download_task.dart  # Download task queue states
├── controllers/
│   ├── settings_controller.dart  # App configurations & locale settings
│   ├── url_analyzer.dart         # Smart URL scraper regex & extraction router
│   └── download_controller.dart  # Multi-threaded download queue manager
├── services/
│   └── webview_extractor.dart    # In-App Browser stream interceptor
└── views/
    ├── splash_screen.dart   # Glowing animated logo entry
    ├── home_screen.dart     # Navigation dashboard shell
    └── tabs/
        ├── home_tab.dart     # Link analyzer and quick-actions grid
        ├── history_tab.dart  # Active queue & historical search logs
        ├── settings_tab.dart # Theme, language, and cache controls
        └── premium_tab.dart  # Glassmorphic pricing cards
```

---

## ⚙️ Android & iOS Native Build Infrastructure

To support local Python compilation (Chaquopy) and native FFmpeg processing, the project is configured with the following parameters:

* **Android Gradle Plugin (AGP):** Downgraded to `8.8.2` in `android/settings.gradle.kts` to resolve task naming conventions with older Chaquopy scripts.
* **Gradle Wrapper:** Configured to `8.14` for broad compatibility.
* **FFmpeg Dependency:** Employs `com.antonkarpenko:ffmpeg-kit-full:2.1.0` as a drop-in replacement for the archived/retired `com.arthenica` artifacts.
* **Permissions Required:** 
  * `INTERNET` and `ACCESS_NETWORK_STATE` for network sockets.
  * Granular media access permissions (`READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_MEDIA_IMAGES`) and `MANAGE_EXTERNAL_STORAGE`.

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (`>=3.19.0`)
* Android Studio / Xcode

### Setup and Build
1. Clone the repository and navigate to the project directory:
   ```bash
   flutter pub get
   ```

2. Generate the debug APK:
   ```bash
   flutter build apk --debug
   ```

---

## 🛡️ Troubleshooting FAQ

* **Issue:** `UnknownTaskException: Task with name 'packageDebugAssets' not found`
  * **Solution:** Keep the Android Gradle Plugin (AGP) version pinned to `8.8.2` or lower inside `android/settings.gradle.kts`. Newer AGP versions (8.9+) change asset packaging structures that clash with Python/Chaquopy pipelines.

* **Issue:** `Could not find com.arthenica:ffmpeg-kit-full:6.0`
  * **Solution:** The official `com.arthenica` packages were removed from Maven Central in 2025. The plugin is configured to use the community-maintained drop-in replacement fork `com.antonkarpenko:ffmpeg-kit-full:2.1.0`.

* **Issue:** `No space left on device` during Android compilation
  * **Solution:** Purge local caches to clean up temporary build volumes:
    ```bash
    flutter clean
    rm -rf ~/Library/Developer/Xcode/DerivedData
    pod cache clean --all
    ```
# jronix-media-downloader
