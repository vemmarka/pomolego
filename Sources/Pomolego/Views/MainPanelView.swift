import SwiftUI

/// Content of the menu bar popover: world, design picker, timer controls.
struct MainPanelView: View {
    @EnvironmentObject var state: AppState
    @State private var showAbandonConfirmation = false
    @State private var customMinutesText = ""

    /// Set by the AppKit layer so panel buttons can open windows/menus.
    var openStatistics: () -> Void = {}
    var openSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            header
            WorldView()
            if let unlocked = state.unlockAnnouncement {
                unlockBanner(unlocked)
            }
            phaseControls
        }
        .padding(12)
        .frame(width: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Pomolego")
                .font(.headline)
            Spacer()
            Button(action: openStatistics) {
                Image(systemName: "chart.bar.xaxis")
            }
            .buttonStyle(.borderless)
            .help("Statistics")
            .accessibilityLabel("Statistics")
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Pomolego")
            .accessibilityLabel("Quit")
        }
    }

    private func unlockBanner(_ design: BlockDesign) -> some View {
        HStack(spacing: 8) {
            BlockSwatch(design: design)
                .frame(width: 28, height: 22)
            Text("New design unlocked: \(design.name)!")
                .font(.callout.bold())
            Spacer()
            Button {
                state.unlockAnnouncement = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss unlock notice")
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Phase-dependent controls

    @ViewBuilder
    private var phaseControls: some View {
        switch state.phase {
        case .idle:
            idleControls
        case .focusRunning, .focusPaused:
            focusControls
        case .breakPrompt(let kind):
            breakPrompt(kind)
        case .breakRunning(let kind, _), .breakPaused(let kind, _):
            breakControls(kind)
        }
    }

    private var idleControls: some View {
        VStack(spacing: 10) {
            DesignPickerView()

            HStack(spacing: 6) {
                ForEach([15, 25, 45, 60], id: \.self) { preset in
                    Button("\(preset)") { state.focusMinutes = preset }
                        .buttonStyle(.bordered)
                        .tint(state.focusMinutes == preset ? .accentColor : nil)
                        .accessibilityLabel("\(preset) minutes")
                }
                Stepper(value: $state.focusMinutes, in: 1...180) {
                    TextField("min", text: $customMinutesText)
                        .frame(width: 36)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if let minutes = Int(customMinutesText) {
                                state.focusMinutes = min(180, max(1, minutes))
                            }
                            customMinutesText = "\(state.focusMinutes)"
                        }
                }
                .accessibilityLabel("Focus duration, \(state.focusMinutes) minutes")
                Text("min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear { customMinutesText = "\(state.focusMinutes)" }
            .onChange(of: state.focusMinutes) { _, newValue in
                customMinutesText = "\(newValue)"
            }

            Text(state.targetCell != nil
                 ? "Building on the marked spot — tap the world to move it"
                 : "Tap a highlighted cell to choose where your block goes")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                state.startFocus()
            } label: {
                Label("Start \(state.focusMinutes) min focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var focusControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                BlockSwatch(design: state.currentDesign)
                    .frame(width: 28, height: 22)
                Text(state.remaining.countdownString)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel("Time remaining \(state.remaining.countdownString)")
                if case .focusPaused = state.phase {
                    Text("paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Building a \(state.currentDesign.name) block — tap the world to move the spot")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if case .focusPaused = state.phase {
                    Button {
                        state.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        state.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                Button(role: .destructive) {
                    showAbandonConfirmation = true
                } label: {
                    Label("Abandon", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
        }
        .confirmationDialog("Abandon this session?",
                            isPresented: $showAbandonConfirmation) {
            Button("Abandon session", role: .destructive) {
                state.abandonFocus()
            }
            Button("Keep focusing", role: .cancel) {}
        } message: {
            Text(AppSettings.crackedBlockOnAbandon
                 ? "A cracked gray block will be placed where your block would have gone."
                 : "The session will end without building a block.")
        }
    }

    private func breakPrompt(_ kind: BreakKind) -> some View {
        let minutes = kind == .long ? AppSettings.longBreakMinutes : AppSettings.shortBreakMinutes
        return VStack(spacing: 10) {
            Text(kind == .long ? "Time for a long break" : "Block built! Take a short break?")
                .font(.title3.bold())
            Text("\(minutes) minutes")
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    state.startBreak()
                } label: {
                    Label("Start break", systemImage: "cup.and.saucer.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    state.skipBreak()
                } label: {
                    Text("Skip break")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
        }
    }

    private func breakControls(_ kind: BreakKind) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(state.remaining.countdownString)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if case .breakPaused = state.phase {
                    Text("paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(kind == .long ? "Long break" : "Short break")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if case .breakPaused = state.phase {
                    Button {
                        state.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        state.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                Button {
                    state.endBreakEarly()
                } label: {
                    Text("End break")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
        }
    }
}
