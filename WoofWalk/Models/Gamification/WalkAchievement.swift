import Foundation
import SwiftUI

struct WalkAchievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String // SF Symbol name
    let color: Color

    init(id: String = UUID().uuidString, title: String, description: String, icon: String, color: Color) {
        self.id = id; self.title = title; self.description = description; self.icon = icon; self.color = color
    }
}
