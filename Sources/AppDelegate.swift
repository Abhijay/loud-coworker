import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "Volume Monitor"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

        let contentView = VolumeView(audioManager: audioManager)
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover

        audioManager.requestPermissionAndStart()

        audioManager.$currentLevel
            .combineLatest(audioManager.$category)
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] level, category in
                self?.updateStatusBar(level: level, category: category)
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusBar(level: Float, category: VolumeCategory) {
        guard let button = statusItem.button else { return }

        let color: NSColor
        switch category {
        case .quiet: color = .systemGreen
        case .moderate: color = .systemYellow
        case .loud: color = .systemOrange
        case .tooLoud: color = .systemRed
        }

        let symbolName: String
        switch category {
        case .quiet: symbolName = "speaker.wave.1"
        case .moderate: symbolName = "speaker.wave.2"
        case .loud, .tooLoud: symbolName = "speaker.wave.3"
        }

        let dbText = String(format: " %.0f dB", level)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let textSize = (dbText as NSString).size(withAttributes: textAttrs)

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        guard let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig) else { return }
        let iconSize = symbolImage.size

        let padding: CGFloat = 4
        let totalWidth = iconSize.width + padding + textSize.width
        let totalHeight = max(iconSize.height, textSize.height)

        let tintedIcon = NSImage(size: iconSize, flipped: false) { rect in
            symbolImage.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }

        let composedImage = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            let iconY = (rect.height - iconSize.height) / 2
            tintedIcon.draw(
                in: NSRect(x: 0, y: iconY, width: iconSize.width, height: iconSize.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )

            let textY = (rect.height - textSize.height) / 2
            (dbText as NSString).draw(
                at: NSPoint(x: iconSize.width + padding, y: textY),
                withAttributes: textAttrs
            )
            return true
        }
        composedImage.isTemplate = false

        button.image = composedImage
        button.title = ""
        button.attributedTitle = NSAttributedString()
    }
}
