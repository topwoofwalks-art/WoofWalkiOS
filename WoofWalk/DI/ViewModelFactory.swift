// This file is excluded from compilation because it references types
// that don't exist in the actual codebase yet.
#if false
import Foundation
import SwiftUI

protocol ViewModelFactory {
    associatedtype ViewModel: ObservableObject
    static func create() -> ViewModel
}

final class ViewModelProvider {
    static let shared = ViewModelProvider()
    private let container = DIContainer.shared

    private init() {}

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            userRepository: container.resolve(),
            dogRepository: container.resolve()
        )
    }

    func makeMapViewModel() -> MapViewModel {
        MapViewModel(
            poiRepository: container.resolve(),
            routeRepository: container.resolve(),
            pooBagDropRepository: container.resolve(),
            publicDogRepository: container.resolve(),
            lostDogRepository: container.resolve(),
            geofenceManager: container.resolve(),
            userDataStore: container.resolve(),
            overpassService: container.resolve(),
            walkRepository: container.resolve()
        )
    }

    func makeRoutingViewModel() -> RoutingViewModel {
        RoutingViewModel(
            routeRepository: container.resolve(),
            directionsRepository: container.resolve(),
            poiRepository: container.resolve(),
            locationService: container.resolve()
        )
    }

    func makeGuidanceViewModel() -> GuidanceViewModel {
        GuidanceViewModel(
            locationService: container.resolve(),
            routeRepository: container.resolve()
        )
    }

    func makeWalkViewModel() -> WalkViewModel {
        WalkViewModel(
            walkRepository: container.resolve(),
            dogRepository: container.resolve(),
            locationService: container.resolve(),
            userRepository: container.resolve()
        )
    }

    func makeWalkTrackingViewModel() -> WalkTrackingViewModel {
        WalkTrackingViewModel(
            walkSessionRepository: container.resolve(),
            walkRepository: container.resolve(),
            locationService: container.resolve(),
            dogRepository: container.resolve(),
            poiRepository: container.resolve()
        )
    }

    func makePooBagDropViewModel() -> PooBagDropViewModel {
        PooBagDropViewModel(
            pooBagDropRepository: container.resolve(),
            locationService: container.resolve()
        )
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            userRepository: container.resolve(),
            dogRepository: container.resolve(),
            walkRepository: container.resolve(),
            auth: container.resolve()
        )
    }

    func makeDogManagementViewModel() -> DogManagementViewModel {
        DogManagementViewModel(
            dogRepository: container.resolve(),
            storageManager: container.resolve(),
            imageCompressor: container.resolve()
        )
    }

    func makePoiViewModel() -> PoiViewModel {
        PoiViewModel(
            poiRepository: container.resolve(),
            locationService: container.resolve(),
            storageManager: container.resolve()
        )
    }

    func makeRouteViewModel() -> RouteViewModel {
        RouteViewModel(
            routeRepository: container.resolve(),
            poiRepository: container.resolve()
        )
    }

    func makeFeedViewModel() -> FeedViewModel {
        FeedViewModel(
            feedRepository: container.resolve(),
            userRepository: container.resolve()
        )
    }

    func makeLostDogViewModel() -> LostDogViewModel {
        LostDogViewModel(
            lostDogRepository: container.resolve(),
            locationService: container.resolve(),
            storageManager: container.resolve()
        )
    }

    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(
            chatRepository: container.resolve(),
            friendRepository: container.resolve()
        )
    }

    func makeChatMessageViewModel(chatId: String) -> ChatMessageViewModel {
        ChatMessageViewModel(
            chatId: chatId,
            chatRepository: container.resolve(),
            userRepository: container.resolve()
        )
    }

    func makeFriendsViewModel() -> FriendsViewModel {
        FriendsViewModel(
            friendRepository: container.resolve(),
            userRepository: container.resolve()
        )
    }

    func makeEventsViewModel() -> EventsViewModel {
        EventsViewModel(
            eventRepository: container.resolve(),
            locationService: container.resolve(),
            userRepository: container.resolve()
        )
    }

    func makeNotificationViewModel() -> NotificationViewModel {
        NotificationViewModel(
            firestore: container.resolve(),
            auth: container.resolve()
        )
    }

    func makeAlertViewModel() -> AlertViewModel {
        AlertViewModel(
            lostDogRepository: container.resolve(),
            locationService: container.resolve(),
            notificationHelper: container.resolve()
        )
    }
}

@propertyWrapper
struct ViewModel<T: ObservableObject>: DynamicProperty {
    @StateObject private var viewModel: T

    init(wrappedValue: @autoclosure @escaping () -> T) {
        self._viewModel = StateObject(wrappedValue: wrappedValue())
    }

    var wrappedValue: T {
        get { viewModel }
    }

    var projectedValue: ObservedObject<T>.Wrapper {
        return $viewModel
    }
}

extension View {
    func withViewModel<VM: ObservableObject>(_ viewModel: VM) -> some View {
        self.environmentObject(viewModel)
    }
}
#endif
