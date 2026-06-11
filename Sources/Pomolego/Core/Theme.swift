import SwiftUI

extension Color {
    /// App-wide accent: warm terracotta (a pomodoro is a tomato, after all).
    /// Applied via .tint() on every root view so no control falls back to
    /// the system blue.
    static let appAccent = Color(red: 0.80, green: 0.38, blue: 0.28)
}
