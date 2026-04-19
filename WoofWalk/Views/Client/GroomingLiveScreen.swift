import SwiftUI

struct GroomingLiveScreen: View {
    let sessionId: String

    @StateObject private var viewModel: GroomingLiveViewModel
    @Environment(\.dismiss) private var dismiss

    init(sessionId: String) {
        self.sessionId = sessionId
        _viewModel = StateObject(wrappedValue: GroomingLiveViewModel(sessionId: sessionId))
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
        .navigationTitle("Grooming Session")
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
                etaCard
                progressTracker
                if !viewModel.photos.isEmpty { photoFeed }
                if !viewModel.healthFindings.isEmpty { healthFindingsCard }
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
                Image(systemName: "scissors")
                    .font(.title2)
                    .foregroundColor(AppColors.Dark.onPrimaryContainer)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.groomerName)
                    .font(.body.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                Text("Grooming \(viewModel.dogName)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)

                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.status == "in_progress" ? Color.success60 : .orange60)
                        .frame(width: 8, height: 8)
                    Text(viewModel.statusDisplayText)
                        .font(.caption.bold())
                        .foregroundColor(viewModel.status == "in_progress" ? Color.success60 : .orange60)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - ETA Card

    private var etaCard: some View {
        HStack {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundColor(AppColors.Dark.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Time")
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                Text(viewModel.etaString)
                    .font(.body.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            Spacer()

            // Circular progress
            ZStack {
                Circle()
                    .stroke(AppColors.Dark.outlineVariant, lineWidth: 4)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: viewModel.progressFraction)
                    .stroke(AppColors.Dark.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(viewModel.progressFraction * 100))%")
                    .font(.caption2.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.primary.opacity(0.12))
        )
    }

    // MARK: - Progress Tracker (9 Steps)

    private var progressTracker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline indicator
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(stepColor(step))
                                .frame(width: 32, height: 32)
                            if step.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: step.icon)
                                    .font(.caption2)
                                    .foregroundColor(step.isActive ? .white : AppColors.Dark.onSurfaceVariant)
                            }
                        }

                        if index < viewModel.steps.count - 1 {
                            Rectangle()
                                .fill(step.isCompleted ? AppColors.Dark.primary : AppColors.Dark.outlineVariant)
                                .frame(width: 2, height: 24)
                        }
                    }

                    // Step info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.name)
                            .font(.subheadline.weight(step.isActive ? .bold : .regular))
                            .foregroundColor(
                                step.isCompleted || step.isActive
                                    ? AppColors.Dark.onSurface
                                    : AppColors.Dark.onSurfaceVariant
                            )

                        if let completedAt = step.completedAt {
                            Text(formatTime(completedAt))
                                .font(.caption)
                                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                        } else if step.isActive {
                            Text("In progress...")
                                .font(.caption)
                                .foregroundColor(AppColors.Dark.primary)
                        }
                    }
                    .padding(.top, 4)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    private func stepColor(_ step: GroomingStep) -> Color {
        if step.isCompleted { return AppColors.Dark.primary }
        if step.isActive { return Color.success60 }
        return AppColors.Dark.outlineVariant
    }

    // MARK: - Photo Feed

    private var photoFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            // Group by type
            let beforePhotos = viewModel.photos.filter { $0.type == "before" }
            let duringPhotos = viewModel.photos.filter { $0.type == "during" }
            let afterPhotos = viewModel.photos.filter { $0.type == "after" }

            if !beforePhotos.isEmpty {
                photoSection(title: "Before", photos: beforePhotos)
            }
            if !duringPhotos.isEmpty {
                photoSection(title: "During", photos: duringPhotos)
            }
            if !afterPhotos.isEmpty {
                photoSection(title: "After", photos: afterPhotos)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    private func photoSection(title: String, photos: [GroomingPhoto]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(AppColors.Dark.onSurfaceVariant)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        AsyncImage(url: URL(string: photo.url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                photoPlaceholder
                            default:
                                ProgressView()
                                    .frame(width: 120, height: 120)
                            }
                        }
                    }
                }
            }
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.Dark.outlineVariant)
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
            )
    }

    // MARK: - Health Findings

    private var healthFindingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.error60)
                Text("Health Findings")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            ForEach(viewModel.healthFindings) { finding in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: finding.severityIcon)
                        .foregroundColor(finding.severityColor)
                        .font(.subheadline)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title)
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.Dark.onSurface)
                        Text(finding.description)
                            .font(.caption)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                        Text(formatTime(finding.timestamp))
                            .font(.caption2)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant.opacity(0.7))
                    }

                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(finding.severityColor.opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Contact Buttons

    private var contactButtons: some View {
        HStack(spacing: 12) {
            // Call button
            Button {
                if let phone = viewModel.groomerPhone, let url = URL(string: "tel:\(phone)") {
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

            // Message button
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

// MARK: - Preview

#Preview {
    NavigationStack {
        GroomingLiveScreen(sessionId: "preview-123")
    }
    .preferredColorScheme(.dark)
}
