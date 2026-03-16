import SwiftUI

struct FeedScreen: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showCreatePost = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.posts) { post in
                        WalkPostCard(
                            post: post,
                            onLike: { viewModel.toggleLike(post) },
                            onComment: { viewModel.selectedPost = post },
                            onShare: {}
                        )
                    }

                    if viewModel.isLoading {
                        ProgressView().padding()
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.turquoise60)
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostSheet(onPost: { text, photoUrl in
                    viewModel.createPost(text: text, photoUrl: photoUrl)
                })
            }
            .sheet(item: $viewModel.selectedPost) { post in
                PostDetailScreen(post: post)
            }
            .refreshable { viewModel.refresh() }
        }
    }
}
