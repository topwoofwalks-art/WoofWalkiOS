import SwiftUI

struct LanguageSelectionView: View {
    @State private var selectedLanguage: String = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    @State private var showRestartAlert = false
    @State private var pendingLanguage: String?

    private let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("cy", "Welsh")
    ]

    var body: some View {
        List {
            Section {
                ForEach(languages, id: \.code) { language in
                    Button {
                        if language.code != selectedLanguage {
                            pendingLanguage = language.code
                            showRestartAlert = true
                        }
                    } label: {
                        HStack {
                            Text(language.name)
                                .foregroundColor(.primary)

                            Spacer()

                            if language.code == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            } footer: {
                Text("Changing the language requires restarting the app for the change to take full effect.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) {
                pendingLanguage = nil
            }
            Button("Change Language") {
                if let code = pendingLanguage {
                    selectedLanguage = code
                    UserDefaults.standard.set(code, forKey: "appLanguage")
                    UserDefaults.standard.set([code], forKey: "AppleLanguages")
                    UserDefaults.standard.synchronize()
                }
                pendingLanguage = nil
            }
        } message: {
            Text("The app needs to be restarted for the language change to take effect. Please close and reopen the app.")
        }
    }
}

#Preview {
    NavigationView {
        LanguageSelectionView()
    }
}
