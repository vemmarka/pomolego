import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "timer") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
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
