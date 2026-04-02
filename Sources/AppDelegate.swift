import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var floatingPanel: NSPanel!
    private let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "Loud Coworker"
            )
            button.action = #selector(togglePanel)
            button.target = self
        }

        let contentView = VolumeView(audioManager: audioManager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 260, height: 360)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 360),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.title = "Loud Coworker"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 276 - 16
            let y = screenFrame.maxY - 376 - 16
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.floatingPanel = panel

        audioManager.requestPermissionAndStart()

        audioManager.$relativeLevel
            .combineLatest(audioManager.$category, audioManager.$isSpeaking, audioManager.$isCalibrating)
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] level, category, speaking, calibrating in
                if calibrating {
                    self?.showCalibratingIcon()
                } else {
                    self?.updateStatusBar(level: level, category: category, speaking: speaking)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func togglePanel() {
        if floatingPanel.isVisible {
            floatingPanel.orderOut(nil)
        } else {
            floatingPanel.orderFront(nil)
        }
    }

    private func updateStatusBar(level: Float, category: VolumeCategory, speaking: Bool) {
        guard let button = statusItem.button else { return }

        if !speaking {
            let image = NSImage(
                systemSymbolName: "speaker.wave.1",
                accessibilityDescription: "Loud Coworker"
            )
            image?.isTemplate = true
            button.image = image
            button.title = ""
            button.attributedTitle = NSAttributedString()
            return
        }

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

        let dbText = String(format: " +%.0f dB", level)
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

    private func showCalibratingIcon() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: "waveform",
            accessibilityDescription: "Calibrating"
        )
        image?.isTemplate = true
        button.image = image
        button.title = ""
        button.attributedTitle = NSAttributedString()
    }
}
