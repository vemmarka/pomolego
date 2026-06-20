import Foundation
import ServiceManagement

enum AnimationPosition: String, CaseIterable, Identifiable {
    case nearMenuBarIcon
    case centerOfScreen
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nearMenuBarIcon: return "Near menu bar icon"
        case .centerOfScreen: return "Center of screen"
        case .off: return "Off"
        }
    }
}

/// UserDefaults-backed settings. Views bind via @AppStorage with the same
/// keys; non-view code reads through this type.
enum AppSettings {
    static let focusMinutesKey = "focusMinutes"
    static let shortBreakMinutesKey = "shortBreakMinutes"
    static let longBreakMinutesKey = "longBreakMinutes"
    static let sessionsBeforeLongBreakKey = "sessionsBeforeLongBreak"
    static let idleResetMinutesKey = "idleResetMinutes"
    static let autoStartBreaksKey = "autoStartBreaks"
    static let autoStartNextFocusKey = "autoStartNextFocus"
    static let animationPositionKey = "animationPosition"
    static let menuBarShowsCountdownKey = "menuBarShowsCountdown"
    static let crackedBlockOnAbandonKey = "crackedBlockOnAbandon"
    static let selectedDesignIDKey = "selectedDesignID"
    static let customDurationsKey = "customDurations"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            focusMinutesKey: 25,
            shortBreakMinutesKey: 5,
            longBreakMinutesKey: 20,
            sessionsBeforeLongBreakKey: 4,
            idleResetMinutesKey: 120,
            autoStartBreaksKey: false,
            autoStartNextFocusKey: false,
            animationPositionKey: AnimationPosition.nearMenuBarIcon.rawValue,
            menuBarShowsCountdownKey: true,
            crackedBlockOnAbandonKey: true,
            selectedDesignIDKey: "brick",
        ])
    }

    private static var defaults: UserDefaults { .standard }

    static var focusMinutes: Int {
        get { defaults.integer(forKey: focusMinutesKey) }
        set { defaults.set(newValue, forKey: focusMinutesKey) }
    }
    static var shortBreakMinutes: Int { defaults.integer(forKey: shortBreakMinutesKey) }
    static var longBreakMinutes: Int { defaults.integer(forKey: longBreakMinutesKey) }
    static var sessionsBeforeLongBreak: Int { defaults.integer(forKey: sessionsBeforeLongBreakKey) }
    static var idleResetMinutes: Int { defaults.integer(forKey: idleResetMinutesKey) }
    static var autoStartBreaks: Bool { defaults.bool(forKey: autoStartBreaksKey) }
    static var autoStartNextFocus: Bool { defaults.bool(forKey: autoStartNextFocusKey) }
    static var menuBarShowsCountdown: Bool { defaults.bool(forKey: menuBarShowsCountdownKey) }
    static var crackedBlockOnAbandon: Bool { defaults.bool(forKey: crackedBlockOnAbandonKey) }

    static var animationPosition: AnimationPosition {
        AnimationPosition(rawValue: defaults.string(forKey: animationPositionKey) ?? "")
            ?? .nearMenuBarIcon
    }

    static var selectedDesignID: String {
        get { defaults.string(forKey: selectedDesignIDKey) ?? "brick" }
        set { defaults.set(newValue, forKey: selectedDesignIDKey) }
    }

    static var customDurations: [Int] {
        get { (defaults.array(forKey: customDurationsKey) as? [Int]) ?? [] }
        set { defaults.set(newValue, forKey: customDurationsKey) }
    }

    static var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login change failed: \(error)")
        }
    }
}
