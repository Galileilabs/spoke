import AppKit

final class SpeechManager: ObservableObject {

    // MARK: - Published state

    @Published var selectedSpeed: SpeedOption = .x1
    @Published var isPlaying = false

    // MARK: - Types

    enum SpeedOption: String, CaseIterable {
        case x075 = "0.75x"
        case x1   = "1x"
        case x125 = "1.25x"
        case x15  = "1.5x"
        case x2   = "2x"

        /// Words per minute for the `say -r` flag, nil = system default (~175 WPM).
        var wpm: Int? {
            switch self {
            case .x075: return 131
            case .x1:   return nil
            case .x125: return 219
            case .x15:  return 263
            case .x2:   return 350
            }
        }
    }

    // MARK: - Internal

    private var previewProcess: Process?
    private var terminationObserver: Any?

    init() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.previewProcess?.terminate()
        }
    }

    deinit {
        previewProcess?.terminate()
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - say command helpers

    func sayArguments(speed: SpeedOption, inputFile: URL) -> [String] {
        var args: [String] = []
        if let wpm = speed.wpm {
            args += ["-r", "\(wpm)"]
        }
        args += ["-f", inputFile.path]
        return args
    }

    // MARK: - Preview playback

    func stopPreview() {
        guard isPlaying else { return }
        previewProcess?.terminate()
        previewProcess = nil
        isPlaying = false
    }

    func togglePreview(text: String) {
        if isPlaying {
            stopPreview()
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoke_preview.txt")
        do {
            try trimmed.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = sayArguments(speed: selectedSpeed, inputFile: tempURL)
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.previewProcess = nil
                try? FileManager.default.removeItem(at: tempURL)
            }
        }

        do {
            try process.run()
            previewProcess = process
            isPlaying = true
        } catch {
            // silently fail
        }
    }

    // MARK: - Open Voice Settings

    static func openVoiceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?ReadAndSpeak") {
            NSWorkspace.shared.open(url)
        }
    }
}
