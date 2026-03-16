import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Track Your Walks",
            description: "Record every walk with your furry friend and watch your journey unfold",
            imageName: "figure.walk",
            color: .blue
        ),
        OnboardingPage(
            title: "Discover New Routes",
            description: "Find dog-friendly parks, trails, and hidden gems in your area",
            imageName: "map",
            color: .green
        ),
        OnboardingPage(
            title: "Connect with Community",
            description: "Meet other dog lovers, share experiences, and join local events",
            imageName: "person.3",
            color: .orange
        ),
        OnboardingPage(
            title: "Earn Rewards",
            description: "Complete challenges, earn badges, and level up your walking adventures",
            imageName: "star.fill",
            color: .purple
        )
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    PrimaryButton(
                        title: "Get Started",
                        isLoading: false,
                        action: onComplete
                    )
                    .padding(.horizontal)
                } else {
                    Button(action: {
                        withAnimation {
                            currentPage += 1
                        }
                    }) {
                        HStack {
                            Text("Next")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    Button(action: onComplete) {
                        Text("Skip")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(page.color)
                .padding()

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }
}
