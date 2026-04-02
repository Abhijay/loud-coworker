import SwiftUI

struct VolumeChartView: View {
    let history: [HistorySample]

    private let chartHeight: CGFloat = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: chartHeight)

                // Chart content
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height

                    let (minDb, maxDb) = dbRange()

                    // Baseline area fill
                    baselinePath(in: width, height: height, minDb: minDb, maxDb: maxDb)
                        .fill(Color.blue.opacity(0.1))

                    // Baseline line
                    baselinePath(in: width, height: height, minDb: minDb, maxDb: maxDb)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1)

                    // Volume line
                    volumePath(in: width, height: height, minDb: minDb, maxDb: maxDb)
                        .stroke(volumeGradient, lineWidth: 1.5)
                }
                .frame(height: chartHeight)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)

                // Y-axis labels
                yAxisLabels
            }
            .frame(height: chartHeight)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.green)
                        .frame(width: 12, height: 2)
                    Text("Volume")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: 12, height: 2)
                    Text("Ambient")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var volumeGradient: LinearGradient {
        LinearGradient(
            colors: [.green, .yellow, .orange, .red],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func dbRange() -> (Float, Float) {
        guard !history.isEmpty else { return (-80, 0) }
        let allLevels = history.flatMap { [$0.level, $0.baseline] }
        let minVal = (allLevels.min() ?? -80) - 5
        let maxVal = max((allLevels.max() ?? 0) + 5, minVal + 20)
        return (minVal, maxVal)
    }

    private func yForDb(_ db: Float, height: CGFloat, minDb: Float, maxDb: Float) -> CGFloat {
        let normalized = CGFloat((db - minDb) / (maxDb - minDb))
        return height * (1 - normalized)
    }

    private func volumePath(in width: CGFloat, height: CGFloat, minDb: Float, maxDb: Float) -> Path {
        linePath(in: width, height: height, minDb: minDb, maxDb: maxDb) { $0.level }
    }

    private func baselinePath(in width: CGFloat, height: CGFloat, minDb: Float, maxDb: Float) -> Path {
        linePath(in: width, height: height, minDb: minDb, maxDb: maxDb) { $0.baseline }
    }

    private func linePath(in width: CGFloat, height: CGFloat, minDb: Float, maxDb: Float, value: (HistorySample) -> Float) -> Path {
        Path { path in
            guard history.count > 1 else { return }
            let step = width / CGFloat(AudioManager.maxHistory - 1)

            for (i, sample) in history.enumerated() {
                let x = CGFloat(i) * step
                let y = yForDb(value(sample), height: height, minDb: minDb, maxDb: maxDb)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private var yAxisLabels: some View {
        let (minDb, maxDb) = dbRange()
        let mid = (minDb + maxDb) / 2

        return GeometryReader { geo in
            let height = geo.size.height

            Text(String(format: "%.0f", maxDb))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .position(x: 16, y: 8)

            Text(String(format: "%.0f", mid))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .position(x: 16, y: height / 2)

            Text(String(format: "%.0f", minDb))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .position(x: 16, y: height - 8)
        }
    }
}
