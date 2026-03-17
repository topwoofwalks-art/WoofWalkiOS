import SwiftUI

struct QuickReplySheet: View {
    let chatId: String
    let onSend: (String) -> Void

    private let templates = [
        "Thanks for your message! I'll get back to you shortly.",
        "I'd love to help! When would you like to book?",
        "Your booking is confirmed. See you then!",
        "Thanks for choosing WoofWalk! How was the walk?",
        "I'm currently unavailable. I'll reply as soon as possible."
    ]

    private let icons = [
        "hand.wave.fill",
        "calendar.badge.plus",
        "checkmark.circle.fill",
        "star.fill",
        "moon.fill"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(templates.enumerated()), id: \.offset) { index, template in
                        Button {
                            onSend(template)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icons[index])
                                    .font(.title3)
                                    .foregroundColor(.turquoise60)
                                    .frame(width: 32)

                                Text(template)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.turquoise60)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } header: {
                    Text("Tap to send instantly")
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Quick Reply")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
