import SwiftUI

struct LivestockModeToggleButton: View {
    @Binding var isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: {
            isEnabled.toggle()
            onToggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isEnabled ? .green : .secondary)
                Text("Livestock Mode")
                    .font(.subheadline)
                    .fontWeight(isEnabled ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isEnabled ? Color.green.opacity(0.15) : Color(.systemGray6))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isEnabled ? Color.green : Color.clear, lineWidth: 1.5)
            )
        }
        .animation(.spring(response: 0.3), value: isEnabled)
    }
}

struct LivestockFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, .green)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

struct LivestockToolbar: View {
    @Binding var isDrawing: Bool
    let onDrawField: () -> Void
    let onViewHistory: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ToolbarButton(
                icon: "pencil.circle.fill",
                label: "Draw Field",
                isActive: isDrawing,
                action: onDrawField
            )

            ToolbarButton(
                icon: "clock.fill",
                label: "History",
                isActive: false,
                action: onViewHistory
            )

            ToolbarButton(
                icon: "gearshape.fill",
                label: "Settings",
                isActive: false,
                action: onSettings
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isActive ? .green : .primary)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isActive ? .green : .secondary)
            }
            .frame(width: 70)
        }
    }
}
