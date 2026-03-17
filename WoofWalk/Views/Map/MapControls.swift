import SwiftUI
import MapKit

struct MapControls: View {
    @Binding var showSearchBar: Bool
    @Binding var showFilterSheet: Bool
    @Binding var isTorchOn: Bool
    @Binding var carLocation: CLLocationCoordinate2D?

    let onShowGuide: () -> Void
    let onLocateUser: () -> Void
    let onToggleTorch: () -> Void
    let onSaveCarLocation: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onShowGuide) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(.blue.opacity(0.8)))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showSearchBar.toggle() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Circle().fill(.regularMaterial))
                }

                Button(action: { showFilterSheet.toggle() }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Circle().fill(.regularMaterial))
                }

                Button(action: onLocateUser) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Circle().fill(.regularMaterial))
                }

                Button(action: onToggleTorch) {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title3)
                        .foregroundColor(isTorchOn ? .yellow : .primary)
                        .padding(8)
                        .background(Circle().fill(.regularMaterial))
                }

                Button(action: {
                    if carLocation == nil {
                        onSaveCarLocation()
                    }
                }) {
                    Image(systemName: "car.fill")
                        .font(.title3)
                        .foregroundColor(carLocation != nil ? .cyan : .primary)
                        .padding(8)
                        .background(Circle().fill(.regularMaterial))
                }
            }
        }
    }
}

struct SearchBarView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search places...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: searchText) { newValue in
                        viewModel.searchLocation(newValue)
                    }

                List(viewModel.searchResults) { result in
                    Button(action: {
                        viewModel.selectSearchResult(result)
                        dismiss()
                    }) {
                        VStack(alignment: .leading) {
                            Text(result.title)
                                .font(.headline)
                            Text(result.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct POIFilterSheet: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("POI Types")) {
                    ForEach(POI.POIType.allCases, id: \.self) { type in
                        Toggle(isOn: binding(for: type)) {
                            HStack {
                                Image(systemName: iconName(for: type))
                                    .foregroundColor(iconColor(for: type))
                                Text(displayName(for: type))
                            }
                        }
                    }
                }

                Section {
                    Button("Clear All Filters") {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter POIs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func binding(for type: POI.POIType) -> Binding<Bool> {
        Binding(
            get: { viewModel.selectedPOITypes.contains(type) },
            set: { isSelected in
                viewModel.togglePOIType(type)
            }
        )
    }

    private func displayName(for type: POI.POIType) -> String {
        type.displayName
    }

    private func iconName(for type: POI.POIType) -> String {
        type.iconName
    }

    private func iconColor(for type: POI.POIType) -> Color {
        POIMarkerView.markerColor(for: type)
    }
}

struct POIDetailSheet: View {
    let poi: POI
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(poi.title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(poi.desc)
                    .font(.body)

                HStack {
                    Label("\(poi.voteUp - poi.voteDown)", systemImage: "hand.thumbsup.fill")
                    Spacer()
                    if let createdAt = poi.createdAt {
                        Text(createdAt.dateValue(), style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Button(action: {
                    viewModel.navigateToPOI(poi)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Navigate Here")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    viewModel.removePOI(poi)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Not Here!")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AppGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    guideSection(
                        title: "Getting Started",
                        icon: "figure.walk",
                        items: [
                            "Tap the play button to start tracking your walk",
                            "Use the search icon to find nearby places",
                            "Filter POIs using the filter button",
                            "Tap on markers to see details"
                        ]
                    )

                    guideSection(
                        title: "Map Features",
                        icon: "map.fill",
                        items: [
                            "Blue line shows your current walk route",
                            "Purple line shows planned routes",
                            "Paw prints mark points along your route",
                            "Different colored markers show different POI types"
                        ]
                    )

                    guideSection(
                        title: "Quick Actions",
                        icon: "bolt.fill",
                        items: [
                            "Green bin icon: Quickly mark a dog bin",
                            "Orange bag icon: Drop a poo bag marker",
                            "Car icon: Save your parking location",
                            "Torch icon: Toggle flashlight"
                        ]
                    )

                    guideSection(
                        title: "Navigation",
                        icon: "arrow.triangle.turn.up.right.diamond.fill",
                        items: [
                            "Tap anywhere on map to plan a route",
                            "Choose 'Walk Here' for direct navigation",
                            "Choose 'Random Walk' for circular routes",
                            "Follow turn-by-turn guidance during walks"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("App Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func guideSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(item)
                    }
                    .font(.body)
                }
            }
        }
    }
}
