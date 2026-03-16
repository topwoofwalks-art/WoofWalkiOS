import SwiftUI

struct CreatePostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var photoUrl: String?
    let onPost: (String, String?) -> Void

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding()

                Spacer()
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        onPost(text, photoUrl)
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                    .fontWeight(.bold)
                    .foregroundColor(.turquoise60)
                }
            }
        }
    }
}
