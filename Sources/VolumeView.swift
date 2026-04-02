import SwiftUI

struct VolumeView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        VStack(spacing: 16) {
            header
            dbDisplay
            VolumeMeterBar(level: audioManager.currentLevel, peak: audioManager.peakLevel)
            thresholdLegend
            peakDisplay
            statusLine
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("Volume Monitor")
                .font(.headline)
            Spacer()
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
    }

    private var dbDisplay: some View {
        Text(String(format: "%.1f dB", audioManager.currentLevel))
            .font(.system(size: 36, weight: .bold, design: .monospaced))
            .foregroundColor(colorForCategory(audioManager.category))
            .animation(.easeOut(duration: 0.1), value: audioManager.currentLevel)
    }

    private var thresholdLegend: some View {
        HStack(spacing: 12) {
            legendDot(color: .green, label: "Quiet")
            legendDot(color: .yellow, label: "Moderate")
            legendDot(color: .orange, label: "Loud")
            legendDot(color: .red, label: "Too Loud")
        }
        .font(.caption2)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    private var peakDisplay: some View {
        HStack {
            Text("Peak")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f dB", audioManager.peakLevel))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private var statusLine: some View {
        Group {
            if audioManager.permissionDenied {
                Label("Microphone access denied. Grant in System Settings > Privacy.", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(.red)
            } else if audioManager.isMonitoring {
                Label(audioManager.category.label, systemImage: "waveform")
                    .font(.caption)
                    .foregroundColor(colorForCategory(audioManager.category))
            } else {
                Label("Paused", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
