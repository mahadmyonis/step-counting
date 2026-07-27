import Foundation

/// The app's five top-level destinations.
enum RootTab: String, CaseIterable, Identifiable {
    case today, challenges, crews, stats, you

    var id: String { rawValue }
}

/// Runs the app against fabricated data instead of HealthKit.
///
/// Two jobs. It lets the screenshot workflow drive a fully populated app on a
/// clean simulator — no Health samples, no permission dialogs, no empty states —
/// and it's the same path App Store screenshots should be taken through, since
/// a real device's Tuesday rarely looks like the best version of the product.
///
/// Enabled only by a launch argument, so a shipped build can never enter it by
/// accident.
enum DemoMode {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoMode")
    }

    /// Which tab to open on launch, via `-demoTab crews`.
    ///
    /// Screenshotting this way means the workflow can capture every screen by
    /// relaunching the app, with no UI automation to write or maintain.
    static var initialTab: RootTab {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let index = arguments.firstIndex(of: "-demoTab"),
            index + 1 < arguments.count,
            let tab = RootTab(rawValue: arguments[index + 1].lowercased())
        else {
            return .today
        }
        return tab
    }
}
