import SwiftUI
import UIKit

/// SwiftUI wrapper around `UIActivityViewController` for share flows.
/// Single canonical definition — previously duplicated inline in
/// `WalkDetailView.swift` (with parameter label `items:`) and in
/// `CommunityPostDetailScreen.swift` (with `activityItems:`), which
/// caused Release-mode Swift to fail with both "invalid redeclaration"
/// and "incorrect argument label" errors at the call sites because the
/// two definitions disagreed on the public API. Centralised here
/// 2026-05-15 with the `activityItems:` label to match
/// `UIActivityViewController`'s own initialiser, then all 7 call sites
/// updated.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
