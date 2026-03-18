import SwiftUI

struct FeedScreen: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showCreatePost = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                        ForEach(viewModel.posts) { post in
                            WalkPostCard(
                                post: post,
                                onReaction: { type in
                                    viewModel.toggleReaction(post, type: type)
                                },
                                onComment: { viewModel.selectedPost = post },
                                onShare: {}
                            )
                        }

                        if viewModel.isLoading {
                            ProgressView().padding()
                        }

                        if !viewModel.isLoading && viewModel.posts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "pawprint.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))

                                Text("No Posts Yet")
                                    .font(.title3.bold())

                                Text("Start a walk and share it with the community!")
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
        }
    }
}
