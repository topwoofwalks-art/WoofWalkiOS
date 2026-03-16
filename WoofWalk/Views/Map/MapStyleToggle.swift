import SwiftUI
import MapKit

enum WoofWalkMapStyle: String, CaseIterable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"

    @available(iOS 17.0, *)
    var mapStyle: MapStyle {
        switch self {
        case .standard: return .standard
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        }
    }

    var icon: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.americas"
        case .hybrid: return "square.stack.3d.up"
        }
    }
}

struct MapStyleToggle: View {
    @Binding var selectedStyle: WoofWalkMapStyle

    var body: some View {
        Menu {
            ForEach(WoofWalkMapStyle.allCases, id: \.self) { style in
                Button(action: { selectedStyle = style }) {
                    Label(style.rawValue, systemImage: style.icon)
                }
            }
        } label: {
            Image(systemName: selectedStyle.icon)
                .font(.title3)
                .foregroundColor(.primary)
                .padding(8)
                .background(Circle().fill(.regularMaterial))
        }
    }
}
