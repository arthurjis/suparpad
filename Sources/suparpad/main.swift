import AppKit
import Darwin

setlinebuf(stdout) // keep prints visible when stdout is a pipe (background runs)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon; panel appears on demand
app.run()
