# NotchFlow Teleprompter

<p align="center">
  <img src="assets/banner.png" alt="NotchFlow Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/Apple%20Silicon-M1%20%7C%20M2%20%7C%20M3%20%7C%20M4-555555" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Tests-83%20Passing-22c55e" alt="Tests">
  <img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-FF6B00" alt="Privacy">
</p>

A native macOS speech-synchronized teleprompter anchored directly to your MacBook display notch.

---

## What is NotchFlow?

**NotchFlow** is a native macOS teleprompter built specifically for Apple Silicon MacBooks. It positions an ultra-smooth, floating teleprompter window right beneath your display notch and camera so you can deliver natural, confident presentations while maintaining direct eye contact with your audience.

As you speak, NotchFlow follows your voice in real time using on-device speech recognition. Words illuminate in Spotify-lyrics style with vibrant orange accents, while past words soften and upcoming sentences remain crystal-clear.

---

## Key Features

- **🎯 Native Display Notch Integration:** Measures physical display geometry (`auxiliaryTopLeftArea` / `auxiliaryTopRightArea`) to anchor flush beneath the camera notch with smooth continuous rounded corners.
- **✨ Auto-Shrink on Idle:** Moving your cursor away auto-shrinks the teleprompter into an unobtrusive 2-line glance bar hugging the camera notch. Hovering over it smoothly expands the full view.
- **↔️ Live Edge & Corner Resizing:** Drag any edge or corner (bottom, left, right, corners) with native cursor feedback to customize width (`380 pt – 950 pt`) and height (`180 pt – 650 pt`). Dimensions are remembered across sessions.
- **🌓 Dynamic Dark / Light Themes:** One-click toggle between **Pure Black** (`#000000`) and **Clean Studio White** (`#FFFFFF`) themes with high-contrast typography.
- **🎙️ Speech-Synchronized Tracking:** Low-latency word-by-word tracking with Levenshtein distance matching and forward confirmation windows to prevent jitter.
- **✨ Spotify-Style Word Highlighting:**
  - **Completed Words:** Softened opacity.
  - **Active Word:** Radiant accent orange (`#FF6B00`) with ambient glow and pill highlight.
  - **Upcoming Words:** Crisp readable white in dark mode / deep black in light mode.
- **🪞 Beam-Splitter Mirror Mode:** One-click horizontal text flipping for physical teleprompter glass rigs.
- **📄 Universal Document Import:** Paste directly or import `.txt`, `.md`, and `.pdf` documents with automated cleanup of markdown syntax, page numbers, and soft hyphenated line wraps.
- **💾 100% On-Device & Private:** Debounced autosave with JSON library persistence in `~/Library/Application Support/NotchFlow/`. Zero cloud, zero telemetry.
- **⌨️ Pro Keyboard Shortcuts:**
  - `Space` — Play / Pause
  - `←` / `→` — Step backward / forward one word
  - `↑` / `↓` — Jump backward / forward one sentence
  - `R` — Reset to beginning
  - `+` / `-` — Increase / decrease reading speed
  - `[` / `]` — Increase / decrease teleprompter font size
  - `D` — Toggle developer debug HUD
  - `Esc` — Dismiss teleprompter

---

## How to Use

1. **Write or Import a Script:** Launch NotchFlow and write your presentation in the editor, or click **"Import Document..."** to import any TXT, PDF, or Markdown file.
2. **Start Teleprompter:** Click **"Start Teleprompter"** to launch the teleprompter window right below your camera notch.
3. **Present Naturally:** Speak at your natural pace—NotchFlow listens and highlights words in real time.
4. **Auto-Shrink & Expand:** Move your mouse away to let it auto-shrink to an unobtrusive 2-line glance bar; hover over it anytime to expand full controls.
5. **Switch Themes:** Click the **Sun/Moon** button in the bottom control bar to toggle between Dark (Pure Black) and Light (Studio White) themes.
6. **Resize Anytime:** Move your cursor to any border or corner of the expanded prompter to drag and resize it to your preferred dimensions.

---

## System Requirements

- **Operating System:** macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or later.
- **Hardware:** Apple Silicon Mac (M1/M2/M3/M4) recommended. Works on MacBook displays with notch as well as external monitors (centered fallback).
- **Permissions:** Microphone access and Speech Recognition (prompted upon first session).

---

## Build & Test Instructions

### 1. Run Unit Tests (83 passing tests)
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
This produces `dist/NotchFlow.app` with embedded icons and resources ready to launch:
```bash
open dist/NotchFlow.app
```

### 4. Create Distributable DMG Installer (`NotchFlow-Installer.dmg`)
```bash
./build.sh dmg
```
This produces `dist/NotchFlow-Installer.dmg` ready for sharing and publishing on GitHub Releases.

### 5. Run Directly from Source
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
│   ├── Speech/           # SpeechRecognitionService, SpeechPermissionService, LocalWhisperService
│   ├── Synchronization/  # ReadingPositionService, ScriptMatchingService, TextNormalizationService, ScriptStructuringService, ScriptLineWrapService
│   └── Storage/          # ScriptStorageService, SettingsStorageService
├── WindowManagement/     # NotchWindowController (NSPanel HUD), DisplayGeometryService
└── DesignSystem/         # AppColors, AppTypography, AppSpacing, AnimationConfiguration, NotchFlowLogo
```

---

## Privacy & Security

- **Strictly Local:** Scripts, preferences, and speech recognition occur on-device. No telemetry, third-party trackers, or servers.
- **Capture Safe:** Teleprompter window uses `NSWindow.sharingType = .readOnly`, making it clean and standard for presentation workflows.
- **Sandboxed TCC:** Requires explicit user authorization for microphone input and speech recognition via macOS System Settings.
