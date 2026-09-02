import AppKit
import SwiftUI
import pinchkit

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: KeyablePanel!

    // Pinch gestures walk one rung at a time on the ladder
    //   suparpad panel ⇄ normal ⇄ desktop shown
    // pinch-close climbs toward the panel, pinch-open descends to the desktop.
    var desktopShown = false

    // C-compatible callback: runs on a MultitouchSupport background thread.
    // Must not touch main-actor state directly — hop to main first.
    private static let pinchHandler: @convention(c) (Int32) -> Void = { isOpen in
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let delegate = NSApp.delegate as? AppDelegate else { return }
                if isOpen == 0 { delegate.pinchClose() } else { delegate.pinchOpen() }
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

        // Leaving show-desktop any other way (clicking a window, F11, hot
        // corner) activates some app — clear the flag so pinch-close goes back
        // to summoning the panel instead of un-toggling a desktop that isn't
        // shown. Mission Control's own activation (fired by our toggle) is
        // ignored.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.bundleIdentifier == "com.apple.exposelauncher" { return }
            MainActor.assumeIsolated {
                (NSApp.delegate as? AppDelegate)?.desktopShown = false
            }
        }

        let devices = pinchkit_start(Self.pinchHandler)
        print(devices > 0
            ? "pinchkit: watching \(devices) trackpad(s) — pinch-close to summon"
            : "pinchkit: NO devices (\(devices)) — pinch disabled; --show still works")

        if CommandLine.arguments.contains("--show") { showPanel() }
    }

    func pinchClose() {
        if desktopShown {
            print("pinch-close → restore windows")
            desktopShown = false
            toggleShowDesktop()
        } else {
            showPanel()
        }
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
    // shows the desktop when the panel isn't visible.
    func pinchOpen() {
        if panel.isVisible {
            hidePanel()
        } else if !desktopShown {
            print("pinch-open → show desktop")
            desktopShown = true
            toggleShowDesktop()
        }
    }

    private func toggleShowDesktop() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", "Mission Control", "--args", "1"]
        try? p.run()
    }
}
