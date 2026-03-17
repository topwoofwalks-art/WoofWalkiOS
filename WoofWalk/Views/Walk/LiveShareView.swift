import SwiftUI

struct LiveShareView: View {
    @Environment(\.dismiss) private var dismiss
    let walkId: String
    let onStopSharing: () -> Void

    @State private var shareLink: String?
    @State private var isLoading = true
    @State private var isCopied = false
    @State private var showSystemShare = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerIcon

                Text("Share Live Walk")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Let friends and family follow your walk in real time.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if isLoading {
                    loadingState
                } else if let link = shareLink {
                    linkDisplay(link)
                    actionButtons(link)
                }

                Spacer()

                expiryNotice

                stopButton
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showSystemShare) {
                if let link = shareLink {
                    ActivitySheet(items: [
                        "Follow my walk live on WoofWalk!",
                        URL(string: link) as Any,
                    ])
                }
            }
            .task {
                await generateLink()
            }
        }
    }

    // MARK: - Sub-views

    private var headerIcon: some View {
        Image(systemName: "location.circle.fill")
            .font(.system(size: 56))
            .foregroundColor(.turquoise60)
            .padding(.top, 8)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Generating share link...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
    }

    private func linkDisplay(_ link: String) -> some View {
        HStack {
            Text(link)
                .font(.system(.subheadline, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if isCopied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private func actionButtons(_ link: String) -> some View {
        VStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = link
                withAnimation { isCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { isCopied = false }
                }
            } label: {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.turquoise60)

            Button {
                showSystemShare = true
            } label: {
                Label("Share via...", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var expiryNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.caption)
            Text("Link expires in 4 hours")
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            onStopSharing()
            dismiss()
        } label: {
            Label("Stop Sharing", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .padding(.bottom)
    }

    // MARK: - Logic

    private func generateLink() async {
        let link = await ShareService.shared.generateLiveShareLink(walkId: walkId)
        await MainActor.run {
            shareLink = link
            isLoading = false
        }
    }
}

// MARK: - UIKit bridge for system share sheet

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
