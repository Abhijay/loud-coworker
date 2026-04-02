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

struct HistorySample: Identifiable {
    let id = UUID()
    let time: Date
    let level: Float
    let baseline: Float
}

final class AudioManager: ObservableObject {
    @Published var currentLevel: Float = -80
    @Published var relativeLevel: Float = 0
    @Published var peakLevel: Float = 0
    @Published var category: VolumeCategory = .quiet
    @Published var permissionDenied = false
    @Published var isMonitoring = false
    @Published var isSpeaking = false
    @Published var baselineLevel: Float = -80
    @Published var isCalibrating = true
    @Published var calibrationProgress: Double = 0
    @Published var history: [HistorySample] = []

    static let maxHistory = 120

    private var engine: AVAudioEngine?
    private var smoothedLevel: Float = -80
    private var chartLevel: Float = -80
    private var peakHoldTime: Date = .distantPast
    private var historyCounter = 0
    private let historyInterval = 20

    // Calibration
    private var calibrationSamples: [Float] = []
    private var calibrationStartTime: Date?
    private static let calibrationDuration: TimeInterval = 3.0

    private static let baselineAdaptRate: Float = 0.01

    // Thresholds as amplitude multipliers of baseline.
    // 3x louder to count as speaking, 10x = moderate, 30x = loud, 100x = too loud.
    // These convert to dB dynamically: threshold_dB = 20 * log10(multiplier)
    private static let speechMultiplier: Float = 1.78     // ~+5 dB
    private static let quietMultiplier: Float = 10       // ~+20 dB
    private static let moderateMultiplier: Float = 30    // ~+30 dB
    private static let loudMultiplier: Float = 100       // ~+40 dB

    // Converted to dB for display / meter use
    static var speechThresholdDb: Float { 20 * log10(speechMultiplier) }
    static var quietThresholdDb: Float { 20 * log10(quietMultiplier) }
    static var moderateThresholdDb: Float { 20 * log10(moderateMultiplier) }
    static var loudThresholdDb: Float { 20 * log10(loudMultiplier) }

    // Meter range
    static let relativeFloor: Float = 0
    static var relativeCeiling: Float { 20 * log10(loudMultiplier * 1.5) }

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )

        do {
            try engine.start()
            self.engine = engine
            DispatchQueue.main.async {
                self.isMonitoring = true
                self.beginCalibration()
            }
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    @objc private func handleConfigChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.restart()
        }
    }

    func restart() {
        stopMonitoring()
        requestPermissionAndStart()
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: engine)
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.currentLevel = -80
            self.relativeLevel = 0
            self.peakLevel = 0
            self.category = .quiet
            self.isSpeaking = false
        }
    }

    func recalibrate() {
        beginCalibration()
    }

    private func beginCalibration() {
        calibrationSamples = []
        calibrationStartTime = Date()
        isCalibrating = true
        calibrationProgress = 0
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
        let db = max(-80, 20 * log10(max(rms, 1e-10)))

        let alpha: Float = 0.3
        let smoothed = alpha * db + (1 - alpha) * smoothedLevel
        smoothedLevel = smoothed

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentLevel = smoothed

            if self.isCalibrating {
                self.handleCalibrationSample(smoothed)
                return
            }

            let aboveBaseline = smoothed - self.baselineLevel
            // Compare in linear amplitude space
            let amplitudeRatio = pow(10, aboveBaseline / 20)
            let speaking = amplitudeRatio >= Self.speechMultiplier

            if !speaking {
                self.baselineLevel += Self.baselineAdaptRate * (smoothed - self.baselineLevel)
            }

            let relative = max(0, aboveBaseline)
            self.relativeLevel = relative
            self.isSpeaking = speaking
            self.category = speaking ? Self.categorize(amplitudeRatio) : .quiet

            let now = Date()
            if relative > self.peakLevel || now.timeIntervalSince(self.peakHoldTime) > 2.0 {
                self.peakLevel = relative
                self.peakHoldTime = now
            }

            // Slow EMA for chart (alpha 0.08 = very smooth)
            self.chartLevel += 0.08 * (smoothed - self.chartLevel)

            self.historyCounter += 1
            if self.historyCounter >= self.historyInterval {
                self.historyCounter = 0
                self.history.append(HistorySample(
                    time: now,
                    level: self.chartLevel,
                    baseline: self.baselineLevel
                ))
                if self.history.count > Self.maxHistory {
                    self.history.removeFirst()
                }
            }
        }
    }

    private func handleCalibrationSample(_ level: Float) {
        calibrationSamples.append(level)

        guard let startTime = calibrationStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        calibrationProgress = min(elapsed / Self.calibrationDuration, 1.0)

        if elapsed >= Self.calibrationDuration {
            baselineLevel = smoothedLevel
            calibrationSamples = []
            calibrationStartTime = nil
            isCalibrating = false
            peakLevel = 0
            peakHoldTime = .distantPast
        }
    }

    private static func categorize(_ amplitudeRatio: Float) -> VolumeCategory {
        if amplitudeRatio >= loudMultiplier { return .tooLoud }
        if amplitudeRatio >= moderateMultiplier { return .loud }
        if amplitudeRatio >= quietMultiplier { return .moderate }
        return .quiet
    }
}
