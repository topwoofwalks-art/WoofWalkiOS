import Foundation

// MARK: - Poo Bag Drop ViewModel

@MainActor
class PooBagDropViewModel: ObservableObject {
    @Published var activeBagDrops: [PooBagDrop] = []

    func markAsCollected(_ id: String) {
        activeBagDrops.removeAll { $0.id == id }
    }
}
