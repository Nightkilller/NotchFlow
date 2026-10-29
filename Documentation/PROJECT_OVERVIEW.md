# NotchFlow — Project Overview

## What is NotchFlow?

NotchFlow is a native macOS teleprompter application designed for MacBook users with display notches. It anchors a compact reading interface around the physical notch area, allowing users to read prepared scripts while maintaining eye contact with their camera.

The application uses speech recognition to track the user's reading position, providing real-time word-level highlighting inspired by synchronized lyrics interfaces.

## Who is it for?

- **Students** recording college presentations or practising placement interviews
- **Content creators** recording videos
- **Professionals** delivering remote presentations
- **Teachers** recording lessons
- **Anyone** who needs to read prepared material while looking toward a camera

## Core Workflows

### 1. Script Preparation
1. Launch NotchFlow
2. Create a new script by typing/pasting text, or import a document (TXT, PDF, Markdown)
3. Review and edit the script in the editor
4. Optionally organize into sections

### 2. Teleprompter Session
1. Click "Start" in the editor
2. The notch-anchored reading overlay appears
3. Choose reading mode: Voice-Paced, Auto-Scroll, or Manual
4. Begin speaking (voice-paced) or control position manually
5. Current word is highlighted orange, completed words dim, upcoming words remain bright
6. Use keyboard shortcuts for navigation
7. Stop when finished — microphone is released, script is saved

### 3. Script Library
1. Scripts are saved locally in Application Support
2. Reopen any saved script from the sidebar
3. Rename, edit, or delete scripts as needed

## Implementation Status

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Environment & Project Discovery | ✅ Complete |
| 1 | Application Foundation | 🔲 Next |
| 2 | Notch Window Management | 🔲 Planned |
| 3 | Script Rendering & Highlighting | 🔲 Planned |
| 4 | Document Import | 🔲 Planned |
| 5 | Speech Recognition | 🔲 Planned |
| 6 | Script Synchronization | 🔲 Planned |
| 7 | Voice-Paced Reading & Timer | 🔲 Planned |
| 8 | Persistence & Script Library | 🔲 Planned |
| 9 | Settings & Polish | 🔲 Planned |
| 10 | Final Validation | 🔲 Planned |

## Privacy

- All scripts stored locally — no cloud sync
- No user accounts required
- Speech recognition uses Apple's framework (on-device when available)
- No analytics or telemetry
- Microphone only active during sessions
