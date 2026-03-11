import SwiftUI

@main
struct SpokeApp: App {
    var body: some Scene {
        WindowGroup("Spoke") {
            ContentView()
                .background(WindowAccessor())
        }
        .defaultSize(width: 600, height: 600)
        .windowResizability(.contentMinSize)
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
