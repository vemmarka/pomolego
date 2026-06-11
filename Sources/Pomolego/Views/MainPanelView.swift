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
        VStack(spacing: 12) {
            header
            WorldView()
            if let unlocked = state.unlockAnnouncement {
                unlockBanner(unlocked)
            }
            Divider()
            phaseControls
        }
        .padding(16)
        .frame(width: 392)
        .tint(Color.appAccent)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Text("Pomolego")
                .font(.headline)
            Spacer()
            Button(action: openStatistics) {
                Image(systemName: "chart.bar.xaxis")
            }
            .help("Statistics")
            .accessibilityLabel("Statistics")
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .help("Settings")
            .accessibilityLabel("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit Pomolego")
            .accessibilityLabel("Quit")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }

    private func unlockBanner(_ design: BlockDesign) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.appAccent)
            BlockSwatch(design: design)
                .frame(width: 26, height: 20)
            Text("New design unlocked: **\(design.name)**")
                .font(.callout)
            Spacer()
            Button {
                state.unlockAnnouncement = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss unlock notice")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        VStack(spacing: 12) {
            DesignPickerView()

            HStack(spacing: 6) {
                ForEach([15, 25, 45, 60], id: \.self) { preset in
                    presetPill(preset)
                }
                Spacer()
                TextField("min", text: $customMinutesText)
                    .frame(width: 34)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { applyCustomMinutes() }
                Stepper("", value: $state.focusMinutes, in: 1...180)
                    .labelsHidden()
                    .accessibilityLabel("Focus duration, \(state.focusMinutes) minutes")
                Text("min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .onAppear { customMinutesText = "\(state.focusMinutes)" }
            .onChange(of: state.focusMinutes) { _, newValue in
                customMinutesText = "\(newValue)"
            }

            Text(state.targetCell != nil
                 ? "Building on the marked spot — click the world to move it"
                 : "Click a highlighted cell to choose where your block goes")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Button {
                applyCustomMinutes()
                state.startFocus()
            } label: {
                Label("Start \(state.focusMinutes)-Minute Focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func presetPill(_ minutes: Int) -> some View {
        let selected = state.focusMinutes == minutes
        return Button {
            state.focusMinutes = minutes
        } label: {
            Text("\(minutes)")
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(selected
                            ? AnyShapeStyle(Color.appAccent.opacity(0.18))
                            : AnyShapeStyle(.quaternary.opacity(0.5)),
                            in: Capsule())
                .foregroundStyle(selected ? Color.appAccent : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes) minutes")
    }

    private func applyCustomMinutes() {
        if let minutes = Int(customMinutesText) {
            state.focusMinutes = min(180, max(1, minutes))
        }
        customMinutesText = "\(state.focusMinutes)"
    }

    private var focusControls: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                HStack(spacing: 10) {
                    BlockSwatch(design: state.currentDesign)
                        .frame(width: 28, height: 22)
                    Text(state.remaining.countdownString)
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("Time remaining \(state.remaining.countdownString)")
                }
                Text(focusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
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
                    .buttonStyle(.bordered)
                }
                Button(role: .destructive) {
                    showAbandonConfirmation = true
                } label: {
                    Label("Abandon", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .confirmationDialog("Abandon this session?",
                            isPresented: $showAbandonConfirmation) {
            Button("Abandon Session", role: .destructive) {
                state.abandonFocus()
            }
            Button("Keep Focusing", role: .cancel) {}
        } message: {
            Text(AppSettings.crackedBlockOnAbandon
                 ? "A cracked gray block will be placed where your block would have gone."
                 : "The session will end without building a block.")
        }
    }

    private var focusSubtitle: String {
        if case .focusPaused = state.phase {
            return "Paused — \(state.currentDesign.name) block in progress"
        }
        return "Building a \(state.currentDesign.name) block"
    }

    private func breakPrompt(_ kind: BreakKind) -> some View {
        let minutes = kind == .long ? AppSettings.longBreakMinutes : AppSettings.shortBreakMinutes
        return VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(kind == .long ? "Time for a Long Break" : "Block Built!")
                    .font(.title3.weight(.semibold))
                Text(kind == .long
                     ? "\(minutes) minutes — you've earned it"
                     : "Take a \(minutes)-minute break?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button {
                    state.startBreak()
                } label: {
                    Label("Start Break", systemImage: "cup.and.saucer.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    state.skipBreak()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    private func breakControls(_ kind: BreakKind) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                HStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(state.remaining.countdownString)
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
                Text(breakSubtitle(kind))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
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
                    .buttonStyle(.bordered)
                }
                Button {
                    state.endBreakEarly()
                } label: {
                    Text("End Break")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    private func breakSubtitle(_ kind: BreakKind) -> String {
        let name = kind == .long ? "Long break" : "Short break"
        if case .breakPaused = state.phase { return "\(name) — paused" }
        return name
    }
}
