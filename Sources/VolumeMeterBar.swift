import SwiftUI

struct VolumeMeterBar: View {
    let level: Float
    let peak: Float

    private let segmentCount = 30
    private let segmentSpacing: CGFloat = 2

    var body: some View {
        VStack(spacing: 6) {
            meterBar
            thresholdMarkers
        }
    }

    private var meterBar: some View {
        HStack(spacing: segmentSpacing) {
            ForEach(0..<segmentCount, id: \.self) { index in
                segmentView(at: index)
            }
        }
        .frame(height: 28)
        .animation(.easeOut(duration: 0.08), value: level)
    }

    private func segmentView(at index: Int) -> some View {
        let normalizedLevel = normalize(level)
        let normalizedPeak = normalize(peak)
        let segmentPosition = Float(index) / Float(segmentCount)

        let isLit = segmentPosition < normalizedLevel
        let isPeak = abs(segmentPosition - normalizedPeak) < (1.0 / Float(segmentCount))
        let color = segmentColor(at: Float(index) / Float(segmentCount))

        return RoundedRectangle(cornerRadius: 2)
            .fill(isLit ? color : (isPeak ? color.opacity(0.8) : color.opacity(0.12)))
    }

    private var thresholdMarkers: some View {
        GeometryReader { geo in
            let width = geo.size.width

            let quietPos = CGFloat(normalize(AudioManager.quietThreshold)) * width
            let moderatePos = CGFloat(normalize(AudioManager.moderateThreshold)) * width
            let loudPos = CGFloat(normalize(AudioManager.loudThreshold)) * width

            ZStack(alignment: .leading) {
                thresholdMark(at: quietPos, label: "-40")
                thresholdMark(at: moderatePos, label: "-20")
                thresholdMark(at: loudPos, label: "-10")
            }
        }
        .frame(height: 14)
    }

    private func thresholdMark(at x: CGFloat, label: String) -> some View {
        Text(label)
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.secondary)
            .position(x: x, y: 7)
    }

    private func normalize(_ db: Float) -> Float {
        let clamped = max(AudioManager.dbFloor, min(AudioManager.dbCeiling, db))
        return (clamped - AudioManager.dbFloor) / (AudioManager.dbCeiling - AudioManager.dbFloor)
    }

    private func segmentColor(at position: Float) -> Color {
        let quietNorm = normalize(AudioManager.quietThreshold)
        let moderateNorm = normalize(AudioManager.moderateThreshold)
        let loudNorm = normalize(AudioManager.loudThreshold)

        if position < quietNorm { return .green }
        if position < moderateNorm { return .yellow }
        if position < loudNorm { return .orange }
        return .red
    }
}
