import SwiftUI

struct SocialHubScreen: View {
    @State private var selectedTab = 0
    @State private var showCreatePost = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(["Feed", "Challenges", "League", "Friends"], id: \.self) { tab in
                        let index = ["Feed", "Challenges", "League", "Friends"].firstIndex(of: tab) ?? 0
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 4) {
                                Text(tab)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == index ? .bold : .regular)
                                    .foregroundColor(selectedTab == index ? .turquoise60 : .secondary)

                                Rectangle()
                                    .fill(selectedTab == index ? Color.turquoise60 : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Content
                TabView(selection: $selectedTab) {
                    FeedScreen().tag(0)
                    ChallengesScreen().tag(1)
                    LeagueView().tag(2)
                    LeaderboardView().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Social")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.turquoise60)
                    }

                    NavigationLink(destination: ChatListScreen()) {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostSheet(onPost: { _, _ in })
            }
        }
    }
}
