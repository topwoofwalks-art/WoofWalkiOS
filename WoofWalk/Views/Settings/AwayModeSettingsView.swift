import SwiftUI

struct AwayModeSettingsView: View {
    @Binding var isEnabled: Bool
    @Binding var autoReplyMessage: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Away Mode") {
                Toggle("Enable Away Mode", isOn: $isEnabled)

                if isEnabled {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                }
            }

            Section("Auto-Reply Message") {
                TextEditor(text: $autoReplyMessage)
                    .frame(minHeight: 80)

                if autoReplyMessage.isEmpty {
                    Text("Tip: Set a message so clients know when you'll be back")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isEnabled {
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.orange)
                            Text("Away Mode Active")
                                .fontWeight(.semibold)
                        }
                        Text(autoReplyMessage.isEmpty ? "No auto-reply message set" : autoReplyMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Away Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave()
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
