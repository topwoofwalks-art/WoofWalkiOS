import SwiftUI

struct BusinessWelcomeDialog: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenBusinessWelcome") var hasSeenWelcome: Bool = false
    @State private var dontShowAgain = false

    private let cardBackground = Color.neutral20
    private let tealAccent = Color(red: 0.6, green: 0.9, blue: 0.9)
    private let darkTeal = Color.turquoise30

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            dialogContent
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Dialog Content

    private var dialogContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("Welcome to WoofWalk Business")
                .font(.title2.bold())
                .foregroundColor(.white)

            // Description
            Text("This app is for managing your business on the go \u{2014} view jobs, complete walks, toggle availability, and track earnings.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            // Feature list
            VStack(alignment: .leading, spacing: 14) {
                Text("What you can do here:")
                    .font(.headline)
                    .foregroundColor(.white)

                featureRow(emoji: "\u{1F6B6}", text: "Start and track walks")
                featureRow(emoji: "\u{1F4C5}", text: "View today\u{2019}s schedule")
                featureRow(emoji: "\u{1F441}", text: "Go online/offline")
                featureRow(emoji: "\u{1F4BB}", text: "Track daily earnings")
                featureRow(emoji: "\u{1F465}", text: "Manage active jobs")
            }

            // Info box
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(tealAccent)
                    .font(.body)

                Text("For full functionality including scheduling, invoicing, client management, and analytics, visit your dashboard at **woofwalk.app**")
                    .font(.caption)
                    .foregroundColor(tealAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(tealAccent.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(tealAccent.opacity(0.3), lineWidth: 1)
            )

            // Bottom row: checkbox + button
            HStack {
                // Don't show again checkbox
                Button(action: {
                    dontShowAgain.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                            .foregroundColor(dontShowAgain ? tealAccent : .white.opacity(0.5))
                            .font(.title3)

                        Text("Don\u{2019}t show again")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Got it button
                Button(action: {
                    dismiss()
                }) {
                    Text("Got it")
                        .font(.body.bold())
                        .foregroundColor(Color.neutral10)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(tealAccent)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
    }

    // MARK: - Feature Row

    private func featureRow(emoji: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title3)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        if dontShowAgain {
            hasSeenWelcome = true
        }
        isPresented = false
    }
}

// MARK: - View Modifier for easy usage

struct BusinessWelcomeModifier: ViewModifier {
    @AppStorage("hasSeenBusinessWelcome") private var hasSeenWelcome: Bool = false
    @State private var showDialog = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasSeenWelcome {
                    showDialog = true
                }
            }
            .overlay {
                if showDialog {
                    BusinessWelcomeDialog(isPresented: $showDialog)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: showDialog)
                }
            }
    }
}

extension View {
    func businessWelcomeDialog() -> some View {
        modifier(BusinessWelcomeModifier())
    }
}

// MARK: - Preview

#Preview("Welcome Dialog") {
    ZStack {
        Color.neutral10.ignoresSafeArea()
        Text("Business Home")
            .foregroundColor(.white)
    }
    .overlay {
        BusinessWelcomeDialog(isPresented: .constant(true))
    }
}
