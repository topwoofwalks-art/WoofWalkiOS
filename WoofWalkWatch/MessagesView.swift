import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var selectedMessage: WatchMessage?

    private let quickReplies = ["On my way", "Running late", "OK", "Be there soon"]

    var body: some View {
        if let message = selectedMessage {
            // Detail view
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Button("< Back") { selectedMessage = nil }
                        .font(.system(size: 11))
                        .foregroundColor(Color("TealLight"))

                    Text(message.senderName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text(message.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)

                    Text(message.fullText)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.top, 4)

                    Text("Quick Reply")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color("TealLight"))
                        .padding(.top, 8)

                    ForEach(quickReplies, id: \.self) { reply in
                        Button(reply) {
                            sessionManager.sendQuickReply(senderId: message.senderId, reply: reply)
                            selectedMessage = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("TealMedium"))
                        .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 8)
            }
        } else {
            // List view
            if sessionManager.messages.isEmpty {
                Text("No messages")
                    .foregroundColor(.gray)
                    .font(.system(size: 13))
            } else {
                List(sessionManager.messages.prefix(10)) { message in
                    Button {
                        selectedMessage = message
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color("TealMedium"))
                                    .frame(width: 28, height: 28)
                                Text(String(message.senderName.prefix(1)).uppercased())
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading) {
                                HStack {
                                    Text(message.senderName)
                                        .font(.system(size: 12, weight: message.isRead ? .regular : .bold))
                                        .foregroundColor(message.isRead ? .gray : .white)
                                    Spacer()
                                    Text(message.timeAgo)
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                                Text(message.previewText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }

                            if !message.isRead {
                                Circle()
                                    .fill(Color("TealLight"))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "142621"))
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
