import SwiftUI
import FirebaseFirestore

// MARK: - R9: Catalogue → Client Wiring
//
// Surfaces the per-vertical sub-configs the business filled in via the
// Service Catalogue wizard (Step 3) so the client picks the actual
// option they're booking instead of the legacy "From £X" base price.
//
// The server (createClientBooking, commit f7b71bd) accepts an optional
// `subSelection` map and resolves price from it. iOS currently writes
// bookings directly to Firestore (see BookingRepository.createBooking)
// rather than through the callable, so we persist `subSelection` /
// `subSelectionLabel` / `price` on the booking doc straight from the
// client. The selection schema itself matches the server contract.
//
// Field names below are read raw from Firestore using the exact
// `walkConfig.durations[]`, `groomingConfig.groomingMenu[]`,
// `boardingConfig.roomTypes[]`, etc. names the wizard / server use —
// **not** via the existing iOS WalkServiceConfig / GroomingServiceConfig
// model layer, which uses different field names (variants vs durations,
// menuItems vs groomingMenu) and isn't currently wired to the
// service_listings collection.
//
// The picker is opt-in: when a sub-config is missing or has zero active
// items the picker renders nothing and the existing basePrice flow stays
// intact. (Spec §3 — empty-state fallback.)

// MARK: - Sub-Selection Models

/// Output of the picker, ready to drop into a `[String: Any]` payload
/// for the booking write. Keys mirror the server's SubSelection contract.
struct R9SubSelection {
    /// `["walk": ["durationOptionId": id], ...]` payload form
    let payload: [String: Any]
    /// Human-readable echo for the receipt screen, e.g. "60 min Walk – £18".
    let label: String
    /// Resolved price for this selection (pre-platform-fee).
    let price: Double
}

// MARK: - Picker View

/// Renders the appropriate sub-config picker for the current service.
/// Loads the listing doc once on appear and caches it locally.
struct R9SubSelectionPicker: View {
    let orgId: String
    let serviceType: BookingServiceType
    let basePrice: Double
    let bookingStartTime: Date
    let bookingEndTime: Date
    /// Called whenever the user changes their selection. `nil` = empty
    /// fallback (no picker rendered, parent should use basePrice).
    let onSelectionChanged: (R9SubSelection?) -> Void

    @State private var listing: [String: Any]?
    @State private var isLoading = true
    @State private var loadError: String?

    // Selection state — only one is active per render based on serviceType.
    @State private var walkDurationId: String?
    @State private var groomingMenuItemId: String?
    @State private var groomingDogSize: String = "M"
    @State private var boardingRoomId: String?
    @State private var boardingNights: Int = 1
    @State private var trainingSessionTypeId: String?
    @State private var daycareSessionTypeId: String?
    @State private var sittingVisitTypeId: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let listing = listing {
                pickerBody(listing: listing)
            } else {
                // No listing or load error — render nothing, parent falls
                // back to basePrice. We don't surface loadError to the user
                // because the picker is opt-in clarity, not gating.
                EmptyView()
            }
        }
        .onAppear {
            loadListing()
            boardingNights = max(1, Int(ceil(bookingEndTime.timeIntervalSince(bookingStartTime) / 86_400)))
        }
    }

    // MARK: Listing Load

    private func loadListing() {
        // service_listings docs are keyed by `{orgId}_{serviceType}` per
        // the catalogue data model used by portal/Android.
        let docId = "\(orgId)_\(serviceType.rawValue)"
        let db = Firestore.firestore()
        db.collection("service_listings").document(docId).getDocument { snap, err in
            DispatchQueue.main.async {
                self.isLoading = false
                if let err = err {
                    self.loadError = err.localizedDescription
                    print("[R9SubSelectionPicker] listing load failed: \(err.localizedDescription)")
                    return
                }
                guard let snap = snap, snap.exists, let data = snap.data() else {
                    self.listing = nil
                    return
                }
                self.listing = data
            }
        }
    }

    // MARK: Vertical Dispatcher

    @ViewBuilder
    private func pickerBody(listing: [String: Any]) -> some View {
        switch serviceType {
        case .walk:
            walkPicker(listing: listing)
        case .grooming:
            groomingPicker(listing: listing)
        case .boarding:
            boardingPicker(listing: listing)
        case .training:
            trainingPicker(listing: listing)
        case .daycare:
            daycarePicker(listing: listing)
        case .petSitting:
            sittingPicker(listing: listing)
        case .inSitting, .outSitting, .meetGreet:
            // Server SubSelection contract has no key for these; spec
            // says MEET_GREET / MARKETPLACE submit basePrice as before.
            // IN_SITTING / OUT_SITTING fall back the same way until they
            // get their own contract entry.
            EmptyView()
        }
    }

    // MARK: Walk

    private func walkPicker(listing: [String: Any]) -> some View {
        let durations = walkDurations(listing: listing)
        return Group {
            if durations.isEmpty {
                EmptyView()
            } else {
                section(title: "Choose duration", icon: "clock") {
                    ForEach(durations, id: \.id) { opt in
                        radioRow(
                            label: opt.displayLabel,
                            price: opt.price,
                            isSelected: walkDurationId == opt.id,
                            isEnabled: true
                        ) {
                            walkDurationId = opt.id
                            emitWalkSelection(durations: durations)
                        }
                    }
                }
                .onAppear {
                    if walkDurationId == nil, let first = durations.first {
                        walkDurationId = first.id
                        emitWalkSelection(durations: durations)
                    }
                }
            }
        }
    }

    private func emitWalkSelection(durations: [WalkDurationRow]) {
        guard let id = walkDurationId, let opt = durations.first(where: { $0.id == id }) else {
            onSelectionChanged(nil)
            return
        }
        let payload: [String: Any] = ["walk": ["durationOptionId": opt.id]]
        let priceStr = CurrencyFormatter.shared.formatPrice(opt.price)
        let label = "\(opt.displayLabel) – \(priceStr)"
        onSelectionChanged(R9SubSelection(payload: payload, label: label, price: opt.price))
    }

    // MARK: Grooming

    private func groomingPicker(listing: [String: Any]) -> some View {
        let items = groomingMenu(listing: listing)
        let acceptedSizes = groomingAcceptedSizes(listing: listing)
        return Group {
            if items.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    section(title: "Dog size", icon: "pawprint") {
                        Picker("Dog size", selection: $groomingDogSize) {
                            ForEach(acceptedSizes, id: \.self) { size in
                                Text(sizeDisplayName(size)).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: groomingDogSize) { _ in
                            emitGroomingSelection(items: items)
                        }
                    }

                    section(title: "Choose service", icon: "scissors") {
                        ForEach(items, id: \.id) { item in
                            let priceForSize = item.prices[groomingDogSize]
                            radioRow(
                                label: item.name,
                                price: priceForSize,
                                isSelected: groomingMenuItemId == item.id,
                                isEnabled: priceForSize != nil
                            ) {
                                guard priceForSize != nil else { return }
                                groomingMenuItemId = item.id
                                emitGroomingSelection(items: items)
                            }
                        }
                    }
                }
                .onAppear {
                    if !acceptedSizes.contains(groomingDogSize), let first = acceptedSizes.first {
                        groomingDogSize = first
                    }
                    if groomingMenuItemId == nil,
                       let firstAvail = items.first(where: { $0.prices[groomingDogSize] != nil }) {
                        groomingMenuItemId = firstAvail.id
                        emitGroomingSelection(items: items)
                    }
                }
            }
        }
    }

    private func emitGroomingSelection(items: [GroomingMenuRow]) {
        guard let id = groomingMenuItemId,
              let item = items.first(where: { $0.id == id }),
              let price = item.prices[groomingDogSize] else {
            onSelectionChanged(nil)
            return
        }
        let payload: [String: Any] = [
            "grooming": [
                "menuItemId": item.id,
                "dogSize": groomingDogSize
            ]
        ]
        let priceStr = CurrencyFormatter.shared.formatPrice(price)
        let label = "\(item.name) – \(sizeDisplayName(groomingDogSize)) – \(priceStr)"
        onSelectionChanged(R9SubSelection(payload: payload, label: label, price: price))
    }

    // MARK: Boarding

    private func boardingPicker(listing: [String: Any]) -> some View {
        let rooms = boardingRoomTypes(listing: listing)
        return Group {
            if rooms.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    section(title: "Choose room", icon: "bed.double") {
                        ForEach(rooms, id: \.id) { room in
                            roomRow(
                                room: room,
                                isSelected: boardingRoomId == room.id
                            ) {
                                boardingRoomId = room.id
                                emitBoardingSelection(rooms: rooms)
                            }
                        }
                    }

                    section(title: "Nights", icon: "moon.stars") {
                        Stepper(value: $boardingNights, in: 1...60) {
                            Text("\(boardingNights) night\(boardingNights == 1 ? "" : "s")")
                                .foregroundColor(.white)
                        }
                        .onChange(of: boardingNights) { _ in
                            emitBoardingSelection(rooms: rooms)
                        }
                    }
                }
                .onAppear {
                    if boardingRoomId == nil, let first = rooms.first {
                        boardingRoomId = first.id
                        emitBoardingSelection(rooms: rooms)
                    }
                }
            }
        }
    }

    private func emitBoardingSelection(rooms: [BoardingRoomRow]) {
        guard let id = boardingRoomId, let room = rooms.first(where: { $0.id == id }) else {
            onSelectionChanged(nil)
            return
        }
        let nights = max(1, boardingNights)
        let total = room.pricePerNight * Double(nights)
        let payload: [String: Any] = [
            "boarding": [
                "roomTypeId": room.id,
                "nights": nights
            ]
        ]
        let perNight = CurrencyFormatter.shared.formatPrice(room.pricePerNight)
        let totalStr = CurrencyFormatter.shared.formatPrice(total)
        let label = "\(room.name) – \(perNight)/night × \(nights) = \(totalStr)"
        onSelectionChanged(R9SubSelection(payload: payload, label: label, price: total))
    }

    // MARK: Training

    private func trainingPicker(listing: [String: Any]) -> some View {
        let sessions = trainingSessionTypes(listing: listing)
        return Group {
            if sessions.isEmpty {
                EmptyView()
            } else {
                section(title: "Choose session", icon: "star") {
                    ForEach(sessions, id: \.id) { s in
                        radioRow(
                            label: s.displayLabel,
                            price: s.price,
                            isSelected: trainingSessionTypeId == s.id,
                            isEnabled: true
                        ) {
                            trainingSessionTypeId = s.id
                            emitTrainingSelection(sessions: sessions)
                        }
                    }
                }
                .onAppear {
                    if trainingSessionTypeId == nil, let first = sessions.first {
                        trainingSessionTypeId = first.id
                        emitTrainingSelection(sessions: sessions)
                    }
                }
            }
        }
    }

    private func emitTrainingSelection(sessions: [SessionTypeRow]) {
        guard let id = trainingSessionTypeId, let s = sessions.first(where: { $0.id == id }) else {
            onSelectionChanged(nil)
            return
        }
        let payload: [String: Any] = ["training": ["sessionTypeId": s.id]]
        let priceStr = CurrencyFormatter.shared.formatPrice(s.price)
        let label = "\(s.displayLabel) – \(priceStr)"
        onSelectionChanged(R9SubSelection(payload: payload, label: label, price: s.price))
    }

    // MARK: Daycare

    private func daycarePicker(listing: [String: Any]) -> some View {
        let sessions = daycareSessionTypes(listing: listing)
        return Group {
            if sessions.isEmpty {
                EmptyView()
            } else {
                section(title: "Choose session", icon: "sun.and.horizon") {
                    ForEach(sessions, id: \.id) { s in
                        radioRow(
                            label: s.displayLabel,
                            price: s.price,
                            isSelected: daycareSessionTypeId == s.id,
                            isEnabled: true
                        ) {
                            daycareSessionTypeId = s.id
                            emitDaycareSelection(sessions: sessions)
                        }
                    }
                }
                .onAppear {
                    if daycareSessionTypeId == nil, let first = sessions.first {
                        daycareSessionTypeId = first.id
                        emitDaycareSelection(sessions: sessions)
                    }
                }
            }
        }
    }

    private func emitDaycareSelection(sessions: [SessionTypeRow]) {
        guard let id = daycareSessionTypeId, let s = sessions.first(where: { $0.id == id }) else {
            onSelectionChanged(nil)
            return
        }
        let payload: [String: Any] = ["daycare": ["sessionTypeId": s.id]]
        let priceStr = CurrencyFormatter.shared.formatPrice(s.price)
        let label = "\(s.displayLabel) – \(priceStr)"
        onSelectionChanged(R9SubSelection(payload: payload, label: label, price: s.price))
    }

    // MARK: Sitting (PET_SITTING / IN_SITTING / OUT_SITTING share visit-type contract)

    private func sittingPicker(listing: [String: Any]) -> some View {
        let visits = sittingVisitTypes(listing: listing)
        return Group {
            if visits.isEmpty {
                EmptyView()
            } else {
                section(title: "Choose visit", icon: "house") {
                    ForEach(visits, id: \.id) { v in
                        radioRow(
                            label: v.displayLabel,
                            price: v.price,
                            isSelected: sittingVisitTypeId == v.id,
                            isEnabled: true
                        ) {
                            sittingVisitTypeId = v.id
                            emitSittingSelection(visits: visits)
                        }
                    }
                }
                .onAppear {
                    if sittingVisitTypeId == nil, let first = visits.first {
                        sittingVisitTypeId = first.id
                        emitSittingSelection(visits: visits)
                    }
                }
            }
        }
    }

    private func emitSittingSelection(visits: [SessionTypeRow]) {
        guard let id = sittingVisitTypeId, let v = visits.first(where: { $0.id == id }) else {
            onSelectionChanged(nil)
            return
        }
        let payload: [String: Any] = ["petSitting": ["visitTypeId": v.id]]
        let priceStr = CurrencyFormatter.shared.formatPrice(v.price)
        let label = "\(v.displayLabel) – \(priceStr)"
        onSelectionChanged(R9SubSelection(payload: payload, label: label, price: v.price))
    }

    // MARK: - Shared UI Pieces

    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neutral20)
            )
        }
    }

    private func radioRow(label: String, price: Double?, isSelected: Bool, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Color.turquoise60 : .neutral50)

                Text(label)
                    .font(.subheadline)
                    .foregroundColor(isEnabled ? .white : .neutral50)

                Spacer()

                Text(price.map { CurrencyFormatter.shared.formatPrice($0) } ?? "—")
                    .font(.subheadline.bold())
                    .foregroundColor(isEnabled ? .success40 : .neutral50)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func roomRow(room: BoardingRoomRow, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Color.turquoise60 : .neutral50)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Sleeps \(room.capacity)")
                        .font(.caption)
                        .foregroundColor(.neutral60)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.shared.formatPrice(room.pricePerNight))
                        .font(.subheadline.bold())
                        .foregroundColor(.success40)
                    Text("/night")
                        .font(.caption2)
                        .foregroundColor(.neutral50)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func sizeDisplayName(_ code: String) -> String {
        switch code {
        case "S": return "Small"
        case "M": return "Medium"
        case "L": return "Large"
        case "XL": return "X-Large"
        default: return code
        }
    }
}

// MARK: - Raw-Firestore Sub-Config Parsers
//
// These parse the spec field names directly from a `[String: Any]` doc.
// Living separately from the existing iOS WalkServiceConfig / etc.
// model layer is intentional — those use different field names
// (variants vs durations, menuItems vs groomingMenu) and aren't wired
// to service_listings. R9 reads what the wizard / server actually write.

struct WalkDurationRow {
    let id: String
    let durationMinutes: Int
    let price: Double
    let label: String?

    var displayLabel: String {
        if let l = label, !l.isEmpty { return l }
        return "\(durationMinutes) min"
    }
}

struct GroomingMenuRow {
    let id: String
    let name: String
    /// Keyed by "S"|"M"|"L"|"XL" → price. Missing key = not offered for that size.
    let prices: [String: Double]
}

struct BoardingRoomRow {
    let id: String
    let name: String
    let pricePerNight: Double
    let capacity: Int
}

struct SessionTypeRow {
    let id: String
    let label: String
    let price: Double
    let durationMinutes: Int?

    var displayLabel: String {
        if let d = durationMinutes, d > 0 {
            return "\(label) (\(d) min)"
        }
        return label
    }
}

private func walkDurations(listing: [String: Any]) -> [WalkDurationRow] {
    guard let cfg = listing["walkConfig"] as? [String: Any],
          let arr = cfg["durations"] as? [[String: Any]] else { return [] }
    return arr.compactMap { dict -> WalkDurationRow? in
        let isActive = (dict["isActive"] as? Bool) ?? true
        guard isActive else { return nil }
        guard let id = dict["id"] as? String else { return nil }
        let mins = (dict["durationMinutes"] as? NSNumber)?.intValue ?? 0
        let price = (dict["price"] as? NSNumber)?.doubleValue ?? 0
        let label = dict["label"] as? String
        return WalkDurationRow(id: id, durationMinutes: mins, price: price, label: label)
    }
}

private func groomingMenu(listing: [String: Any]) -> [GroomingMenuRow] {
    guard let cfg = listing["groomingConfig"] as? [String: Any],
          let arr = cfg["groomingMenu"] as? [[String: Any]] else { return [] }
    return arr.compactMap { dict -> GroomingMenuRow? in
        let isActive = (dict["isActive"] as? Bool) ?? true
        guard isActive else { return nil }
        guard let id = dict["id"] as? String else { return nil }
        let name = dict["name"] as? String ?? "Service"
        var prices: [String: Double] = [:]
        if let raw = dict["prices"] as? [String: Any] {
            for (k, v) in raw {
                if let n = v as? NSNumber {
                    prices[k] = n.doubleValue
                }
            }
        }
        return GroomingMenuRow(id: id, name: name, prices: prices)
    }
}

private func groomingAcceptedSizes(listing: [String: Any]) -> [String] {
    guard let cfg = listing["groomingConfig"] as? [String: Any] else {
        return ["S", "M", "L", "XL"]
    }
    if let raw = cfg["acceptedSizes"] as? [String], !raw.isEmpty {
        return raw
    }
    return ["S", "M", "L", "XL"]
}

private func boardingRoomTypes(listing: [String: Any]) -> [BoardingRoomRow] {
    guard let cfg = listing["boardingConfig"] as? [String: Any],
          let arr = cfg["roomTypes"] as? [[String: Any]] else { return [] }
    return arr.compactMap { dict -> BoardingRoomRow? in
        let isActive = (dict["isActive"] as? Bool) ?? true
        guard isActive else { return nil }
        guard let id = dict["id"] as? String else { return nil }
        let name = dict["name"] as? String ?? "Room"
        let price = (dict["pricePerNight"] as? NSNumber)?.doubleValue ?? 0
        let capacity = (dict["capacity"] as? NSNumber)?.intValue
            ?? (dict["maxDogs"] as? NSNumber)?.intValue ?? 1
        return BoardingRoomRow(id: id, name: name, pricePerNight: price, capacity: capacity)
    }
}

private func trainingSessionTypes(listing: [String: Any]) -> [SessionTypeRow] {
    guard let cfg = listing["trainingConfig"] as? [String: Any],
          let arr = cfg["sessionTypes"] as? [[String: Any]] else { return [] }
    return arr.compactMap { dict -> SessionTypeRow? in
        let isActive = (dict["isActive"] as? Bool) ?? true
        guard isActive else { return nil }
        guard let id = dict["id"] as? String else { return nil }
        let label = dict["name"] as? String ?? dict["label"] as? String ?? "Session"
        let price = (dict["price"] as? NSNumber)?.doubleValue ?? 0
        let mins = (dict["duration"] as? NSNumber)?.intValue
            ?? (dict["durationMinutes"] as? NSNumber)?.intValue
        return SessionTypeRow(id: id, label: label, price: price, durationMinutes: mins)
    }
}

private func daycareSessionTypes(listing: [String: Any]) -> [SessionTypeRow] {
    guard let cfg = listing["daycareConfig"] as? [String: Any],
          let arr = cfg["sessionTypes"] as? [[String: Any]] else { return [] }
    return arr.compactMap { dict -> SessionTypeRow? in
        let isActive = (dict["isActive"] as? Bool) ?? true
        guard isActive else { return nil }
        // Spec: "Use id ?? type since some legacy docs only have type."
        guard let id = (dict["id"] as? String) ?? (dict["type"] as? String) else { return nil }
        let label = dict["label"] as? String ?? dict["name"] as? String ?? id
        let price = (dict["price"] as? NSNumber)?.doubleValue ?? 0
        let mins = (dict["durationMinutes"] as? NSNumber)?.intValue
        return SessionTypeRow(id: id, label: label, price: price, durationMinutes: mins)
    }
}

private func sittingVisitTypes(listing: [String: Any]) -> [SessionTypeRow] {
    guard let cfg = listing["petSittingConfig"] as? [String: Any] ?? listing["sittingConfig"] as? [String: Any],
          let arr = cfg["visitTypes"] as? [[String: Any]] else { return [] }
    return arr.compactMap { dict -> SessionTypeRow? in
        let isActive = (dict["isActive"] as? Bool) ?? true
        guard isActive else { return nil }
        // id-or-type fallback per spec.
        guard let id = (dict["id"] as? String) ?? (dict["type"] as? String) else { return nil }
        let label = dict["label"] as? String ?? dict["name"] as? String ?? id
        let price = (dict["price"] as? NSNumber)?.doubleValue ?? 0
        let mins = (dict["durationMinutes"] as? NSNumber)?.intValue
        return SessionTypeRow(id: id, label: label, price: price, durationMinutes: mins)
    }
}
