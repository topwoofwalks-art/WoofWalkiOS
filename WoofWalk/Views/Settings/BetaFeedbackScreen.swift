import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// iOS port of `app/src/main/java/com/woofwalk/ui/profile/BetaFeedbackScreen.kt`.
///
/// Lets a signed-in beta tester submit a written report (and optional
/// screenshot) to the `beta_feedback` Firestore collection. Document
/// shape mirrors Android exactly so the back-office dashboard sees the
/// same fields regardless of platform:
///
///   beta_feedback/{auto}
///     userId:        uid (or "anonymous")
///     body:          free-form text
///     screenshotUrl: download URL (optional)
///     appVersion:    e.g. "1.0.0"
///     platform:      "ios"
///     createdAt:     serverTimestamp
///
/// Wired from `SettingsView` under the "Giving back" → support section.
struct BetaFeedbackScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bodyText: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var screenshotData: Data?
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        Form {
            Section {
                Text("Tell us what's broken, missing, or confusing. Screenshots help us reproduce.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Your feedback") {
                ZStack(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text("What's broken / missing?")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 160)
                        .disabled(isSubmitting)
                }
            }

            Section("Screenshot (optional)") {
                if let data = screenshotData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .cornerRadius(12)
                    Button(role: .destructive) {
                        screenshotData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Label("Remove screenshot", systemImage: "trash")
                    }
                    .disabled(isSubmitting)
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Add screenshot", systemImage: "photo.badge.plus")
                    }
                    .disabled(isSubmitting)
                }
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSubmitting ? "Sending…" : "Send feedback")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .background(canSubmit ? Color.turquoise60 : Color(.systemGray3))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal)
            }
        }
        .navigationTitle("Beta feedback")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { newItem in
            Task { await loadSelectedPhoto(newItem) }
        }
        .alert("Thanks for the feedback!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your report is on its way to the WoofWalk team. We read every one.")
        }
    }

    // MARK: - Photo picker

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run { screenshotData = data }
        }
    }

    // MARK: - Submit

    private func submit() {
        guard canSubmit else { return }
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let dataToUpload = screenshotData
        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                var screenshotUrl: String?
                if let data = dataToUpload {
                    screenshotUrl = try await uploadScreenshot(data: data)
                }

                let uid = Auth.auth().currentUser?.uid ?? "anonymous"
                let info = Bundle.main.infoDictionary
                let appVersion = info?["CFBundleShortVersionString"] as? String ?? "unknown"
                let buildNumber = info?["CFBundleVersion"] as? String ?? ""
                let versionString = buildNumber.isEmpty ? appVersion : "\(appVersion) (\(buildNumber))"

                var payload: [String: Any] = [
                    "userId": uid,
                    "body": trimmed,
                    "appVersion": versionString,
                    "platform": "ios",
                    "createdAt": FieldValue.serverTimestamp()
                ]
                if let url = screenshotUrl {
                    payload["screenshotUrl"] = url
                }

                _ = try await Firestore.firestore()
                    .collection("beta_feedback")
                    .addDocument(data: payload)

                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Couldn't send: \(error.localizedDescription)"
                }
            }
        }
    }

    private func uploadScreenshot(data: Data) async throws -> String {
        let uid = Auth.auth().currentUser?.uid ?? "anonymous"
        let id = UUID().uuidString
        // Keep the path under the user's own segment so Storage rules can
        // gate write access to `request.auth.uid == uid`.
        let ref = Storage.storage().reference().child("beta_feedback/\(uid)/\(id).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }
}
