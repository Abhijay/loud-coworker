import AVFoundation
import Combine

enum VolumeCategory {
    case quiet, moderate, loud, tooLoud

    var label: String {
        switch self {
        case .quiet: return "Quiet"
        case .moderate: return "Moderate"
        case .loud: return "Loud"
        case .tooLoud: return "Too Loud"
        }
    }
}

final class AudioManager: ObservableObject {
    @Published var currentLevel: Float = -80
    @Published var peakLevel: Float = -80
    @Published var category: VolumeCategory = .quiet
    @Published var permissionDenied = false
    @Published var isMonitoring = false

    private var engine: AVAudioEngine?
    private var smoothedLevel: Float = -80
    private var peakHoldTime: Date = .distantPast

    static let quietThreshold: Float = -40
    static let moderateThreshold: Float = -20
    static let loudThreshold: Float = -10
    static let dbFloor: Float = -80
    static let dbCeiling: Float = 0

    func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startMonitoring()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startMonitoring()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
            self.engine = engine
            DispatchQueue.main.async { self.isMonitoring = true }
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    func stopMonitoring() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.currentLevel = Self.dbFloor
            self.peakLevel = Self.dbFloor
            self.category = .quiet
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frames = Int(buffer.frameLength)
        let samples = channelData[0]

        var sumSquares: Float = 0
        for i in 0..<frames {
            let sample = samples[i]
            sumSquares += sample * sample
        }

        let rms = sqrt(sumSquares / Float(frames))
        let db = max(Self.dbFloor, 20 * log10(max(rms, 1e-10)))

        let alpha: Float = 0.3
        let smoothed = alpha * db + (1 - alpha) * smoothedLevel
        smoothedLevel = smoothed

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentLevel = smoothed
            self.category = Self.categorize(smoothed)

            let now = Date()
            if smoothed > self.peakLevel || now.timeIntervalSince(self.peakHoldTime) > 1.5 {
                self.peakLevel = smoothed
                self.peakHoldTime = now
            }
        }
    }

    private static func categorize(_ db: Float) -> VolumeCategory {
        if db >= loudThreshold { return .tooLoud }
        if db >= moderateThreshold { return .loud }
        if db >= quietThreshold { return .moderate }
        return .quiet
    }
}
