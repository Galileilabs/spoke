# Spoke — Next Feature Enhancements

## 1. Simplify to System Voice only
Remove the Language and Voice pickers entirely. Always use the system voice (no `-v` flag to `say`). This keeps the UI minimal and avoids exposing the low-quality non-Siri voices.

## 2. Refined speed options
Replace Slow/Normal/Fast with explicit multipliers: **0.75x, 1x, 1.25x, 1.5x, 2x**. Map these to `say -r` WPM values (default ~175 WPM, so 0.75x ≈ 131, 1x = nil/default, 1.25x ≈ 219, 1.5x ≈ 263, 2x ≈ 350).

## 3. Voice settings shortcut
Add a button that opens System Settings directly to the Spoken Content voice management page (`x-apple.systempreferences:com.apple.preference.universalaccess?SpeechServices`). Include a tooltip with brief instructions: "Download a Siri voice in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices, then set it as your System Voice."

## 4. Export progress and Reveal in Finder
- Show a progress indicator during audio file generation. The `say` command doesn't report progress, so either use an indeterminate progress bar or estimate based on text length and speed.
- When export completes, replace the status line with a "Reveal in Finder" button that calls `NSWorkspace.shared.activateFileViewerSelecting([url])`.
