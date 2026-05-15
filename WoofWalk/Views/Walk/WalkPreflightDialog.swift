import SwiftUI
import UIKit

/// Sheet shown when `WalkPreflightChecker.check()` returns blockers or
/// warnings. Mirrors Android `app/src/main/java/com/woofwalk/ui/walk/
/// WalkPreflightDialog.kt`: blockers are unsurmountable from the dialog
/// and route the user out to system Settings; warnings ship with a
/// "Walk anyway" override that records the user's acceptance and
/// proceeds.
struct WalkPreflightDialog: View {
    let check: WalkPreflightCheck

    /// Tapped when the user wants to ignore warnings and proceed. Only
    /// enabled when `check.canStart == true`.
    let onWalkAnyway: () -> Void

    /// Tapped on close / cancel / X. Always available.
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 20)
                .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !check.blockers.isEmpty {
                        section(title: "Before you start") {
                            ForEach(check.blockers, id: \.self) { blocker in
                                row(
                                    icon: blocker.systemImage,
                                    title: blocker.title,
                                    message: blocker.message,
                                    tint: .red
                                )
                            }
                        }
                    }

                    if !check.warnings.isEmpty {
                        section(title: check.blockers.isEmpty ? "Heads up" : "Other things to know") {
                            ForEach(check.warnings, id: \.self) { warning in
                                row(
                                    icon: warning.systemImage,
                                    title: warning.title,
                                    message: warning.message,
                                    tint: .orange
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }

            actionBar
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(check.canStart ? "Ready to walk?" : "Can't start walk yet")
                    .font(.title2.bold())
                Text(check.canStart
                     ? "A few things you might want to check first."
                     : "Fix the items below to get going.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Close")
        }
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            if !check.blockers.isEmpty {
                Button {
                    openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Open Settings")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            if check.canStart {
                Button(action: onWalkAnyway) {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text(check.warnings.isEmpty ? "Start walk" : "Walk anyway")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(check.warnings.isEmpty ? Color.accentColor : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            Button(action: onDismiss) {
                Text("Cancel")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    private func row(icon: String, title: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(tint)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.08))
        )
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
