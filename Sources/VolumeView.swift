import SwiftUI

struct VolumeView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        VStack(spacing: 6) {
            if audioManager.isCalibrating {
                calibrationView
            } else {
                dbDisplay
                VolumeMeterBar(level: audioManager.relativeLevel, peak: audioManager.peakLevel)
                VolumeChartView(history: audioManager.history)
                bottomRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .frame(width: 260, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(nil, value: audioManager.isSpeaking)
        .animation(nil, value: audioManager.relativeLevel)
        .animation(nil, value: audioManager.isCalibrating)
    }

    private var calibrationView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Sampling ambient noise...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text("Stay quiet")
                .font(.caption)
                .foregroundColor(.secondary)
            ProgressView(value: audioManager.calibrationProgress)
                .tint(.accentColor)
            Spacer()
        }
    }

    private var dbDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(audioManager.isSpeaking
                 ? String(format: "+%.0f dB", audioManager.relativeLevel)
                 : "--")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(audioManager.isSpeaking
                                 ? colorForCategory(audioManager.category)
                                 : .secondary)
            Spacer()
            Text(audioManager.isSpeaking ? audioManager.category.label : "not speaking")
                .font(.caption)
                .foregroundColor(audioManager.isSpeaking
                                 ? colorForCategory(audioManager.category)
                                 : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            Text(String(format: "Peak +%.0f", audioManager.peakLevel))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            Text(String(format: "Amb %.0f", audioManager.baselineLevel))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { audioManager.recalibrate() }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Recalibrate")
            Button(action: {
                if audioManager.isMonitoring {
                    audioManager.stopMonitoring()
                } else {
                    audioManager.requestPermissionAndStart()
                }
            }) {
                Image(systemName: audioManager.isMonitoring ? "mic.fill" : "mic.slash.fill")
                    .foregroundColor(audioManager.isMonitoring ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(audioManager.isMonitoring ? "Stop monitoring" : "Start monitoring")
        }
        .frame(height: 16)
    }

    private func colorForCategory(_ category: VolumeCategory) -> Color {
        switch category {
        case .quiet: return .green
        case .moderate: return .yellow
        case .loud: return .orange
        case .tooLoud: return .red
        }
    }
}
