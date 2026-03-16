import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel

    var body: some View {
        VStack {
            Text("Profile Setup")
                .font(.largeTitle)
            Button("Complete") {
                navigationViewModel.navigateToRoot()
                navigationViewModel.selectTab(.map)
            }
        }
        .navigationTitle("Setup Profile")
    }
}

struct SocialHubView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel

    var body: some View {
        VStack {
            Text("Social Hub")
                .font(.largeTitle)
            Button("View Chats") {
                navigationViewModel.navigate(to: .chats)
            }
            Button("Lost Dogs Feed") {
                navigationViewModel.navigate(to: .lostDogsFeed)
            }
        }
        .navigationTitle("Social")
    }
}

struct WalkTrackingView: View {
    var body: some View {
        Text("Walk Tracking")
            .navigationTitle("Walk")
    }
}

struct AlertHistoryView: View {
    var body: some View {
        Text("Alert History")
            .navigationTitle("Alert History")
    }
}

struct ChatListView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel

    var body: some View {
        List {
            Button("Chat 1") {
                navigationViewModel.navigate(to: .chatMessage(chatId: "chat1"))
            }
            Button("Chat 2") {
                navigationViewModel.navigate(to: .chatMessage(chatId: "chat2"))
            }
        }
        .navigationTitle("Chats")
    }
}

struct ChatMessageView: View {
    let chatId: String

    var body: some View {
        VStack {
            Text("Chat")
                .font(.largeTitle)
            Text("Chat ID: \(chatId)")
                .font(.caption)
        }
        .navigationTitle("Messages")
    }
}

struct LostDogsFeedView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel

    var body: some View {
        VStack {
            Text("Lost Dogs Feed")
                .font(.largeTitle)
            Button("Report Lost Dog") {
                navigationViewModel.navigate(to: .reportLostDog)
            }
        }
        .navigationTitle("Lost Dogs")
    }
}

struct ReportLostDogView: View {
    var body: some View {
        Text("Report Lost Dog")
            .navigationTitle("Report")
    }
}
