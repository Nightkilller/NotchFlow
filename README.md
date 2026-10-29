# NotchFlow

A native macOS teleprompter that anchors to the MacBook notch and follows your voice.

## What is NotchFlow?

NotchFlow is a speech-synchronized teleprompter designed for MacBook users. It displays your script in a compact, notch-anchored overlay so you can read prepared material while looking toward your camera.

As you speak, NotchFlow highlights the current word, dims previously spoken text, and keeps upcoming lines visible — inspired by synchronized lyrics interfaces.

## Key Features

- **Notch-anchored teleprompter** — positions the reading surface around the MacBook display notch
- **Voice-paced reading** — follows your speech using on-device speech recognition
- **Word-level highlighting** — current word accented, completed words dimmed, upcoming words bright
- **Manual controls** — keyboard navigation when voice tracking isn't available
- **Document import** — paste text or import TXT, PDF, and Markdown files
- **Local-only storage** — scripts stay on your Mac, no account required

## Requirements

- macOS 15.0 (Sequoia) or later
- MacBook with Apple Silicon (M-series)
- MacBook with display notch (for notch-anchored positioning)
- Microphone access (for voice-paced reading)

The application can be used without a notch display (centered fallback) and without a microphone (manual or auto-scroll modes).

## Development Setup

### Prerequisites

- Swift 6.0+ (included with Xcode 16+ or Command Line Tools)
- macOS 15.0 SDK or later

### Build

```bash
swift build
```

### Run

```bash
swift run NotchFlow
```

### Test

```bash
swift test
```

## Current Status

**Phase 0 — Environment and Project Discovery** ✅

- Project structure established
- Design system created
- Core data models implemented
- Initial editor view created
- Unit tests for models written
- Documentation initialized

See [Documentation/DEVELOPMENT_PLAN.md](Documentation/DEVELOPMENT_PLAN.md) for the full roadmap.

## Architecture

The application follows MVVM with clear service-layer separation:

- **Models** — Script, Section, Sentence, Word with stable identities
- **Views** — SwiftUI views for editor and teleprompter
- **ViewModels** — Bridge between views and services
- **Services** — Import, Speech, Synchronization, Storage, Timing
- **WindowManagement** — AppKit-based notch positioning
- **DesignSystem** — Centralized colors, typography, spacing, animations

See [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for details.

## Privacy

- All scripts are stored locally in Application Support
- Speech recognition uses Apple's framework (on-device when available)
- No accounts, cloud storage, or analytics
- Microphone is only active during teleprompter sessions

## License

Private project — not licensed for redistribution.
