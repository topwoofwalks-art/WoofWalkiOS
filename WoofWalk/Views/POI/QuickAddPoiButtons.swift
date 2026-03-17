import SwiftUI
import CoreLocation

struct QuickAddPoiButtons: View {
    let location: CLLocationCoordinate2D
    let onPoiAdded: () -> Void

    @State private var showingSuccess = false
    @State private var addedType: PoiType?

    var body: some View {
        HStack(spacing: 12) {
            QuickAddButton(
                icon: "trash",
                label: "Bin",
                color: .orange
            ) {
                Task {
                    await quickAddPoi(type: .bin, title: "Waste Bin")
                }
            }

            QuickAddButton(
                icon: "drop.fill",
                label: "Water",
                color: .blue
            ) {
                Task {
                    await quickAddPoi(type: .water, title: "Water Source")
                }
            }

            QuickAddButton(
                icon: "exclamationmark.triangle",
                label: "Hazard",
                color: .red
            ) {
                Task {
                    await quickAddPoi(type: .hazard, title: "Hazard")
                }
            }
        }
        .padding(.horizontal)
        .alert("POI Added", isPresented: $showingSuccess) {
            Button("OK") {}
        } message: {
            if let type = addedType {
                Text("\(type.displayName) added successfully")
            }
        }
    }

    private func quickAddPoi(type: PoiType, title: String) async {
        let poi = POI(
            type: type.rawValue,
            title: title,
            desc: "Quickly added \(type.displayName.lowercased())",
            lat: location.latitude,
            lng: location.longitude
        )

        do {
            _ = try await PoiServiceRepository.shared.createPoi(poi)
            addedType = type
            showingSuccess = true
            onPoiAdded()
        } catch {
            print("Failed to add POI: \(error)")
        }
    }
}

struct QuickAddButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}
