import SwiftUI

/// Root view that switches the entire tab container based on the current app mode.
///
/// When the user selects "Client" or "Business" in the AppModeSwitcher (on the Profile tab),
/// the `appMode` value in `@AppStorage` changes and this view swaps out the full tab bar
/// and screen set with a smooth cross-fade.
struct ModeAwareRootView: View {
    @AppStorage("appMode") private var appMode: String = "Public"

    var body: some View {
        Group {
            switch appMode {
            case "Client":
                ClientTabView()
            case "Business":
                BusinessTabView()
            default:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appMode)
        .transition(.opacity)
    }
}
