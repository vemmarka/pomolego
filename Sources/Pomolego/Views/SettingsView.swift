import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "timer") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            BackupTab()
                .tabItem { Label("Backup", systemImage: "arrow.up.arrow.down.circle") }
            DangerZoneTab()
                .tabItem { Label("Danger Zone", systemImage: "exclamationmark.triangle") }
        }
        .frame(width: 420)
        .tint(Color.appAccent)
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.focusMinutesKey) private var focusMinutes = 25
    @AppStorage(AppSettings.shortBreakMinutesKey) private var shortBreak = 5
    @AppStorage(AppSettings.longBreakMinutesKey) private var longBreak = 20
    @AppStorage(AppSettings.sessionsBeforeLongBreakKey) private var sessionsBeforeLong = 4
    @AppStorage(AppSettings.idleResetMinutesKey) private var idleResetMinutes = 120
    @AppStorage(AppSettings.autoStartBreaksKey) private var autoStartBreaks = false
    @AppStorage(AppSettings.autoStartNextFocusKey) private var autoStartNextFocus = false

    var body: some View {
        Form {
            Section("Durations") {
                Stepper(value: $focusMinutes, in: 5...180) {
                    labeledValue("Focus", "\(focusMinutes) min")
                }
                Stepper(value: $shortBreak, in: 1...60) {
                    labeledValue("Short break", "\(shortBreak) min")
                }
                Stepper(value: $longBreak, in: 1...120) {
                    labeledValue("Long break", "\(longBreak) min")
                }
                Stepper(value: $sessionsBeforeLong, in: 2...12) {
                    labeledValue("Sessions before long break", "\(sessionsBeforeLong)")
                }
            }
            Section("Flow") {
                Toggle("Auto-start breaks", isOn: $autoStartBreaks)
                Toggle("Auto-start next focus session after a break",
                       isOn: $autoStartNextFocus)
                Stepper(value: $idleResetMinutes, in: 15...480, step: 15) {
                    labeledValue("Reset session cycle after idle",
                                 idleResetLabel)
                }
                Text("After this much time without a session, the long-break counter starts over.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }

    private var idleResetLabel: String {
        let hours = idleResetMinutes / 60
        let minutes = idleResetMinutes % 60
        if minutes == 0 { return "\(hours) h" }
        if hours == 0 { return "\(minutes) min" }
        return "\(hours) h \(minutes) min"
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

private struct AppearanceSettingsTab: View {
    @AppStorage(AppSettings.animationPositionKey)
    private var animationPosition = AnimationPosition.nearMenuBarIcon.rawValue
    @AppStorage(AppSettings.menuBarShowsCountdownKey) private var showsCountdown = true
    @AppStorage(AppSettings.crackedBlockOnAbandonKey) private var crackedOnAbandon = true
    @State private var launchAtLogin = AppSettings.launchAtLogin

    var body: some View {
        Form {
            Section("Completion animation") {
                Picker("Position", selection: $animationPosition) {
                    ForEach(AnimationPosition.allCases) { position in
                        Text(position.label).tag(position.rawValue)
                    }
                }
                Text("The animation is always silent and never steals focus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Menu bar") {
                Picker("Display", selection: $showsCountdown) {
                    Text("Countdown and glyph").tag(true)
                    Text("Glyph only").tag(false)
                }
            }
            Section("Consequences") {
                Toggle("Place a cracked block when a session is abandoned",
                       isOn: $crackedOnAbandon)
            }
            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        AppSettings.setLaunchAtLogin(newValue)
                        launchAtLogin = AppSettings.launchAtLogin
                    }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}

private struct BackupTab: View {
    @EnvironmentObject var state: AppState
    @State private var pendingImport: Data?
    @State private var confirmingImport = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("Backup") {
                Text("Your worlds and statistics are stored only on this Mac. Export a backup file to keep them safe — or to move them to another Mac or the Pomolego website.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Export Backup…") { exportBackup() }
                    Button("Import Backup…") { importBackup() }
                }
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .confirmationDialog("Import this backup?", isPresented: $confirmingImport) {
            Button("Replace & Import", role: .destructive) {
                if let data = pendingImport, state.importBackup(from: data) {
                    message = "Backup imported."
                } else {
                    message = "Could not import that file."
                }
                pendingImport = nil
            }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text("This replaces your current world and statistics with the backup's. Consider exporting first.")
        }
    }

    private func exportBackup() {
        guard let data = state.exportBackupData() else { message = "Nothing to export."; return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        panel.nameFieldStringValue = "pomolego-backup-\(stamp).json"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
            message = "Backup exported."
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            pendingImport = data
            confirmingImport = true
        }
    }
}

private struct DangerZoneTab: View {
    @EnvironmentObject var state: AppState
    @State private var confirmingFreshCanvas = false

    var body: some View {
        Form {
            Section("Fresh canvas") {
                Text("Archives the current world and starts an empty one. Statistics keep the full history; the archived world cannot be re-opened in v1.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Start a fresh canvas…", role: .destructive) {
                    confirmingFreshCanvas = true
                }
                .disabled(state.world.blocks.isEmpty)
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .confirmationDialog("Start a fresh canvas?",
                            isPresented: $confirmingFreshCanvas) {
            Button("Archive world and start fresh", role: .destructive) {
                state.startFreshCanvas()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current world (\(state.world.blocks.count) blocks) will be archived. This cannot be undone from the app.")
        }
    }
}
