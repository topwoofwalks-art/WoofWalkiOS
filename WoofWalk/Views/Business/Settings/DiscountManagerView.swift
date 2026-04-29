import SwiftUI

// MARK: - Main Screen

struct DiscountManagerView: View {
    @StateObject private var vm: DiscountManagerViewModel

    init(orgId: String) {
        _vm = StateObject(wrappedValue: DiscountManagerViewModel(orgId: orgId))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading discounts...")
            } else if vm.discounts.isEmpty {
                emptyState
            } else {
                discountList
            }
        }
        .navigationTitle("Discounts & Offers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.showingTypeSelector = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $vm.showingTypeSelector) {
            DiscountTypeSelectorSheet { type in
                vm.createNew(type: type)
            }
        }
        .sheet(isPresented: $vm.showingEditor) {
            if let discount = vm.editingDiscount {
                DiscountEditorSheet(discount: discount) { updated in
                    vm.save(updated)
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Discounts Yet")
                .font(.title2.bold())
            Text("Create discounts and offers to attract new clients and reward loyal ones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                vm.showingTypeSelector = true
            } label: {
                Label("Add Discount", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Discount List

    private var discountList: some View {
        List {
            ForEach(vm.discounts) { discount in
                DiscountRow(discount: discount, onToggle: {
                    vm.toggle(discount)
                })
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vm.delete(discount)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        vm.edit(discount)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Discount Row

private struct DiscountRow: View {
    let discount: BusinessDiscount
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: discount.type.icon)
                .font(.title3)
                .foregroundStyle(discount.isActive ? .blue : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    (discount.isActive ? Color.blue : Color.secondary)
                        .opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(discount.name)
                        .font(.headline)
                    discountBadge
                }
                if !discount.description.isEmpty {
                    Text(discount.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Toggle("", isOn: .init(
                get: { discount.isActive },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var discountBadge: some View {
        if discount.percentOff > 0 {
            Text("\(Int(discount.percentOff))% off")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        } else if discount.amountOff > 0 {
            Text("\(CurrencyFormatter.shared.formatPrice(discount.amountOff)) off")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Type Selector Sheet

private struct DiscountTypeSelectorSheet: View {
    let onSelect: (DiscountType) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(DiscountType.allCases, id: \.self) { type in
                        Button {
                            onSelect(type)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Circle())
                                Text(type.displayName)
                                    .font(.subheadline.bold())
                                Text(typeSubtitle(type))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func typeSubtitle(_ type: DiscountType) -> String {
        switch type {
        case .MULTI_DOG: return "Discount per extra dog"
        case .BULK_PACK: return "Buy a pack of walks"
        case .RECURRING: return "Regular booking reward"
        case .LOYALTY: return "Reward loyal clients"
        case .FIRST_BOOKING: return "Welcome new clients"
        case .REFERRAL: return "Reward referrals"
        case .DURATION: return "Longer walk discount"
        case .CUSTOM: return "Fully custom offer"
        }
    }
}

// MARK: - Editor Sheet

private struct DiscountEditorSheet: View {
    @State private var draft: BusinessDiscount
    let onSave: (BusinessDiscount) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var usePercent = true
    @State private var serviceTypeInput = ""

    private let allServiceTypes = ["Dog Walking", "Day Care", "Home Boarding", "Grooming", "Training", "Pet Sitting"]

    init(discount: BusinessDiscount, onSave: @escaping (BusinessDiscount) -> Void) {
        _draft = State(initialValue: discount)
        _usePercent = State(initialValue: discount.percentOff > 0 || discount.amountOff == 0)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                discountValueSection
                typeSpecificSection
                servicesSection
                optionsSection
            }
            .navigationTitle(draft.id == nil ? "New Discount" : "Edit Discount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                    }
                    .bold()
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: Basic Info

    private var basicSection: some View {
        Section("Details") {
            HStack(spacing: 10) {
                Image(systemName: draft.type.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                Text(draft.type.displayName)
                    .foregroundStyle(.secondary)
            }
            TextField("Name", text: $draft.name)
            TextField("Description (optional)", text: $draft.description)
        }
    }

    // MARK: Discount Value

    private var discountValueSection: some View {
        Section("Discount") {
            Picker("Type", selection: $usePercent) {
                Text("Percentage").tag(true)
                Text("Fixed Amount").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: usePercent) { isPercent in
                if isPercent {
                    draft.amountOff = 0
                } else {
                    draft.percentOff = 0
                }
            }

            if usePercent {
                HStack {
                    Text("Percent Off")
                    Spacer()
                    TextField("0", value: $draft.percentOff, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("Amount Off")
                    Spacer()
                    Text(CurrencyFormatter.shared.symbol())
                        .foregroundStyle(.secondary)
                    TextField("0.00", value: $draft.amountOff, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
        }
    }

    // MARK: Type-Specific Fields

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch draft.type {
        case .MULTI_DOG:
            Section("Multi-Dog Settings") {
                Stepper("Min Dogs: \(draft.minDogs)", value: $draft.minDogs, in: 2...10)
            }
        case .BULK_PACK:
            Section("Pack Settings") {
                Stepper("Pack Size: \(draft.packSize)", value: $draft.packSize, in: 3...50)
                HStack {
                    Text("Pack Price")
                    Spacer()
                    Text(CurrencyFormatter.shared.symbol())
                        .foregroundStyle(.secondary)
                    TextField("0.00", value: $draft.packPrice, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Stepper("Expiry: \(draft.packExpiryDays) days", value: $draft.packExpiryDays, in: 7...365, step: 7)
            }
        case .RECURRING:
            Section("Recurring Settings") {
                Stepper("Min Bookings: \(draft.minBookings)", value: $draft.minBookings, in: 2...52)
            }
        case .LOYALTY:
            Section("Loyalty Settings") {
                Stepper("Min Bookings: \(draft.minBookings)", value: $draft.minBookings, in: 3...100)
            }
        case .FIRST_BOOKING:
            Section("First Booking Settings") {
                Stepper(value: $draft.maxUsesPerClient, in: 0...10) {
                    if draft.maxUsesPerClient == 0 {
                        Text("Max Uses: Unlimited")
                    } else {
                        Text("Max Uses: \(draft.maxUsesPerClient)")
                    }
                }
            }
        case .REFERRAL:
            Section("Referral Settings") {
                Stepper(value: $draft.maxUsesPerClient, in: 0...50) {
                    if draft.maxUsesPerClient == 0 {
                        Text("Max Uses: Unlimited")
                    } else {
                        Text("Max Uses: \(draft.maxUsesPerClient)")
                    }
                }
            }
        case .DURATION:
            Section("Duration Settings") {
                Stepper("Min Duration: \(draft.minDurationMins) min", value: $draft.minDurationMins, in: 30...180, step: 15)
            }
        case .CUSTOM:
            EmptyView()
        }
    }

    // MARK: Service Types

    private var servicesSection: some View {
        Section {
            if draft.serviceTypes.isEmpty {
                Text("Applies to all services")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(draft.serviceTypes, id: \.self) { svc in
                    HStack {
                        Text(svc)
                        Spacer()
                        Button {
                            draft.serviceTypes.removeAll { $0 == svc }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let available = allServiceTypes.filter { !draft.serviceTypes.contains($0) }
            if !available.isEmpty {
                Menu {
                    ForEach(available, id: \.self) { svc in
                        Button(svc) {
                            draft.serviceTypes.append(svc)
                        }
                    }
                } label: {
                    Label("Limit to Service", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
        } header: {
            Text("Services")
        } footer: {
            Text("Leave empty to apply to all service types.")
        }
    }

    // MARK: Options

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Stackable with other discounts", isOn: $draft.stackable)
            Stepper("Priority: \(draft.priority)", value: $draft.priority, in: 1...99)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DiscountManagerView(orgId: "preview-org")
    }
}
