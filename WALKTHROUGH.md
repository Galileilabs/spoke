## Project structure

```
spoke/
├── Spoke.xcodeproj/          ← Xcode project (macOS 13+, Swift 5, hardened runtime)
└── Spoke/
    ├── SpokeApp.swift         ← App entry point — single WindowGroup titled "Spoke"
    ├── ContentView.swift      ← Full UI layout
    ├── SpeechManager.swift    ← Voice loading, selection, preview playback
    ├── AudioExporter.swift    ← M4A export via write(_:toBufferCallback:)
    ├── Spoke.entitlements     ← Hardened runtime entitlement
    └── Assets.xcassets/       ← App icon + accent color slots
```

## Key files explained

### `SpokeApp.swift`
Minimal `@main` entry point with a single `WindowGroup("Spoke")`, default size 700×650, resizable with minimum size.

### `ContentView.swift`
Single-window layout, top to bottom:
- **Import / Paste buttons** — file importer filtered to `.txt`, clipboard paste via `NSPasteboard`
- **TextEditor** — fills available space, monospaced font for a document feel
- **Voice picker** — populated from `AVSpeechSynthesisVoice.speechVoices()`, showing name + locale + gender
- **Speed picker** — Slow / Normal / Fast mapped to `AVSpeechUtteranceDefaultSpeechRate` multipliers
- **Preview toggle** — play/stop using SF Symbols `play.fill` / `stop.fill`
- **Convert & Save** — full-width `.borderedProminent` button, opens `NSSavePanel` for `.m4a`
- **Status line** — muted caption showing last saved path or error

### `SpeechManager.swift`
- Loads and sorts all system voices, defaults to a Siri voice if found
- `displayName(for:)` formats as `"Samantha (English (United States), Female)"`
- `togglePreview(text:)` plays/stops via `AVSpeechSynthesizer.speak()`
- Delegate callbacks update `isPlaying` on the main queue

### `AudioExporter.swift`
- `export(text:voice:rate:to:completion:)` — the core export pipeline
- Uses `AVSpeechSynthesizer.write(_:toBufferCallback:)` — each PCM buffer is written to an `AVAudioFile` configured with AAC/M4A settings (`kAudioFormatMPEG4AAC`, 128 kbps)
- The audio file is created lazily on the first buffer (so we get the correct sample rate/channel count from the synthesizer)
- Thread safety via a serial `DispatchQueue`; completion delivered on main queue
- Delegate's `didFinish` closes the file and signals success

### Distribution configuration
- **Bundle ID**: `com.spoke.spoke` (update in target build settings)
- **Signing**: `CODE_SIGN_IDENTITY = "Developer ID Application"` + `CODE_SIGN_STYLE = Manual`
- **Hardened runtime**: `ENABLE_HARDENED_RUNTIME = YES`
- **Entitlement**: `com.apple.security.cs.allow-unsigned-executable-memory` (needed for notarization with some system frameworks)
- **DEVELOPMENT_TEAM**: Set your Team ID in the target build settings before archiving

## To run

Open `Spoke.xcodeproj` in Xcode, select the Spoke scheme, and hit Run. For distribution, set your `DEVELOPMENT_TEAM`, archive, and submit to Apple's notarization service via `xcrun notarytool`.
