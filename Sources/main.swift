import AppKit
import SwiftUI

@main
struct VolumeControlApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
