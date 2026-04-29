import SwiftUI
import FirebaseFirestore

// MARK: - Training Session Screen

struct TrainingSessionScreen: View {
    let sessionId: String

    @StateObject private var viewModel: TrainingSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAddExerciseSheet = false
    @State private var showAddHomeworkSheet = false
    @State private var showBehaviourSheet = false
    @State private var showCompletionSheet = false
    @State private var showLessonPlanSheet = false
    @State private var showPhotoCapture = false
    @State private var showNotesSheet = false
    @State private var editingExercise: ExerciseEntry?
    @State private var selectedTab = 0 // 0=Exercises, 1=Behaviour, 2=Homework, 3=Summary

    // MARK: - Theme

    private let tealAccent = Color(red: 0.6, green: 0.9, blue: 0.9)
    private let darkTeal = Color(red: 0.0, green: 0.59, blue: 0.53)

    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6)
    }

    init(sessionId: String) {
        self.sessionId = sessionId
        self._viewModel = StateObject(wrappedValue: TrainingSessionViewModel(sessionId: sessionId))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.session == nil {
                ProgressView("Loading session...")
            } else if let session = viewModel.session {
                VStack(spacing: 0) {
                    sessionHeader(session)
                    tabBar
                    tabContent(session)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(viewModel.error ?? "Session not found")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("Go Back") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(darkTeal)
                }
                .padding(32)
            }
        }
        .navigationTitle("Training Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(viewModel.session?.dogName ?? "Training")
                        .font(.subheadline.bold())
                    Text(viewModel.session?.trainingFocus.isEmpty == false ? viewModel.session!.trainingFocus : "Dog Training")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                timerBadge
            }
        }
        .sheet(isPresented: $showAddExerciseSheet) { addExerciseSheet }
        .sheet(isPresented: $showAddHomeworkSheet) { addHomeworkSheet }
        .sheet(isPresented: $showBehaviourSheet) { behaviourSheet }
        .sheet(isPresented: $showCompletionSheet) { completionSheet }
        .sheet(isPresented: $showLessonPlanSheet) { lessonPlanSheet }
        .sheet(isPresented: $showNotesSheet) { notesSheet }
        .sheet(isPresented: $showPhotoCapture) { photoCaptureSheet }
        .sheet(item: $editingExercise) { exercise in
            editExerciseSheet(exercise)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Timer Badge

    private var timerBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption)
            Text(viewModel.formatDuration(viewModel.elapsedTime))
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(darkTeal))
    }

    // MARK: - Session Header

    private func sessionHeader(_ session: TrainingSessionData) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(darkTeal.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(darkTeal)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.dogName)
                        .font(.headline)
                    HStack(spacing: 4) {
                        if !session.breed.isEmpty {
                            Text(session.breed)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("-")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(session.clientName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                statusBadge(session.status)
            }

            // Lesson plan chips
            if !session.lessonPlan.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(session.lessonPlan, id: \.self) { skill in
                            HStack(spacing: 4) {
                                Image(systemName: skill.icon)
                                    .font(.caption2)
                                Text(skill.displayName)
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(darkTeal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(darkTeal.opacity(0.15)))
                        }

                        Button {
                            showLessonPlanSheet = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Button {
                    showLessonPlanSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                        Text("Set Lesson Plan")
                            .font(.caption.bold())
                    }
                    .foregroundColor(darkTeal)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func statusBadge(_ status: TrainingSessionStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .scheduled: return ("Scheduled", .orange)
            case .inProgress: return ("In Progress", .green)
            case .completed: return ("Completed", .blue)
            case .cancelled: return ("Cancelled", .red)
            }
        }()

        return Text(label)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Exercises", icon: "dumbbell.fill", tab: 0)
            tabButton(title: "Behaviour", icon: "brain.head.profile", tab: 1)
            tabButton(title: "Homework", icon: "house.fill", tab: 2)
            tabButton(title: "Summary", icon: "doc.text.fill", tab: 3)
        }
        .background(cardBackground)
    }

    private func tabButton(title: String, icon: String, tab: Int) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2.bold())
            }
            .foregroundColor(selectedTab == tab ? darkTeal : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedTab == tab ? darkTeal.opacity(0.1) : Color.clear)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(_ session: TrainingSessionData) -> some View {
        switch selectedTab {
        case 0: exercisesTab(session)
        case 1: behaviourTab(session)
        case 2: homeworkTab(session)
        case 3: summaryTab(session)
        default: EmptyView()
        }
    }

    // MARK: - Exercises Tab

    private func exercisesTab(_ session: TrainingSessionData) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                if session.exercises.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No exercises logged yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(session.exercises) { exercise in
                        exerciseCard(exercise)
                    }
                }

                Button {
                    showAddExerciseSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(darkTeal))
                }

                // Quick actions row
                HStack(spacing: 12) {
                    quickActionButton("Photo", icon: "camera.fill") {
                        showPhotoCapture = true
                    }
                    quickActionButton("Notes", icon: "note.text") {
                        showNotesSheet = true
                    }
                    if session.status == .inProgress {
                        quickActionButton("Complete", icon: "checkmark.circle.fill") {
                            showCompletionSheet = true
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(16)
        }
    }

    private func exerciseCard(_ exercise: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: exercise.skill.icon)
                        .font(.subheadline)
                        .foregroundColor(darkTeal)
                    Text(exercise.skillDisplayName)
                        .font(.headline)
                }

                Spacer()

                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...4, id: \.self) { star in
                        Image(systemName: star <= exercise.rating.stars ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(star <= exercise.rating.stars ? .yellow : .gray)
                    }
                }
            }

            // Success rate
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Success Rate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(exercise.successRatePercent)%")
                            .font(.title3.bold())
                        Text("(\(exercise.successfulAttempts)/\(exercise.totalAttempts))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Skill progress
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Skill Level")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(exercise.skillLevelBefore.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(exercise.hasProgressed ? .green : .secondary)
                        Text(exercise.skillLevelAfter.displayName)
                            .font(.caption.bold())
                            .foregroundColor(exercise.hasProgressed ? .green : .primary)
                    }
                }
            }

            // Progress bar
            ProgressView(value: exercise.successRate)
                .tint(exercise.successRate >= 0.7 ? .green : exercise.successRate >= 0.4 ? .orange : .red)

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    editingExercise = exercise
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption2)
                        Text("Edit")
                            .font(.caption.bold())
                    }
                    .foregroundColor(darkTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(darkTeal.opacity(0.1)))
                }

                Button {
                    viewModel.removeExercise(exercise.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption2)
                        Text("Remove")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
    }

    private func quickActionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.caption2.bold())
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
        }
    }

    // MARK: - Behaviour Tab

    private func behaviourTab(_ session: TrainingSessionData) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Focus level
                behaviourCard(
                    title: "Focus Level",
                    icon: "eye.fill",
                    value: session.behaviourObservations.focusLevel.displayName,
                    color: focusColor(session.behaviourObservations.focusLevel)
                )

                // Energy level
                behaviourCard(
                    title: "Energy Level",
                    icon: "bolt.fill",
                    value: session.behaviourObservations.energyLevel.displayName,
                    color: energyColor(session.behaviourObservations.energyLevel)
                )

                // Reactivity notes
                if !session.behaviourObservations.reactivityNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.orange)
                            Text("Reactivity")
                                .font(.subheadline.bold())
                        }
                        Text(session.behaviourObservations.reactivityNotes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
                }

                // Confidence notes
                if !session.behaviourObservations.confidenceNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.blue)
                            Text("Confidence")
                                .font(.subheadline.bold())
                        }
                        Text(session.behaviourObservations.confidenceNotes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
                }

                Button {
                    showBehaviourSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle.fill")
                        Text("Update Observations")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(darkTeal))
                }

                Spacer(minLength: 40)
            }
            .padding(16)
        }
    }

    private func behaviourCard(title: String, icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }

            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
    }

    private func focusColor(_ level: FocusLevel) -> Color {
        switch level {
        case .easilyDistracted: return .red
        case .moderate: return .orange
        case .excellent: return .green
        }
    }

    private func energyColor(_ level: EnergyLevel) -> Color {
        switch level {
        case .low: return .blue
        case .moderate: return .green
        case .high: return .orange
        case .hyperactive: return .red
        }
    }

    // MARK: - Homework Tab

    private func homeworkTab(_ session: TrainingSessionData) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                if session.homework.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "house")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No homework assigned yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(session.homework) { item in
                        homeworkCard(item)
                    }
                }

                Button {
                    showAddHomeworkSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Homework")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(darkTeal))
                }

                Spacer(minLength: 40)
            }
            .padding(16)
        }
    }

    private func homeworkCard(_ item: HomeworkItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(darkTeal)
                Text(item.exercise)
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    viewModel.removeHomework(item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if !item.frequency.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(item.frequency)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !item.tips.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text(item.tips)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
    }

    // MARK: - Summary Tab

    private func summaryTab(_ session: TrainingSessionData) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats overview
                HStack(spacing: 0) {
                    summaryStatItem(value: "\(session.exercises.count)", label: "Exercises", icon: "dumbbell.fill")
                    Divider().frame(height: 32)
                    summaryStatItem(
                        value: session.exercises.isEmpty ? "-" : "\(avgSuccessRate(session))%",
                        label: "Avg Success",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                    Divider().frame(height: 32)
                    summaryStatItem(value: "\(session.homework.count)", label: "Homework", icon: "house.fill")
                    Divider().frame(height: 32)
                    summaryStatItem(value: "\(session.photoUrls.count)", label: "Photos", icon: "camera.fill")
                }
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))

                // Session notes
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(tealAccent)
                        Text("Session Notes")
                            .font(.subheadline.bold())
                    }

                    if session.sessionNotes.isEmpty {
                        Text("No notes added yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(session.sessionNotes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showNotesSheet = true
                    } label: {
                        Text("Edit Notes")
                            .font(.caption.bold())
                            .foregroundColor(darkTeal)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))

                // Next session recommendations
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.forward.circle")
                            .foregroundColor(tealAccent)
                        Text("Next Session")
                            .font(.subheadline.bold())
                    }

                    if session.nextSessionRecommendations.isEmpty {
                        Text("No recommendations yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(session.nextSessionRecommendations)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))

                // Photos
                if !session.photoUrls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(tealAccent)
                            Text("Session Photos (\(session.photoUrls.count))")
                                .font(.subheadline.bold())
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(session.photoUrls.enumerated()), id: \.offset) { _, _ in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(darkTeal.opacity(0.2))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(darkTeal)
                                        )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
                }

                // Complete / Report button
                if session.status == .inProgress {
                    Button {
                        showCompletionSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete Session & Send Report")
                                .font(.body.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
                    }
                } else if session.status == .completed {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("Session Complete")
                            .font(.headline)
                        if session.reportSentToClient {
                            Text("Report sent to client")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                }

                Spacer(minLength: 40)
            }
            .padding(16)
        }
    }

    private func summaryStatItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(tealAccent)
                Text(value)
                    .font(.headline)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func avgSuccessRate(_ session: TrainingSessionData) -> Int {
        let rates: [Double] = session.exercises.map { $0.successRate }
        guard !rates.isEmpty else { return 0 }
        let sum: Double = rates.reduce(0.0, +)
        let mean: Double = sum / Double(rates.count)
        return Int(mean * 100)
    }

    // MARK: - Add Exercise Sheet

    private var addExerciseSheet: some View {
        NavigationStack {
            ExerciseFormSheet(exercise: nil) { exercise in
                viewModel.addExercise(exercise)
                showAddExerciseSheet = false
            }
        }
        .presentationDetents([.large])
    }

    private func editExerciseSheet(_ exercise: ExerciseEntry) -> some View {
        NavigationStack {
            ExerciseFormSheet(exercise: exercise) { updated in
                viewModel.updateExercise(updated)
                editingExercise = nil
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Add Homework Sheet

    private var addHomeworkSheet: some View {
        NavigationStack {
            HomeworkFormSheet { item in
                viewModel.addHomework(item)
                showAddHomeworkSheet = false
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Behaviour Sheet

    private var behaviourSheet: some View {
        NavigationStack {
            BehaviourFormSheet(
                initial: viewModel.session?.behaviourObservations ?? BehaviourObservations()
            ) { observations in
                viewModel.updateBehaviourObservations(observations)
                showBehaviourSheet = false
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Lesson Plan Sheet

    private var lessonPlanSheet: some View {
        NavigationStack {
            LessonPlanSheet(
                selected: viewModel.session?.lessonPlan ?? []
            ) { skills in
                viewModel.updateLessonPlan(skills)
                showLessonPlanSheet = false
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Notes Sheet

    private var notesSheet: some View {
        NavigationStack {
            TrainingNotesSheet(
                notes: viewModel.session?.sessionNotes ?? "",
                recommendations: viewModel.session?.nextSessionRecommendations ?? ""
            ) { notes, recommendations in
                viewModel.updateSessionNotes(notes)
                viewModel.updateNextSessionRecommendations(recommendations)
                showNotesSheet = false
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Photo Capture Sheet

    private var photoCaptureSheet: some View {
        TrainingPhotoCaptureSheet { _ in
            // Placeholder for photo upload flow
            let placeholderUrl = "local://training_photo_\(UUID().uuidString)"
            viewModel.addPhotoUrl(placeholderUrl)
            showPhotoCapture = false
        }
    }

    // MARK: - Completion Sheet

    private var completionSheet: some View {
        NavigationStack {
            TrainingCompletionSheet(
                report: viewModel.generateReport()
            ) {
                viewModel.completeSession()
                showCompletionSheet = false
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Exercise Form Sheet

private struct ExerciseFormSheet: View {
    let exercise: ExerciseEntry?
    let onSave: (ExerciseEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var skill: TrainingSkill
    @State private var customSkillName: String
    @State private var totalAttempts: Int
    @State private var successfulAttempts: Int
    @State private var rating: ExerciseRating
    @State private var notes: String
    @State private var skillLevelBefore: SkillLevel
    @State private var skillLevelAfter: SkillLevel

    init(exercise: ExerciseEntry?, onSave: @escaping (ExerciseEntry) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        self._skill = State(initialValue: exercise?.skill ?? .sit)
        self._customSkillName = State(initialValue: exercise?.customSkillName ?? "")
        self._totalAttempts = State(initialValue: exercise?.totalAttempts ?? 10)
        self._successfulAttempts = State(initialValue: exercise?.successfulAttempts ?? 5)
        self._rating = State(initialValue: exercise?.rating ?? .good)
        self._notes = State(initialValue: exercise?.notes ?? "")
        self._skillLevelBefore = State(initialValue: exercise?.skillLevelBefore ?? .none)
        self._skillLevelAfter = State(initialValue: exercise?.skillLevelAfter ?? .none)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Skill picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skill")
                        .font(.subheadline.bold())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(TrainingSkill.allCases, id: \.self) { s in
                            Button {
                                skill = s
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: s.icon)
                                        .font(.caption2)
                                    Text(s.displayName)
                                        .font(.caption.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(skill == s ? Color.teal.opacity(0.2) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(skill == s ? Color.teal : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if skill == .custom {
                        TextField("Custom skill name", text: $customSkillName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Divider()

                // Attempts
                VStack(alignment: .leading, spacing: 6) {
                    Text("Attempts")
                        .font(.subheadline.bold())

                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Stepper("\(totalAttempts)", value: $totalAttempts, in: 0...100)
                                .labelsHidden()
                            Text("\(totalAttempts)")
                                .font(.title3.bold())
                        }

                        VStack(spacing: 4) {
                            Text("Successful")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Stepper("\(successfulAttempts)", value: $successfulAttempts, in: 0...totalAttempts)
                                .labelsHidden()
                            Text("\(successfulAttempts)")
                                .font(.title3.bold())
                                .foregroundColor(.green)
                        }
                    }
                }

                Divider()

                // Rating
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rating")
                        .font(.subheadline.bold())

                    HStack(spacing: 8) {
                        ForEach(1...4, id: \.self) { star in
                            Button {
                                rating = ExerciseRating.fromStars(star)
                            } label: {
                                Image(systemName: star <= rating.stars ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(star <= rating.stars ? .yellow : .gray)
                            }
                        }
                        Text(rating.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Skill levels
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skill Level")
                        .font(.subheadline.bold())

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Before")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Before", selection: $skillLevelBefore) {
                                ForEach(SkillLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("After")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("After", selection: $skillLevelAfter) {
                                ForEach(SkillLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                Divider()

                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.subheadline.bold())

                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
            }
            .padding(16)
        }
        .navigationTitle(exercise == nil ? "Add Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let entry = ExerciseEntry(
                        id: exercise?.id ?? UUID().uuidString,
                        skill: skill,
                        customSkillName: customSkillName,
                        totalAttempts: totalAttempts,
                        successfulAttempts: min(successfulAttempts, totalAttempts),
                        rating: rating,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        skillLevelBefore: skillLevelBefore,
                        skillLevelAfter: skillLevelAfter
                    )
                    onSave(entry)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Homework Form Sheet

private struct HomeworkFormSheet: View {
    let onSave: (HomeworkItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exercise = ""
    @State private var frequency = ""
    @State private var tips = ""

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Exercise")
                    .font(.subheadline.bold())
                TextField("e.g. Practice recall in garden", text: $exercise)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Frequency")
                    .font(.subheadline.bold())
                TextField("e.g. 3 times daily, 5 minutes each", text: $frequency)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tips for Owner")
                    .font(.subheadline.bold())
                TextEditor(text: $tips)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            }

            Spacer()
        }
        .padding(16)
        .navigationTitle("Add Homework")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let item = HomeworkItem(
                        exercise: exercise.trimmingCharacters(in: .whitespacesAndNewlines),
                        frequency: frequency.trimmingCharacters(in: .whitespacesAndNewlines),
                        tips: tips.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    onSave(item)
                    dismiss()
                }
                .disabled(exercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Behaviour Form Sheet

private struct BehaviourFormSheet: View {
    let initial: BehaviourObservations
    let onSave: (BehaviourObservations) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var focusLevel: FocusLevel
    @State private var energyLevel: EnergyLevel
    @State private var reactivityNotes: String
    @State private var confidenceNotes: String

    init(initial: BehaviourObservations, onSave: @escaping (BehaviourObservations) -> Void) {
        self.initial = initial
        self.onSave = onSave
        self._focusLevel = State(initialValue: initial.focusLevel)
        self._energyLevel = State(initialValue: initial.energyLevel)
        self._reactivityNotes = State(initialValue: initial.reactivityNotes)
        self._confidenceNotes = State(initialValue: initial.confidenceNotes)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Focus Level")
                        .font(.subheadline.bold())
                    Picker("Focus", selection: $focusLevel) {
                        ForEach(FocusLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Energy Level")
                        .font(.subheadline.bold())
                    Picker("Energy", selection: $energyLevel) {
                        ForEach(EnergyLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reactivity Notes")
                        .font(.subheadline.bold())
                    TextEditor(text: $reactivityNotes)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Confidence Notes")
                        .font(.subheadline.bold())
                    TextEditor(text: $confidenceNotes)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
            }
            .padding(16)
        }
        .navigationTitle("Behaviour Observations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(BehaviourObservations(
                        focusLevel: focusLevel,
                        energyLevel: energyLevel,
                        reactivityNotes: reactivityNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidenceNotes: confidenceNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Lesson Plan Sheet

private struct LessonPlanSheet: View {
    let selected: [TrainingSkill]
    let onSave: ([TrainingSkill]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSkills: Set<TrainingSkill>

    init(selected: [TrainingSkill], onSave: @escaping ([TrainingSkill]) -> Void) {
        self.selected = selected
        self.onSave = onSave
        self._selectedSkills = State(initialValue: Set(selected))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(TrainingSkill.allCases.filter { $0 != .custom }, id: \.self) { skill in
                    Button {
                        if selectedSkills.contains(skill) {
                            selectedSkills.remove(skill)
                        } else {
                            selectedSkills.insert(skill)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: skill.icon)
                                .font(.caption)
                            Text(skill.displayName)
                                .font(.caption.bold())
                            Spacer()
                            if selectedSkills.contains(skill) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedSkills.contains(skill) ? Color.teal.opacity(0.15) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedSkills.contains(skill) ? Color.teal : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .navigationTitle("Lesson Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(Array(selectedSkills))
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Training Notes Sheet

private struct TrainingNotesSheet: View {
    let notes: String
    let recommendations: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editNotes: String
    @State private var editRecommendations: String

    init(notes: String, recommendations: String, onSave: @escaping (String, String) -> Void) {
        self.notes = notes
        self.recommendations = recommendations
        self.onSave = onSave
        self._editNotes = State(initialValue: notes)
        self._editRecommendations = State(initialValue: recommendations)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Session Notes")
                        .font(.subheadline.bold())
                    TextEditor(text: $editNotes)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Session Recommendations")
                        .font(.subheadline.bold())
                    TextEditor(text: $editRecommendations)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
            }
            .padding(16)
        }
        .navigationTitle("Session Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        editNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                        editRecommendations.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Training Photo Capture Sheet

private struct TrainingPhotoCaptureSheet: View {
    let onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationStack {
            if let image = capturedImage {
                VStack(spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()
                }
                .padding(16)
                .navigationTitle("Training Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Retake") { capturedImage = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Photo") {
                            onCapture(image)
                            dismiss()
                        }
                    }
                }
            } else {
                TrainingImagePicker(image: $capturedImage)
                    .ignoresSafeArea()
                    .onChange(of: capturedImage) { newValue in
                        if newValue == nil {
                            dismiss()
                        }
                    }
            }
        }
    }
}

private struct TrainingImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: TrainingImagePicker

        init(_ parent: TrainingImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Training Completion Sheet

private struct TrainingCompletionSheet: View {
    let report: String
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("Complete Session")
                    .font(.title3.bold())

                Text("This will mark the session as complete and send the report to the client.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Report Preview")
                        .font(.subheadline.bold())

                    Text(report)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                }

                Button {
                    onComplete()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Complete & Send Report")
                            .font(.body.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
                }

                Spacer(minLength: 20)
            }
            .padding(16)
        }
        .navigationTitle("Complete Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrainingSessionScreen(sessionId: "preview-session-id")
    }
    .preferredColorScheme(.dark)
}
