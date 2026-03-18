import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AwayModeSettingsView: View {
    @Binding var isEnabled: Bool
    @Binding var autoReplyMessage: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var holidayMode: HolidayMode
    @Binding var quickReplies: [QuickReplyTemplate]
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newQuickReplyText: String = ""
    @State private var showAddQuickReply: Bool = false

    var body: some View {
        Form {
            Section("Away Mode") {
                Toggle("Enable Away Mode", isOn: $isEnabled)

                if isEnabled {
                    TextEditor(text: $autoReplyMessage)
                        .frame(minHeight: 60)

                    if autoReplyMessage.isEmpty {
                        Text("Tip: Set a message so clients know when you'll be back")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Holiday Mode") {
                Toggle("Enable Holiday Mode", isOn: $holidayMode.enabled)

                if holidayMode.enabled {
                    DatePicker("Start", selection: Binding(
                        get: { holidayMode.startDate ?? Date() },
                        set: { holidayMode.startDate = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    DatePicker("End", selection: Binding(
                        get: { holidayMode.endDate ?? Date().addingTimeInterval(86400) },
                        set: { holidayMode.endDate = $0 }
                    ), in: (holidayMode.startDate ?? Date())..., displayedComponents: [.date, .hourAndMinute])

                    TextField("Holiday message", text: $holidayMode.message, axis: .vertical)
                        .lineLimit(2...4)
                }
            }

            Section("Quick Reply Templates") {
                ForEach(quickReplies) { reply in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reply.text)
                            .font(.subheadline)
                        Text(reply.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete { indexSet in
                    quickReplies.remove(atOffsets: indexSet)
                }

                Button {
                    showAddQuickReply = true
                } label: {
                    Label("Add Quick Reply", systemImage: "plus.circle")
                }
            }

            if isEnabled || holidayMode.enabled {
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        if isEnabled {
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
                        if holidayMode.enabled {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.yellow)
                                Text("Holiday Mode Active")
                                    .fontWeight(.semibold)
                            }
                            if let start = holidayMode.startDate, let end = holidayMode.endDate {
                                Text("\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if !holidayMode.message.isEmpty {
                                Text(holidayMode.message)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
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
        .alert("Add Quick Reply", isPresented: $showAddQuickReply) {
            TextField("Reply text", text: $newQuickReplyText)
            Button("Add") {
                if !newQuickReplyText.isEmpty {
                    quickReplies.append(QuickReplyTemplate(text: newQuickReplyText))
                    newQuickReplyText = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newQuickReplyText = ""
            }
        }
    }
}
