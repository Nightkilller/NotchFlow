# NotchFlow

A native macOS speech-synchronized teleprompter anchored directly to your MacBook display notch.

![NotchFlow Banner](NotchFlow/Resources/AppInfo.json)

## What is NotchFlow?

NotchFlow is a native macOS teleprompter designed specifically for Apple Silicon MacBooks. It positions an ultra-smooth, floating teleprompter window right below your display notch and camera so you can deliver natural, confident presentations while keeping direct eye contact with your audience.

As you speak, NotchFlow follows your voice in real time using Apple's on-device speech framework. Each word illuminates in Spotify-style high-contrast orange, while past text softens and upcoming sentences remain crystal-clear.

---

## Key Features

- **🎯 Display Notch Integration:** Accurately measures physical display geometry (`auxiliaryTopLeftArea` / `auxiliaryTopRightArea`) to position the teleprompter directly beneath the camera. Smoothly transitions between a minimal collapsed status pill and an expanded HUD.
- **🎙️ Speech-Synchronized Tracking:** Leverages `SFSpeechRecognizer` and `AVAudioEngine` for low-latency word tracking. Uses Levenshtein distance matching and forward confirmation windows to prevent jitter.
- **✨ Spotify-Style Word Highlighting:** Real-time visual feedback:
  - **Completed Words:** Softened to 38% opacity.
  - **Active Word:** Radiant accent orange with ambient glow and subtle scale.
  - **Active Sentence:** Soft ambient container highlight.
  - **Upcoming Words:** Crisp readable white.
- **⚡ Pre-Start Countdown:** Configurable 3-second or 5-second countdown ("3... 2... 1... Speak!") to prepare you before voice tracking begins.
- **👀 Eye-Level Reading Guide Line:** Subtle horizontal eye-level indicator with arrow guides placed right at the camera focal plane.
- **🪞 Beam-Splitter Mirror Mode:** One-click horizontal text flipping for physical teleprompter glass rigs.
- **📄 Universal Document Import:** Paste directly or import `.txt`, `.md`, and `.pdf` documents with automated cleanup of markdown syntax, page numbers, and soft hyphenated line wraps.
- **💾 Local-First Persistence:** Debounced autosave with JSON library persistence in `~/Library/Application Support/NotchFlow/`. Zero cloud, zero telemetry.
- **⌨️ Pro Keyboard Shortcuts:**
  - `Space` — Play / Pause
  - `←` / `→` — Step backward / forward one word
  - `↑` / `↓` — Jump backward / forward one sentence
  - `R` — Reset to beginning
  - `+` / `-` — Increase / decrease reading speed
  - `[` / `]` — Increase / decrease teleprompter font size
  - `Esc` — Collapse to notch pill or dismiss
- **📦 Packaged `.app` Bundle:** Fully packaged with `Info.plist` declaring camera-safe non-activating window HUD behavior and TCC permissions for Microphone and Speech Recognition.

---

## System Requirements

- **Operating System:** macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or later.
- **Hardware:** Apple Silicon Mac (M1/M2/M3/M4) recommended. Works on MacBook displays with notch as well as external monitors (centered fallback).
- **Permissions:** Microphone access and Speech Recognition (prompted upon first voice session).

---

## Quick Start & Build Instructions

### 1. Run Unit Tests (58 passing tests)
```bash
./build.sh test
```

### 2. Build Release Binary
```bash
./build.sh release
```

### 3. Package Native macOS Application Bundle (`NotchFlow.app`)
```bash
./build.sh package
```
This produces `dist/NotchFlow.app` ready to launch:
```bash
open dist/NotchFlow.app
```

### 4. Run Directly from Source
```bash
./build.sh run
```

---

## Architecture Overview

NotchFlow is built with Swift 6 and strict concurrency safety without external dependencies:

```
NotchFlow/
├── App/                  # App entry point, AppDelegate lifecycle hooks
├── Models/               # Script, ScriptSection, ScriptSentence, ScriptWord, ReadingSettings
├── ViewModels/           # EditorViewModel, TeleprompterViewModel
├── Views/
│   ├── Editor/           # MainEditorView (Sidebar library, editor surface, live metrics)
│   ├── Notch/            # NotchContainerView, CollapsedNotchView, TeleprompterView, WordHighlightView
│   └── Settings/         # SettingsView (Typography, Notch dimensions, Playback defaults)
├── Services/
│   ├── Import/           # ScriptImportService, PDFImportService, MarkdownImportService, PlainTextImportService
│   ├── Speech/           # SpeechRecognitionService, SpeechPermissionService
│   ├── Synchronization/  # ReadingPositionService, ScriptMatchingService, TextNormalizationService, ScriptStructuringService
│   └── Storage/          # ScriptStorageService, SettingsStorageService
├── WindowManagement/     # NotchWindowController (NSPanel HUD), DisplayGeometryService
└── DesignSystem/         # AppColors, AppTypography, AppSpacing, AnimationConfiguration
```

---

## Privacy & Security

- **Strictly Local:** Scripts, preferences, and speech recognition occur on-device. No telemetry, third-party trackers, or servers.
- **Capture Safe:** Teleprompter window uses `NSWindow.sharingType = .readOnly`, making it clean and standard for presentation workflows.
- **Sandboxed TCC:** Requires explicit user authorization for microphone input and speech recognition via macOS System Settings.
