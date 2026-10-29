# NotchFlow Architecture

This document describes the architectural design, component responsibilities, data flow, windowing strategy, speech synchronization approach, and persistence decisions for NotchFlow.

---

## 1. Architectural Philosophy

NotchFlow is a native macOS teleprompter designed with a strict separation of concerns following the **MVVM (Model-View-ViewModel) + Service Layer** pattern.

Key architectural boundaries:
- **UI Views** remain declarative and lightweight, reacting to state published by ViewModels.
- **ViewModels** govern screen presentation state, orchestration, and user action dispatching.
- **Domain Services** encapsulate business logic, algorithm execution, speech recognition, and system APIs independently of SwiftUI.
- **Window Management** is isolated in AppKit controllers (`NSPanel`, `NSScreen`), insulating SwiftUI views from display geometry calculations.
- **Hardware/SDK Integration** (Speech, Screen Geometry, Hotkeys) uses native public Apple frameworks without third-party dependencies.

---

## 2. Target Platform & Environment

- **Host Machine:** MacBook Air M4 running macOS 27.0.1 (Darwin 26A434).
- **Deployment Target:** macOS 15.0 (Sequoia).
- **SDK:** macOS 27.0 SDK (`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`).
- **Toolchain:** Swift 6.4 (Swift 6 language mode with strict concurrency).
- **Project Structure:** Swift Package Manager executable target with tests.

---

## 3. High-Level System Architecture

```
┌────────────────────────────────────────────────────────┐
│                      SwiftUI UI                        │
│  MainEditorView │ ScriptLibraryView │ NotchPrompterView│
└───────────┬───────────────────────────────────┬────────┘
            │                                   │
┌───────────▼───────────┐           ┌───────────▼────────┐
│    EditorViewModel    │           │TeleprompterViewModel│
└───────────┬───────────┘           └───────────┬────────┘
            │                                   │
┌───────────▼───────────────────────────────────▼────────┐
│                    Domain Services                     │
│  ┌───────────────────────┐  ┌───────────────────────┐  │
│  │  ScriptImportService  │  │SpeechRecognitionServ. │  │
│  │  (PDF, TXT, Markdown) │  │(SFSpeechRecognizer)   │  │
│  └───────────────────────┘  └───────────┬───────────┘  │
│  ┌───────────────────────┐              │              │
│  │ DocumentCleaningServ. │  ┌───────────▼───────────┐  │
│  │ (Normalization)       │  │ ScriptMatchingService │  │
│  └───────────────────────┘  │ (Synchronization Engine│  │
│  ┌───────────────────────┐  └───────────┬───────────┘  │
│  │ ScriptStorageService  │              │              │
│  │ (Application Support) │  ┌───────────▼───────────┐  │
│  └───────────────────────┘  │ReadingPositionService │  │
│  ┌───────────────────────┐  └───────────────────────┘  │
│  │SettingsStorageService │                             │
│  │ (UserDefaults)        │                             │
│  └───────────────────────┘                             │
└───────────────────────────────────────┬────────────────┘
                                        │
                         ┌──────────────▼─────────────┐
                         │      AppKit Windowing      │
                         │   NotchWindowController    │
                         │  DisplayGeometryService    │
                         └────────────────────────────┘
```

---

## 4. Domain Models

All models conform to `Sendable`, `Identifiable`, `Equatable`, and `Codable`.

- **`Script`**: The root document entity containing raw source text, structured sections, timestamps, and title.
- **`ScriptSection`**: Represents a structural block (paragraph, heading) containing sentences.
- **`ScriptSentence`**: Represents an individual sentence containing an ordered collection of words.
- **`ScriptWord`**: Stable token entity with global and sentence-relative indices, display text (preserving casing & punctuation), and computed normalized text for speech matching.
- **`ReadingPosition`**: Tracks word-level advancement index, total word count, progress percentage, and provides boundary-checked stepping operations.
- **`ReadingSettings`**: Persisted configuration (font size, line spacing, window dimensions, reading mode, scroll speed, visible lines, mirror toggle).

---

## 5. Teleprompter Window Management

The teleprompter window is implemented as a borderless, non-activating `NSPanel` (`NotchWindowController`):

1. **Non-activating**: Uses `.nonactivatingPanel` style mask so it never steals focus or keyboard events from presentations, camera software, or screen sharing.
2. **Window Level**: Configured at `.floating` or `.status` level to stay visible above standard windows.
3. **Spaces & Fullscreen**: Collection behavior `.canJoinAllSpaces` and `.fullScreenAuxiliary` ensures persistence across Spaces and full-screen presentations.
4. **Notch Geometry Detection**:
   - Queries `NSScreen.main?.auxiliaryTopLeftArea` and `auxiliaryTopRightArea`.
   - The gap between auxiliary top-left and top-right gives the exact width and height of the hardware notch.
   - Falls back gracefully on notchless displays to top-center positioning beneath the menu bar.
5. **Collapsed vs Expanded States**:
   - *Collapsed*: Minimal notch hugger indicator showing status dot and play/pause button.
   - *Expanded*: Floating dark HUD with reading surface below the notch line. Smooth animation via `NSAnimationContext`.

---

## 6. Speech Synchronization Engine

The synchronization engine operates independently of UI and audio capture:

1. **Audio Capture & Recognition**:
   - Uses `AVAudioEngine` for microphone input.
   - Feeds buffers to `SFSpeechAudioBufferRecognitionRequest` configured for `requiresOnDeviceRecognition = true` (with fallback) and `addsPunctuation = true`.
2. **Text Normalization**:
   - Strips non-alphanumeric characters except apostrophes.
   - Lowercases tokens and normalizes numbers/symbols to spoken form.
3. **Bounded Window Matching**:
   - Rather than searching the entire script on every partial result, searches within a sliding window: **5 words behind** to **40 words ahead** of the confirmed position.
4. **Hysteresis & Anti-Jitter**:
   - Commits forward advances only after confirmation across consecutive partial results or a final result.
   - Strict backward-jump inhibition: requires a 4+ word consecutive high-confidence match before allowing a backward position update.
   - Tolerates small Levenshtein edit distance differences (≤ 1 for 4-7 char words, ≤ 2 for 8+ char words).

---

## 7. Persistence Strategy

- **Scripts:** Stored as individual JSON files in `~/Library/Application Support/NotchFlow/Scripts/` with an `index.json` metadata catalog for rapid listing. This avoids SwiftData schema migration overhead and allows human-readable backups.
- **Settings:** Stored in standard `UserDefaults` under key `com.notchflow.settings`.
