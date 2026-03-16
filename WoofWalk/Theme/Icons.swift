import SwiftUI

// MARK: - App Icons
// SF Symbols and custom icon mappings

struct AppIcons {
    // MARK: - Navigation
    static let home = "house.fill"
    static let map = "map.fill"
    static let profile = "person.fill"
    static let social = "bubble.left.and.bubble.right.fill"
    static let settings = "gearshape.fill"

    // MARK: - Walk Actions
    static let startWalk = "play.circle.fill"
    static let pauseWalk = "pause.circle.fill"
    static let stopWalk = "stop.circle.fill"
    static let resumeWalk = "play.circle.fill"

    // MARK: - Map
    static let location = "location.fill"
    static let compass = "location.north.fill"
    static let route = "map"
    static let pin = "mappin.circle.fill"
    static let currentLocation = "location.circle.fill"

    // MARK: - Dog/Pet
    static let dog = "pawprint.fill"
    static let addDog = "plus.circle.fill"
    static let dogProfile = "pawprint.circle.fill"

    // MARK: - POI Types
    static let park = "leaf.fill"
    static let waterFountain = "drop.fill"
    static let pooBagDrop = "trash.fill"
    static let veterinary = "cross.case.fill"
    static let petStore = "cart.fill"
    static let dogArea = "figure.walk"

    // MARK: - Stats
    static let distance = "arrow.left.and.right"
    static let duration = "timer"
    static let steps = "figure.walk"
    static let calories = "flame.fill"
    static let chart = "chart.bar.fill"

    // MARK: - Social
    static let like = "heart.fill"
    static let comment = "bubble.left.fill"
    static let share = "square.and.arrow.up"
    static let photo = "camera.fill"
    static let gallery = "photo.on.rectangle"

    // MARK: - General
    static let add = "plus"
    static let remove = "minus"
    static let edit = "pencil"
    static let delete = "trash"
    static let close = "xmark"
    static let check = "checkmark"
    static let chevronRight = "chevron.right"
    static let chevronLeft = "chevron.left"
    static let chevronDown = "chevron.down"
    static let chevronUp = "chevron.up"
    static let search = "magnifyingglass"
    static let filter = "line.3.horizontal.decrease.circle"
    static let refresh = "arrow.clockwise"
    static let info = "info.circle"
    static let warning = "exclamationmark.triangle.fill"
    static let error = "xmark.circle.fill"
    static let success = "checkmark.circle.fill"

    // MARK: - Authentication
    static let email = "envelope.fill"
    static let password = "lock.fill"
    static let faceID = "faceid"
    static let touchID = "touchid"
    static let logout = "arrow.right.square.fill"

    // MARK: - Weather
    static let sunny = "sun.max.fill"
    static let cloudy = "cloud.fill"
    static let rainy = "cloud.rain.fill"
    static let temperature = "thermometer"
}

// MARK: - Icon View Helper
struct ThemedIcon: View {
    @Environment(\.woofWalkTheme) var theme
    let name: String
    let size: CGFloat
    let color: IconColor

    enum IconColor {
        case primary
        case secondary
        case tertiary
        case error
        case onSurface
        case onSurfaceVariant
        case custom(Color)
    }

    init(_ name: String, size: CGFloat = 24, color: IconColor = .onSurface) {
        self.name = name
        self.size = size
        self.color = color
    }

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size))
            .foregroundColor(resolvedColor)
    }

    private var resolvedColor: Color {
        switch color {
        case .primary:
            return theme.primary
        case .secondary:
            return theme.secondary
        case .tertiary:
            return theme.tertiary
        case .error:
            return theme.error
        case .onSurface:
            return theme.onSurface
        case .onSurfaceVariant:
            return theme.onSurfaceVariant
        case .custom(let customColor):
            return customColor
        }
    }
}

// MARK: - Icon Size Presets
extension ThemedIcon {
    static func small(_ name: String, color: IconColor = .onSurface) -> ThemedIcon {
        ThemedIcon(name, size: 16, color: color)
    }

    static func medium(_ name: String, color: IconColor = .onSurface) -> ThemedIcon {
        ThemedIcon(name, size: 24, color: color)
    }

    static func large(_ name: String, color: IconColor = .onSurface) -> ThemedIcon {
        ThemedIcon(name, size: 32, color: color)
    }

    static func xlarge(_ name: String, color: IconColor = .onSurface) -> ThemedIcon {
        ThemedIcon(name, size: 48, color: color)
    }
}
