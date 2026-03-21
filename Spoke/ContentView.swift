import SwiftUI
import UniformTypeIdentifiers

#Preview {
    ContentView()
}

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var text = ""
    @State private var statusMessage = "Ready"
    @State private var isExporting = false
    @State private var showFileImporter = false
    @State private var showPasteSheet = false
    @State private var pasteText = ""
    @State private var exportedURL: URL? = nil
    @State private var isDragTargeted = false
    @State private var showVoiceGuide = false

    private let exporter = AudioExporter()
    private let maxTextBytes = 100_000 // 100 KB

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Branding
            VStack(spacing: 4) {
                Text("Spoke")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                Text("Turn text into spoken audio")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(nsColor: .darkGray))
            }
            .padding(.bottom, 8)

            // MARK: - Text input area
            if textIsEmpty {
                dropWell
            } else {
                textPreview
            }

            // MARK: - Speed / Preview / Voice Settings
            HStack(spacing: 16) {
                Picker("Speed", selection: $speechManager.selectedSpeed) {
                    ForEach(SpeechManager.SpeedOption.allCases, id: \.self) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
                .frame(width: 140)

                Button {
                    speechManager.togglePreview(text: previewText)
                } label: {
                    Label(
                        speechManager.isPlaying ? "Stop" : "Preview",
                        systemImage: speechManager.isPlaying ? "stop.fill" : "play.fill"
                    )
                }
                .disabled(textIsEmpty)

                Spacer()

                Button {
                    showVoiceGuide = true
                } label: {
                    Label("Learn how to pick the best voices", systemImage: "questionmark.circle")
                }
            }

            // MARK: - Convert & Save
            Button {
                convertAndSave()
            } label: {
                Label("Convert & Save", systemImage: "square.and.arrow.down")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(textIsEmpty || isExporting)

            // MARK: - Status bar
            HStack(spacing: 10) {
                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Converting\u{2026}")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else if let url = exportedURL {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .controlSize(.large)
                } else {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                if exportedURL == nil { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isExporting || exportedURL != nil ? 12 : 4)
            .background(
                (isExporting || exportedURL != nil)
                    ? Color.white.opacity(0.85)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .padding(56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("Background")
                .resizable()
                .scaledToFill()
        )
        .ignoresSafeArea()
        .frame(minWidth: 600, minHeight: 300)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText]
        ) { result in
            switch result {
            case .success(let url):
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    loadText(content)
                }
            case .failure(let error):
                statusMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showPasteSheet) {
            pasteSheet
        }
        .sheet(isPresented: $showVoiceGuide) {
            voiceGuideSheet
        }
    }

    // MARK: - Drop well (empty state)

    private var dropWell: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Drop a text file here")
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Browse\u{2026}", systemImage: "folder")
                }
                Button {
                    pasteText = ""
                    showPasteSheet = true
                } label: {
                    Label("Paste Text", systemImage: "doc.on.clipboard")
                }
            }
            Text("Max 100 KB of text — enough for ~2 hours of audio")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDragTargeted ? Color.accentColor : Color.white.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
        }
        .background {
            if isDragTargeted {
                Color.accentColor.opacity(0.1)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .onDrop(of: [.plainText, .fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Text preview (loaded state)

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(previewLines)
                .font(.system(.body, design: .monospaced))
                .lineLimit(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary)

            Divider()

            HStack(spacing: 12) {
                Text("\(text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    pasteText = ""
                    showPasteSheet = true
                } label: {
                    Label("Paste Text", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.link)

                Button {
                    showFileImporter = true
                } label: {
                    Label("Replace\u{2026}", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.link)

                Button {
                    speechManager.stopPreview()
                    text = ""
                    exportedURL = nil
                    statusMessage = "Ready"
                } label: {
                    Label("Clear", systemImage: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
        .onDrop(of: [.plainText, .fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Paste sheet

    private var pasteSheet: some View {
        VStack(spacing: 16) {
            Text("Paste or type your text")
                .font(.headline)

            TextEditor(text: $pasteText)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 450, minHeight: 250)

            HStack {
                Button("Cancel") {
                    showPasteSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Use This Text") {
                    if !pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        loadText(pasteText)
                    }
                    showPasteSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
    }

    // MARK: - Voice guide sheet

    private var voiceGuideSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Getting the Best Voices")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Spoke uses your Mac\u{2019}s System Voice. For the best results, download a high-quality Siri voice:")

            VStack(alignment: .leading, spacing: 8) {
                guideStep(number: 1, text: "Open **System Settings \u{2192} Accessibility \u{2192} Read & Speak**")
                guideStep(number: 2, text: "Click **System Voice** and choose **Manage Voices\u{2026}**")
                guideStep(number: 3, text: "Download a Siri voice (look for the best quality options)")
                guideStep(number: 4, text: "Set your preferred voice as the **System Voice**")
            }

            Text("Spoke will automatically use whatever voice you set as the System Voice.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("Done") {
                    showVoiceGuide = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    SpeechManager.openVoiceSettings()
                } label: {
                    Label("Open Voice Settings\u{2026}", systemImage: "gear")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func guideStep(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .fontWeight(.semibold)
                .frame(width: 20, alignment: .trailing)
            Text(text)
        }
    }

    // MARK: - Helpers

    private func loadText(_ content: String) {
        if content.utf8.count > maxTextBytes {
            statusMessage = "File too large — 100 KB limit"
            return
        }
        speechManager.stopPreview()
        text = content
        exportedURL = nil
        statusMessage = "Ready"
    }

    private var textIsEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewText: String {
        let lines = text.components(separatedBy: .newlines)
        return lines.prefix(10).joined(separator: "\n")
    }

    private var previewLines: String {
        let lines = text.components(separatedBy: .newlines)
        let preview = lines.prefix(10).joined(separator: "\n")
        if lines.count > 10 {
            return preview + "\n\u{2026}"
        }
        return preview
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // loadFileRepresentation is the modern API for Finder file drops —
        // it gives us a temporary URL to the file while it's still accessible.
        let textTypes = ["public.utf8-plain-text", "public.plain-text"]
        for typeId in textTypes {
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
                    guard let url = url,
                          let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                    DispatchQueue.main.async { self.loadText(content) }
                }
                return true
            }
        }

        // Fallback: generic file URL (e.g. drag from somewhere other than Finder)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let u = item as? URL { url = u }
                else if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else { url = nil }
                guard let u = url, let content = try? String(contentsOf: u, encoding: .utf8) else { return }
                DispatchQueue.main.async { self.loadText(content) }
            }
            return true
        }

        return false
    }

    private func convertAndSave() {
        if speechManager.isPlaying {
            speechManager.togglePreview(text: previewText)
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Audio]
        panel.nameFieldStringValue = "output.m4a"
        panel.title = "Save Audio File"
        panel.prompt = "Save"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        exportedURL = nil
        statusMessage = "Ready"

        exporter.export(
            text: text,
            speed: speechManager.selectedSpeed,
            to: url
        ) { result in
            isExporting = false
            switch result {
            case .success(let savedURL):
                exportedURL = savedURL
                statusMessage = "Saved to \(savedURL.path)"
            case .failure(let error):
                exportedURL = nil
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
