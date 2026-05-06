import SwiftUI

/// Social Hub screen matching the Android design with scrollable tab pills:
/// Friends, Lost Dogs, Group Walks, Chats, Events
/// Replace SocialHubScreen usage with SocialHubScreenV2 to adopt the new layout.
struct SocialHubScreenV2: View {
    @State private var selectedTab = 0

    private let tabs: [(String, String)] = [
        ("Friends", "person.2.fill"),
        ("Communities", "person.3.sequence.fill"),
        ("Lost Dogs", "pawprint.fill"),
        ("Group Walks", "figure.walk"),
        ("Chats", "bubble.left.and.bubble.right.fill"),
        ("Events", "calendar"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Social")
                        .font(.largeTitle.bold())
                    Text("Your dog community")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Scrollable tab row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                            SocialTabButton(
                                title: tab.0,
                                iconName: tab.1,
                                isSelected: selectedTab == index,
                                action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index } }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }

                // Thin divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 0.5)

                // Tab content
                TabView(selection: $selectedTab) {
                    FriendsListScreen().tag(0)
                    CommunityListScreen().tag(1)
                    LostDogsScreen().tag(2)
                    GroupWalksScreen().tag(3)
                    ChatsTabScreen().tag(4)
                    EventsScreen().tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
}

/// Individual tab button matching Android's scrollable tab pill style
private struct SocialTabButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? brandColor : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? brandColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? brandColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Chats tab wrapper that embeds ChatListScreen without its own NavigationStack
/// (since SocialHubScreenV2 already provides one)
struct ChatsTabScreen: View {
    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        List(viewModel.chats) { chat in
            NavigationLink(value: chat.id ?? "") {
                ChatListRow(chat: chat, currentUserId: viewModel.currentUserId)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: String.self) { chatId in
            ChatDetailScreen(chatId: chatId)
        }
        .overlay {
            if viewModel.chats.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No Messages")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Start a conversation with a friend or dog walker.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}
