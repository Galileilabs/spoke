import Foundation

final class AudioExporter {

    enum ExportError: LocalizedError {
        case emptyText
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyText:           return "No text to convert."
            case .exportFailed(let m): return "Export failed: \(m)"
            }
        }
    }

    private var process: Process?

    /// Export text to M4A using the `say` command with the system voice.
    func export(
        text: String,
        speed: SpeechManager.SpeedOption,
        to url: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(ExportError.emptyText))
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoke_export_\(UUID().uuidString).txt")
        do {
            try trimmed.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            completion(.failure(error))
            return
        }

        var args: [String] = []
        if let wpm = speed.wpm {
            args += ["-r", "\(wpm)"]
        }
        args += [
            "-o", url.path,
            "--file-format=m4af",
            "--data-format=aac",
            "-f", tempURL.path,
        ]

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        proc.arguments = args
        proc.terminationHandler = { finished in
            try? FileManager.default.removeItem(at: tempURL)
            DispatchQueue.main.async {
                if finished.terminationStatus == 0 {
                    completion(.success(url))
                } else {
                    completion(.failure(ExportError.exportFailed(
                        "say exited with status \(finished.terminationStatus)")))
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            completion(.failure(error))
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
    }
}
