import AppKit
import SwiftUI
import pinchkit

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: KeyablePanel!
    var statusItem: NSStatusItem!
    let gridModel = GridModel()

    // Pinch gestures walk one rung at a time on the ladder
    //   suparpad panel ⇄ normal ⇄ desktop shown
    // pinch-close climbs toward the panel, pinch-open descends to the desktop.
    var desktopShown = false
    var desktopToggledAt = Date.distantPast

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
        panel.level = .popUpMenu // above the menu bar and Dock, like real Launchpad
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        gridModel.load()
        print("scanned \(gridModel.apps.count) apps")
        panel.contentView = NSHostingView(rootView: LaunchGridView(
            model: gridModel,
            onLaunch: { [weak self] app in
                print("launch: \(app.name)")
                NSWorkspace.shared.openApplication(at: app.id, configuration: .init())
                self?.hidePanel()
            },
            onDismiss: { [weak self] in self?.hidePanel() }
        ))

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                // Mid-drag, Esc cancels the drag (un-hides the icon) and keeps
                // the panel open, rather than dismissing.
                if self?.gridModel.dragging != nil {
                    self?.gridModel.endDrag()
                } else {
                    self?.hidePanel()
                }
                return nil
            }
            if event.keyCode == 12, event.modifierFlags.contains(.command) { // ⌘Q
                NSApp.terminate(nil)
                return nil
            }
            return event
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "square.grid.3x3.fill",
            accessibilityDescription: "suparpad"
        )
        let menu = NSMenu()
        let show = NSMenuItem(title: "Show Launchpad", action: #selector(menuShowPanel), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit suparpad", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

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

    // The Mission Control call is a blind toggle, so a shadow flag alone
    // inverts forever after one missed event. Decide from observable reality:
    // during show-desktop all normal app windows are slid off-screen.
    private func normalWindowsVisible() -> Bool {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return true }

        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetActiveDisplayList(16, &ids, &count)
        let displays = (0..<Int(count)).map { CGDisplayBounds(ids[$0]).insetBy(dx: 40, dy: 40) }

        let myPID = Int32(ProcessInfo.processInfo.processIdentifier)
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != myPID,
                  let boundsDict = w[kCGWindowBounds as String],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary),
                  rect.width > 150, rect.height > 100
            else { continue }
            // Show-desktop parks windows just past the edge, sometimes with a
            // sliver still overlapping — require a substantial overlap area.
            for display in displays {
                let overlap = rect.intersection(display)
                if overlap.width > 200 && overlap.height > 150 {
                    let pid = w[kCGWindowOwnerPID as String] as? Int32 ?? -1
                    let owner = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
                    print("  windowsVisible=true: \(owner) \(Int(rect.width))x\(Int(rect.height)) at (\(Int(rect.minX)),\(Int(rect.minY)))")
                    return true
                }
            }
        }
        print("  windowsVisible=false")
        return false
    }

    // Window bounds lie while the show-desktop slide animates (and slivers
    // park on-screen), so for 2s after our own toggle trust what we did.
    private func desktopIsShown() -> Bool {
        if Date().timeIntervalSince(desktopToggledAt) < 2.0 { return desktopShown }
        return desktopShown && !normalWindowsVisible()
    }

    func pinchClose() {
        print("pinchClose: desktopShown=\(desktopShown) panelVisible=\(panel.isVisible)")
        if desktopIsShown() {
            print("pinch-close → restore windows")
            desktopShown = false
            toggleShowDesktop()
        } else {
            desktopShown = false // resync if the flag went stale
            showPanel()
        }
    }

    @objc private func menuShowPanel() { showPanel() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    func showPanel() {
        guard !panel.isVisible else { return }
        gridModel.endDrag() // backstop: never open with an icon left hidden
        // Appear on the screen the cursor is on, like real Launchpad.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        if let frame = screen?.frame, panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
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
        print("pinchOpen: desktopShown=\(desktopShown) panelVisible=\(panel.isVisible)")
        if panel.isVisible {
            hidePanel()
        } else if desktopIsShown() {
            print("pinch-open → desktop already shown; nothing to do")
        } else if normalWindowsVisible() {
            print("pinch-open → show desktop")
            desktopShown = true
            toggleShowDesktop()
        } else {
            print("pinch-open → no windows on screen; nothing to do")
        }
    }

    private func toggleShowDesktop() {
        desktopToggledAt = Date()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", "Mission Control", "--args", "1"]
        try? p.run()
    }
}
