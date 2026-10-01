<div align="center">
  <img src="assets/images/logo.png" alt="Twilight Music Logo" width="120">
  <h1>🌙 Twilight Music</h1>
  <p><strong>Ultra-fast cross-platform music streaming & offline player</strong></p>
  <p>
    <a href="https://github.com/hasibcore/Twilight/releases/latest"><img src="https://img.shields.io/github/v/release/hasibcore/Twilight?style=flat-square&color=6366f1&label=Latest+Release" alt="Release"></a>
    <a href="https://github.com/hasibcore/Twilight/releases/latest/download/app-release.apk"><img src="https://img.shields.io/badge/Android-APK-10b981?style=flat-square&logo=android" alt="Android"></a>
    <a href="https://github.com/hasibcore/Twilight/releases/latest/download/Twilight-Windows-x64.zip"><img src="https://img.shields.io/badge/Windows-x64-0284c7?style=flat-square&logo=windows" alt="Windows"></a>
    <a href="https://github.com/hasibcore/Twilight/releases/latest/download/Twilight-iOS.ipa"><img src="https://img.shields.io/badge/iOS-IPA-f43f5e?style=flat-square&logo=apple" alt="iOS"></a>
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter" alt="Flutter">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License">
  </p>
</div>

---

## ⬇️ Downloads

| Platform | Link | Notes |
|----------|------|-------|
| 🤖 **Android** | [app-release.apk](https://github.com/hasibcore/Twilight/releases/latest/download/app-release.apk) | Android 7.0+ — Direct APK installer |
| 🪟 **Windows PC** | [Twilight-Windows-x64.zip](https://github.com/hasibcore/Twilight/releases/latest/download/Twilight-Windows-x64.zip) | Windows 10/11 x64 — Portable ZIP |
| 🍎 **iOS** | [Twilight-iOS.ipa](https://github.com/hasibcore/Twilight/releases/latest/download/Twilight-iOS.ipa) | iOS 14+ — AltStore / Sideloadly / TrollStore |

> **All releases are built automatically via GitHub Actions on every `v*` tag push.**

---

## ✨ Features

- ⚡ **Instant Playback** — Multi-tiered audio stream cache starts music in under 100ms
- 🔒 **Lockscreen / Background Playback** — Notification media player with system controls
- ☁️ **Firebase Cloud Sync** — Login/signup to backup playlists & favorites across devices
- 📥 **Offline Downloads** — 256 kbps AAC M4A with cover artwork, playable without internet
- 📻 **Smart Radio Autoplay** — Endless listening with auto-cued similar tracks
- 🎛️ **Sleep Timer & Speed Control** — Spotify-grade comfort features
- 🚫 **Zero Ads** — No tracking, no interruptions, 100% open source

---

## 📱 Screenshots

| Home | Player | Library | Downloads |
|------|--------|---------|-----------|
| ![Home](preview_home.png) | ![Player](preview_player.png) | ![Library](preview_library.png) | ![Downloads](preview_history.png) |

---

## 🚀 Quick Start (Development)

### Prerequisites
- Flutter SDK 3.x (`flutter --version`)
- Android SDK (for Android builds)
- Xcode (for iOS builds — macOS only)
- Visual Studio 2022 with C++ workloads (for Windows builds)

### 1. Clone the Repository
```bash
git clone https://github.com/hasibcore/Twilight.git
cd Twilight
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure API Keys
```bash
cp assets/config/app_config.example.json assets/config/app_config.json
# Edit app_config.json with your YouTube API key and Firebase credentials
```

### 4. Run the App
```bash
flutter run                        # Run on connected device/emulator
flutter run -d windows             # Windows desktop
flutter run -d chrome              # Web browser
```

---

## ⚙️ Build Releases

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Windows PC
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

### iOS IPA (macOS required)
```bash
flutter build ios --release --no-codesign
mkdir -p Payload && cp -r build/ios/iphoneos/Runner.app Payload/
zip -r Twilight-iOS.ipa Payload
```

### Web
```bash
flutter build web --release
# Output: build/web/
```

---

## ☁️ Firebase Setup (Login & Cloud Sync)

1. Go to [Firebase Console](https://console.firebase.google.com/) → Create a project
2. Enable **Authentication** → Sign-in methods → **Email/Password** ✅
3. Enable **Firestore Database** (start in test mode)
4. Go to **Project Settings** → copy **Web API Key** and **Project ID**
5. Add to `assets/config/app_config.json`:

```json
{
  "youtubeApiKey": "YOUR_YOUTUBE_DATA_API_KEY",
  "firebaseApiKey": "YOUR_FIREBASE_WEB_API_KEY",
  "firebaseProjectId": "your-firebase-project-id"
}
```

> ⚠️ **Never commit `app_config.json`** — it's already in `.gitignore`.

---

## 🌐 Deploy the Download Landing Page

The `landing/` folder is a static download hub ready to deploy to:

| Platform | Command / Steps |
|----------|----------------|
| **Vercel** | `vercel --prod` or import repo in [vercel.com](https://vercel.com) |
| **Netlify** | `netlify deploy --prod --dir landing` or drag-drop `landing/` folder |
| **GitHub Pages** | Push to `main` → Actions auto-deploys to `hasibcore.github.io/Twilight` |

---

## 🤖 Auto Build & Release (GitHub Actions)

Every time you push a version tag, releases are built for all 3 platforms automatically:

```bash
git tag v1.0.1
git push origin v1.0.1
# → Builds Android APK, Windows ZIP, iOS IPA
# → Creates GitHub Release with all 3 files attached
```

---

## 🗂️ Project Structure

```
lib/
├── core/
│   ├── config/          # Firebase config
│   ├── constants/       # Colors, strings, theme
│   ├── services/        # Audio engine, Firebase, Download, Extractor
│   └── utils/           # Logger
├── data/
│   ├── datasources/     # Remote (YouTube API) & Local (SharedPrefs)
│   ├── models/          # JSON serialization models
│   └── repositories/    # Implementation of domain contracts
├── domain/
│   ├── entities/        # Pure data classes (Song, UserProfile, etc.)
│   └── repositories/    # Abstract repository interfaces
└── presentation/
    ├── navigation/      # App routing
    ├── providers/       # State management (ChangeNotifier)
    ├── screens/         # UI screens (Auth, Home, Player, Library, etc.)
    └── widgets/         # Reusable UI components

landing/                 # Static download & info website
.github/workflows/       # CI/CD: release.yml + deploy-pages.yml
```

---

## 📄 License

MIT License — see [LICENSE](LICENSE) file.

---

<div align="center">
  Built with ❤️ using Flutter · Maintained by <a href="https://github.com/hasibcore">@hasibcore</a>
</div>
