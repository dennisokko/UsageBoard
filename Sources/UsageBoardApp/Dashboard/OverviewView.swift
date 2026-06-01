import AppKit
import SwiftUI
import UsageBoardCore

// MARK: - Environment Key

private struct OpenSettingsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

struct OverviewView: View {
    @ObservedObject var store: UsageBoardStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                AppIconSquircle(size: 22)
                Text("UsageBoard")
                    .font(UB.Font.popoverTitle)
                    .tracking(-0.1)
                Spacer()
                Button {
                    store.refreshAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                SettingsButton(iconSize: 13, buttonSize: 24)
                QuitButton(language: store.activeLanguage, iconSize: 13, buttonSize: 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            DashboardView(store: store, mode: store.configuration.overviewDisplayMode)
        }
    }
}

struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    var iconSize: CGFloat = 13
    var buttonSize: CGFloat = 24

    var body: some View {
        Button {
            openSettings()
        } label: {
            Image(systemName: "gear")
                .font(.system(size: iconSize, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.borderless)
    }
}

struct QuitButton: View {
    var language: AppLanguage = .zhHans
    var iconSize: CGFloat = 13
    var buttonSize: CGFloat = 24
    private var strings: AppLocalization {
        .shared
    }

    var body: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Image(systemName: "power")
                .font(.system(size: iconSize, weight: .medium))
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.borderless)
        .help(strings.text(.quitUsageBoard))
    }
}
