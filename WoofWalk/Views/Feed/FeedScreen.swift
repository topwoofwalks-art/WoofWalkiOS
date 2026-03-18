import SwiftUI

struct FeedScreen: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showCreatePost = false

    var body: some View {
        VStack(spacing: 0) {
            // Stories row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // "Your Story" button
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.15))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.title2)
                                        .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                                )

                            Circle()
                                .fill(Color(red: 0/255, green: 160/255, blue: 176/255))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                )
                                .offset(x: 2, y: 2)
                        }

                        Text("Your Story")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Placeholder story circles
                    ForEach(0..<5, id: \.self) { i in
                        VStack(spacing: 4) {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0/255, green: 160/255, blue: 176/255), .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .padding(3)
                                        .overlay(
                                            Image(systemName: "pawprint.fill")
                                                .foregroundColor(.gray.opacity(0.5))
                                        )
                                )

                            Text("Dog \(i + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

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
