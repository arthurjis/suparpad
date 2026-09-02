import AppKit
import SwiftUI
import pinchkit

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: KeyablePanel!

    // C-compatible callback: runs on a MultitouchSupport background thread.
    // Must not touch main-actor state directly — hop to main first.
    private static let pinchHandler: @convention(c) (Int32) -> Void = { isOpen in
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let delegate = NSApp.delegate as? AppDelegate else { return }
                if isOpen == 0 { delegate.showPanel() } else { delegate.pinchOpen() }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 1440, height: 900)
        panel = KeyablePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let apps = AppScanner.scan()
        print("scanned \(apps.count) apps")
        panel.contentView = NSHostingView(rootView: LaunchGridView(
            apps: apps,
            onLaunch: { [weak self] app in
                print("launch: \(app.name)")
                NSWorkspace.shared.openApplication(at: app.id, configuration: .init())
                self?.hidePanel()
            },
            onDismiss: { [weak self] in self?.hidePanel() }
        ))

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.hidePanel()
                return nil
            }
            if event.keyCode == 12, event.modifierFlags.contains(.command) { // ⌘Q
                NSApp.terminate(nil)
                return nil
            }
            return event
        }

        let devices = pinchkit_start(Self.pinchHandler)
        print(devices > 0
            ? "pinchkit: watching \(devices) trackpad(s) — pinch-close to summon"
            : "pinchkit: NO devices (\(devices)) — pinch disabled; --show still works")

        if CommandLine.arguments.contains("--show") { showPanel() }
    }

    func showPanel() {
        guard !panel.isVisible else { return }
        print("pinch-close → show panel")
        // Nonactivating panel: takes key status for Esc without deactivating
        // the frontmost app, so focus returns to it on dismiss.
        panel.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        guard panel.isVisible else { return }
        print("→ hide panel")
        panel.orderOut(nil)
    }

    // Pinch-open dismisses the panel, or — restoring the pre-Tahoe gesture —
    // toggles Show Desktop when the panel isn't up.
    func pinchOpen() {
        if panel.isVisible {
            hidePanel()
        } else {
            print("pinch-open → toggle show desktop")
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-a", "Mission Control", "--args", "1"]
            try? p.run()
        }
    }
}
