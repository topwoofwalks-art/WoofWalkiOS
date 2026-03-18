import SwiftUI

struct AppModeSwitcher: View {
    @State private var selectedMode: String
    var onModeChanged: (String) -> Void

    private let modes: [(id: String, label: String, icon: String, description: String)] = [
        ("public", "Public", "globe", "Browse walks and discover places"),
        ("client", "Client", "person.fill", "Book dog walking and pet services"),
        ("business", "Business", "briefcase.fill", "Manage your business on the go"),
    ]

    private let teal = Color(red: 0 / 255, green: 160 / 255, blue: 176 / 255)
    private let cardBackground = Color(red: 0.1, green: 0.2, blue: 0.22)

    init(initialMode: String = "public", onModeChanged: @escaping (String) -> Void = { _ in }) {
        _selectedMode = State(initialValue: initialMode)
        self.onModeChanged = onModeChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Mode")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 10) {
                ForEach(modes, id: \.id) { mode in
                    modeChip(mode: mode)
                }
            }

            if let current = modes.first(where: { $0.id == selectedMode }) {
                Text(current.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity)
                    .id(selectedMode)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func modeChip(mode: (id: String, label: String, icon: String, description: String)) -> some View {
        let isSelected = selectedMode == mode.id

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMode = mode.id
            }
            onModeChanged(mode.id)
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
                Image(systemName: mode.icon)
                    .font(.caption)
                Text(mode.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            .background(
                Capsule()
                    .fill(isSelected ? teal : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? teal : Color.white.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct AppModeSwitcher_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AppModeSwitcher(initialMode: "public")
            AppModeSwitcher(initialMode: "client")
            AppModeSwitcher(initialMode: "business")
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
