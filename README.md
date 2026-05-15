# Popodoro

<p align="center">
  <img src="assets/icon/popodoro_mascot.svg" alt="Popodoro mascot" width="180" />
</p>

A focused Pomodoro timer for macOS and Windows — built with Flutter.

![Version](https://img.shields.io/badge/version-1.0.4-blue)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey)
![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)

---

## Features

### Core Timer
- Customizable focus, short break, and long break durations
- Long-break interval (e.g. long break every 4 sessions)
- Keyboard-friendly with a system tray icon showing live countdown
- Sound effects on session transitions

### Projects & Tasks
- Create projects with a name and color
- Add tasks with optional Pomodoro estimates and track actual vs. expected
- **Obsidian integration** — link one or more `.md` files from an Obsidian vault; unchecked tasks surface directly in the app
- macOS sandbox-safe: vault access is persisted across relaunches using security-scoped bookmarks

### Focus Guard (AI)
- On-device YOLO model detects when you leave your desk or pick up your phone
- Automatically pauses the timer and resumes when you return
- No data leaves your device — all inference runs locally
- Works on macOS, Windows, and Android

### Background Sound
- Built-in ambient tracks: White noise, Rain, Lo-fi hip-hop, Guts meditation
- Tracks download once and are cached locally
- Volume slider with live preview
- Plays only during focus sessions, pauses automatically on breaks

### Together Mode
- Real-time co-focus rooms powered by Supabase
- Share a 6-character room code with a friend
- Synchronized timer: host controls start/pause/break, all members see the same clock
- Lobby with participant list before the session begins

### Stats
- Daily and weekly Pomodoro bar charts
- Per-project breakdown
- Session history with tags

### Appearance & Customization
- Light / Dark / System theme
- Timer style: classic dial or minimal text
- Home screen toggles: show/hide greeting, nudge card, project row, session info
- Customizable nudge messages

### Auto-Update
- Checks for new releases via a GitHub Pages appcast
- Download link opens directly to the release page

---

## Platforms

| Platform | Status       |
|----------|--------------|
| macOS    | Supported  |
| Windows  | Supported  |
| Android  | Supported  |
| iOS      | Not targeted |
| Linux    | Not targeted |

---

## Download

Pre-built binaries are attached to every [GitHub Release](https://github.com/hajorda/popodoro/releases):

| File | Description |
|------|-------------|
| `popodoro-macos.dmg` | macOS disk image (drag to Applications) |
| `popodoro-X.X.X-windows-installer.exe` | Windows Inno Setup installer |
| `popodoro-X.X.X-android-arm64-v8a.apk` | Android APK (64-bit, most devices) |
| `popodoro-X.X.X-android.aab` | Android App Bundle (Play Store) |

> **macOS note:** The DMG is unsigned. Right-click → Open the first time to bypass Gatekeeper.

---

## Building from Source

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Xcode 15+ (macOS builds)
- Visual Studio 2022 with Desktop C++ workload (Windows builds)
- Android Studio / SDK (Android builds)

### Steps

```bash
# 1. Clone
git clone https://github.com/hajorda/popodoro.git
cd popodoro

# 2. Install dependencies
flutter pub get

# 3. Run
flutter run -d macos      # or windows / android

# 4. Build release
flutter build macos --release
flutter build windows --release
flutter build apk --release --split-per-abi
```

### macOS Entitlements

The app uses the following sandbox entitlements:

| Entitlement | Reason |
|-------------|--------|
| `com.apple.security.app-sandbox` | Required for Mac App Store / notarization |
| `com.apple.security.network.client` | Download ambient tracks, sync, update check |
| `com.apple.security.files.user-selected.read-write` | Obsidian vault file picker |
| `com.apple.security.files.bookmarks.app-scope` | Re-open vault across relaunches without re-prompting |
| `com.apple.security.device.camera` | Focus Guard AI detection |

### Android Permissions

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

---

## Architecture

```
lib/
├── controllers/        # ChangeNotifier state (timer, project, settings)
├── core/
│   └── theme/          # Design tokens, typography, AppTokens
├── database/           # SQLite via sqflite_common_ffi
├── models/             # Project, SessionRecord, etc.
├── screens/            # UI screens (home, break, complete, settings, stats, together)
├── services/           # Business logic (timer audio, BG music, Focus Guard, sync, update)
└── widgets/            # Shared widgets
```

**State management:** Provider (`ChangeNotifier`) — no code generation.  
**Local DB:** SQLite via `sqflite_common_ffi` (works on desktop + Android).  
**Remote:** Supabase Realtime for Together mode; anonymous auth.  
**AI inference:** `tflite_flutter` with a bundled YOLO model for Focus Guard.

---

## CI / CD

GitHub Actions (`.github/workflows/build.yml`) builds and releases automatically:

| Job | Trigger | Output |
|-----|---------|--------|
| `build-macos` | Push to `main` or tag | `popodoro-macos.dmg` artifact |
| `build-windows` | Push to `main` or tag | Inno Setup `.exe` artifact |
| `build-android` | Push to `main` or tag | APKs + AAB artifacts |
| `release` | Tag `v*.*.*` only | GitHub Release with all three binaries |
| `deploy-pages` | Tag `v*.*.*` only | Appcast XML to GitHub Pages |

### Android signing

To enable signed release APKs, add these repository secrets:

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` / `.keystore` file |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |

Without these secrets, the Android job still builds but signs with the debug key.

---

## Obsidian Integration

1. Go to **Settings → Obsidian** and connect your vault folder.
2. Create a project of type **Obsidian** and pick one or more `.md` files.
3. Unchecked `- [ ] task` items from those files appear in the project task list.
4. Check them off inside Popodoro — the file is updated in place.

Vault access is stored as a macOS security-scoped bookmark so you won't be re-prompted after relaunch.

---

## License

MIT
