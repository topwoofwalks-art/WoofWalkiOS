import SwiftUI

struct TrainingLiveScreen: View {
    let sessionId: String

    @StateObject private var viewModel: TrainingLiveViewModel
    @Environment(\.dismiss) private var dismiss

    init(sessionId: String) {
        self.sessionId = sessionId
        _viewModel = StateObject(wrappedValue: TrainingLiveViewModel(sessionId: sessionId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                mainContent
            }
        }
        .background(AppColors.Dark.background)
        .navigationTitle("Training Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColors.Dark.onSurface)
                }
            }
        }
        .toolbarBackground(AppColors.Dark.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(AppColors.Dark.primary)
            Text("Loading session...")
                .font(.subheadline)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
            Text(message)
                .font(.body)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
            Button("Go Back") { dismiss() }
                .font(.subheadline.bold())
                .foregroundColor(AppColors.Dark.onPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(AppColors.Dark.primary))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if !viewModel.skills.isEmpty { skillChips }
                if !viewModel.exercises.isEmpty { exerciseCards }
                if !viewModel.observations.isEmpty { observationsCard }
                if !viewModel.photos.isEmpty { photoSection }
                if !viewModel.homework.isEmpty { homeworkCard }
                if viewModel.isCompleted, let summary = viewModel.summary { summaryCard(summary) }
                contactButtons
            }
            .padding(16)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.Dark.primaryContainer)
                    .frame(width: 56, height: 56)
                Image(systemName: viewModel.sessionTypeIcon)
                    .font(.title2)
                    .foregroundColor(AppColors.Dark.onPrimaryContainer)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.trainerName)
                    .font(.body.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                Text("Training \(viewModel.dogName)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isCompleted ? AppColors.Dark.primary : Color.success60)
                            .frame(width: 8, height: 8)
                        Text(viewModel.statusDisplayText)
                            .font(.caption.bold())
                            .foregroundColor(viewModel.isCompleted ? AppColors.Dark.primary : Color.success60)
                    }

                    if !viewModel.isCompleted {
                        Text(viewModel.sessionDuration)
                            .font(.caption)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }
            }

            Spacer()

            if !viewModel.exercises.isEmpty {
                // Overall success rate
                ZStack {
                    Circle()
                        .stroke(AppColors.Dark.outlineVariant, lineWidth: 4)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: viewModel.overallSuccessRate)
                        .stroke(Color.success60, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    Text("\(viewModel.overallSuccessPercent)%")
                        .font(.caption2.bold())
                        .foregroundColor(AppColors.Dark.onSurface)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Skill Chips

    private var skillChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Skills Being Trained")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            FlowLayout(spacing: 8) {
                ForEach(viewModel.skills) { skill in
                    HStack(spacing: 4) {
                        Image(systemName: skill.icon)
                            .font(.caption2)
                        Text(skill.name)
                            .font(.caption.bold())
                    }
                    .foregroundColor(AppColors.Dark.onPrimaryContainer)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(AppColors.Dark.primaryContainer)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Exercise Progress Cards

    private var exerciseCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            ForEach(viewModel.exercises) { exercise in
                exerciseCard(exercise)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    private func exerciseCard(_ exercise: LiveTrainingExercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                Spacer()
                Text("\(exercise.successes)/\(exercise.attempts) attempts")
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
            }

            HStack(spacing: 16) {
                // Circular success rate
                ZStack {
                    Circle()
                        .stroke(AppColors.Dark.outlineVariant, lineWidth: 5)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: exercise.successRate)
                        .stroke(successColor(exercise.successRate), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(exercise.successPercent)%")
                        .font(.caption.bold())
                        .foregroundColor(AppColors.Dark.onSurface)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Level progression
                    HStack(spacing: 6) {
                        levelBadge(level: exercise.beforeLevel, label: "Before")
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                        levelBadge(level: exercise.afterLevel, label: "After")

                        if exercise.levelImproved {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(Color.success60)
                                .font(.caption)
                        }
                    }

                    if !exercise.notes.isEmpty {
                        Text(exercise.notes)
                            .font(.caption)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.Dark.background.opacity(0.5))
        )
    }

    private func levelBadge(level: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(level)")
                .font(.caption.bold())
                .foregroundColor(AppColors.Dark.onPrimaryContainer)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
        }
        .frame(width: 36, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.Dark.primaryContainer.opacity(0.6))
        )
    }

    private func successColor(_ rate: Double) -> Color {
        if rate >= 0.8 { return Color.success60 }
        if rate >= 0.5 { return .orange60 }
        return .error60
    }

    // MARK: - Behaviour Observations

    private var observationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Behaviour Observations")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            ForEach(viewModel.observations) { obs in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: obs.icon)
                        .foregroundColor(obs.color)
                        .font(.subheadline)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(obs.text)
                            .font(.subheadline)
                            .foregroundColor(AppColors.Dark.onSurface)
                        Text(formatTime(obs.timestamp))
                            .font(.caption2)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }

                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(obs.color.opacity(0.08))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Photos

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.photos) { photo in
                        VStack(spacing: 4) {
                            AsyncImage(url: URL(string: photo.url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.Dark.outlineVariant)
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                                        )
                                default:
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                }
                            }

                            if !photo.caption.isEmpty {
                                Text(photo.caption)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                                    .lineLimit(1)
                                    .frame(width: 120)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Homework Card

    private var homeworkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.orange60)
                Text("Homework")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            ForEach(viewModel.homework) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.Dark.onSurface)
                        Spacer()
                        Text(frequencyLabel(item.frequency))
                            .font(.caption2.bold())
                            .foregroundColor(.orange60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange60.opacity(0.15)))
                    }

                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(item.durationMinutes) min per session")
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange60.opacity(0.06))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    private func frequencyLabel(_ frequency: String) -> String {
        switch frequency {
        case "daily": return "Daily"
        case "3x_week": return "3x/week"
        case "weekly": return "Weekly"
        default: return frequency.capitalized
        }
    }

    // MARK: - Session Summary

    private func summaryCard(_ summary: TrainingSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(AppColors.Dark.primary)
                Text("Session Summary")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            if !summary.overallProgress.isEmpty {
                Text(summary.overallProgress)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            if !summary.keyWins.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Wins")
                        .font(.caption.bold())
                        .foregroundColor(Color.success60)
                    ForEach(summary.keyWins, id: \.self) { win in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(Color.success60)
                            Text(win)
                                .font(.caption)
                                .foregroundColor(AppColors.Dark.onSurface)
                        }
                    }
                }
            }

            if !summary.areasToWork.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Areas to Work On")
                        .font(.caption.bold())
                        .foregroundColor(.orange60)
                    ForEach(summary.areasToWork, id: \.self) { area in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundColor(.orange60)
                            Text(area)
                                .font(.caption)
                                .foregroundColor(AppColors.Dark.onSurface)
                        }
                    }
                }
            }

            if !summary.nextSessionFocus.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Session Focus")
                        .font(.caption.bold())
                        .foregroundColor(AppColors.Dark.primary)
                    Text(summary.nextSessionFocus)
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurface)
                }
            }

            if !summary.trainerNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trainer Notes")
                        .font(.caption.bold())
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    Text(summary.trainerNotes)
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.primary.opacity(0.08))
        )
    }

    // MARK: - Contact Buttons

    private var contactButtons: some View {
        HStack(spacing: 12) {
            Button {
                if let phone = viewModel.trainerPhone, let url = URL(string: "tel:\(phone)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                    Text("Call")
                        .font(.subheadline.bold())
                }
                .foregroundColor(AppColors.Dark.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.Dark.primary, lineWidth: 1)
                )
            }

            Button {
                // Navigate to chat
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption)
                    Text("Message")
                        .font(.subheadline.bold())
                }
                .foregroundColor(AppColors.Dark.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.Dark.primary)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout (for skill chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrainingLiveScreen(sessionId: "preview-123")
    }
    .preferredColorScheme(.dark)
}
