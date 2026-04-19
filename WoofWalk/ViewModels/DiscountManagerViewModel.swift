import Foundation
import Combine

class DiscountManagerViewModel: ObservableObject {
    @Published var discounts: [BusinessDiscount] = []
    @Published var isLoading = true
    @Published var editingDiscount: BusinessDiscount?
    @Published var showingTypeSelector = false
    @Published var showingEditor = false
    @Published var errorMessage: String?

    private let repository = DiscountRepository()
    private let orgId: String
    private var cancellables = Set<AnyCancellable>()

    init(orgId: String) {
        self.orgId = orgId
        repository.observeDiscounts(orgId: orgId)
        repository.$discounts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] discounts in
                self?.discounts = discounts
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func createNew(type: DiscountType) {
        editingDiscount = BusinessDiscount(type: type, name: type.displayName)
        showingTypeSelector = false
        showingEditor = true
    }

    func edit(_ discount: BusinessDiscount) {
        editingDiscount = discount
        showingEditor = true
    }

    func save(_ discount: BusinessDiscount) {
        Task {
            do {
                if discount.id == nil || discount.id?.isEmpty == true {
                    _ = try await repository.createDiscount(orgId: orgId, discount: discount)
                } else {
                    try await repository.updateDiscount(orgId: orgId, discount: discount)
                }
                await MainActor.run {
                    showingEditor = false
                    editingDiscount = nil
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func toggle(_ discount: BusinessDiscount) {
        guard let id = discount.id else { return }
        Task {
            try? await repository.toggleDiscount(orgId: orgId, discountId: id, isActive: !discount.isActive)
        }
    }

    func delete(_ discount: BusinessDiscount) {
        guard let id = discount.id else { return }
        Task {
            try? await repository.deleteDiscount(orgId: orgId, discountId: id)
        }
    }
}
