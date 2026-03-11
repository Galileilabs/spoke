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
    func makeNSView(context: Context) -> WindowObserverView {
        let view = WindowObserverView()
        return view
    }

    func updateNSView(_ nsView: WindowObserverView, context: Context) {}

    class WindowObserverView: NSView {
        private var observation: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window = window else { return }
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
        }
    }
}
