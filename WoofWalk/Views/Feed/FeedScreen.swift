import SwiftUI

struct FeedScreen: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var storyViewModel = StoryViewModel()
    @State private var showCreatePost = false

    private var emptyStateIcon: String {
        switch viewModel.feedMode {
        case .forYou: return "pawprint.circle.fill"
        case .trending: return "flame.circle.fill"
        case .nearby: return "location.circle.fill"
        case .following: return "person.2.circle.fill"
        }
    }

    private var emptyStateTitle: String {
        switch viewModel.feedMode {
        case .forYou: return "No Posts Yet"
        case .trending: return "Nothing Trending"
        case .nearby: return "No Nearby Posts"
        case .following: return "No Posts from Friends"
        }
    }

    private var emptyStateMessage: String {
        switch viewModel.feedMode {
        case .forYou: return "Start a walk and share it with the community!"
        case .trending: return "Posts gaining traction will appear here. Be the first to spark a conversation!"
        case .nearby: return "No one has posted within 25km yet. Be the first!"
        case .following: return "Add friends to see their posts here."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stories row
            StoriesRow(viewModel: storyViewModel)

            // Tab picker
            Picker("Feed", selection: $viewModel.feedMode) {
                ForEach(FeedMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: viewModel.feedMode) { newMode in
                viewModel.switchMode(newMode)
            }

            ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            WalkPostCard(
                                post: post,
                                onReaction: { type in
                                    viewModel.toggleReaction(post, type: type)
                                },
                                onComment: { viewModel.selectedPost = post },
                                onShare: {}
                            )

                            // Insert a DogReelCard every 10 posts
                            if (index + 1) % 10 == 0,
                               let reel = DogReelSamples.reel(at: (index + 1) / 10 - 1) {
                                DogReelCard(
                                    videoURL: reel.url,
                                    dogName: reel.dogName,
                                    ownerName: reel.ownerName
                                )
                                .frame(height: 480)
                            }
                        }

                        // Infinite scroll trigger
                        if !viewModel.posts.isEmpty {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    viewModel.loadMorePosts()
                                }
                        }

                        if viewModel.isLoading || viewModel.isLoadingMore {
                            ProgressView().padding()
                        }

                        if !viewModel.isLoading && viewModel.posts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: emptyStateIcon)
                                    .font(.system(size: 64))
                                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))

                                Text(emptyStateTitle)
                                    .font(.title3.bold())

                                Text(emptyStateMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                Button(action: { showCreatePost = true }) {
                                    Label("Start Walking", systemImage: "figure.walk")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255)))
                                }
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            .refreshable { viewModel.refresh() }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostSheet(onPost: { text, photoUrl in
                viewModel.createPost(text: text, photoUrl: photoUrl)
            })
            .environmentObject(viewModel)
        }
        .sheet(item: $viewModel.selectedPost) { post in
            PostDetailScreen(post: post)
        }
    }
}
