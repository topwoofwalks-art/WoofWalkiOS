import SwiftUI
import FirebaseFirestore

// MARK: - Daycare Console Screen

struct DaycareConsoleScreen: View {
    let sessionId: String
    let bookingId: String
    let dogIds: [String]

    @StateObject private var viewModel = DaycareConsoleViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme

    private let tealAccent = Color(red: 0.6, green: 0.9, blue: 0.9)
    private let darkTeal = Color(red: 0.0, green: 0.59, blue: 0.53)

    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6)
    }

    private var surfaceBackground: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(.systemBackground)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            surfaceBackground.ignoresSafeArea()

            if viewModel.isLoading && viewModel.session == nil {
                ProgressView("Loading session...")
            } else if let session = viewModel.session {
                VStack(spacing: 0) {
                    sessionHeader(session)

                    if session.status == .completed {
                        completionSummaryView(session)
                    } else {
                        sessionProgressBar(session)
                        tabBar
                        tabContent(session)
                    }
                }

                // Speed dial FAB
                if session.isActive {
                    speedDialFAB
                }
            } else if let error = viewModel.error {
                errorView(error)
            }
        }
        .navigationTitle("Daycare Console")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !sessionId.isEmpty {
                viewModel.loadExistingSession(sessionId: sessionId)
            } else {
                viewModel.startSession(bookingId: bookingId, dogIds: dogIds)
            }
        }
        .sheet(isPresented: $viewModel.showFeedingSheet) { feedingSheet }
        .sheet(isPresented: $viewModel.showNapSheet) { napSheet }
        .sheet(isPresented: $viewModel.showPlaySheet) { playSheet }
        .sheet(isPresented: $viewModel.showSocialisationSheet) { socialisationSheet }
        .sheet(isPresented: $viewModel.showTemperamentSheet) { temperamentSheet }
        .sheet(isPresented: $viewModel.showNoteSheet) { noteSheet }
        .sheet(isPresented: $viewModel.showIncidentSheet) { incidentSheet }
        .sheet(isPresented: $viewModel.showCompletionSheet) { completionSheet }
        .sheet(isPresented: $viewModel.showPhotoCapture) { photoCaptureSheet }
        .alert("Error", isPresented: .constant(viewModel.error != nil && viewModel.session != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Session Header

    private func sessionHeader(_ session: DaycareSession) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(darkTeal.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(session.clientName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.primary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.clientName)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundColor(tealAccent)
                        Text("\(session.dogs.count) dog\(session.dogs.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Elapsed time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text(session.elapsedFormatted)
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(darkTeal))
            }

            if let instructions = session.specialInstructions, !instructions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.15)))
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Progress Bar

    private func sessionProgressBar(_ session: DaycareSession) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("Session Progress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(session.remainingFormatted) remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: session.progressPercent)
                .tint(darkTeal)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Stats Row

    private func statsRow(_ session: DaycareSession) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(viewModel.eventCount)", label: "Events", icon: "list.bullet")
            Divider().frame(height: 32)
            statItem(value: "\(viewModel.totalDogCount)", label: "Dogs", icon: "pawprint.fill")
            Divider().frame(height: 32)
            statItem(value: "\(viewModel.nappingDogCount)", label: "Napping", icon: "bed.double.fill")
            Divider().frame(height: 32)
            statItem(value: "\(viewModel.incidentCount)", label: "Incidents", icon: "exclamationmark.triangle")
        }
        .padding(.vertical, 8)
        .background(cardBackground)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
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

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Timeline", icon: "clock.fill", tab: 0)
            tabButton(title: "Dogs", icon: "pawprint.fill", tab: 1)
            tabButton(title: "Photos", icon: "photo.fill", tab: 2)
        }
        .background(cardBackground)
    }

    private func tabButton(title: String, icon: String, tab: Int) -> some View {
        Button {
            viewModel.selectTab(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.caption2.bold())
            }
            .foregroundColor(viewModel.selectedTab == tab ? darkTeal : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                viewModel.selectedTab == tab
                    ? darkTeal.opacity(0.1)
                    : Color.clear
            )
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(_ session: DaycareSession) -> some View {
        switch viewModel.selectedTab {
        case 0: timelineTab(session)
        case 1: dogsTab(session)
        case 2: photosTab(session)
        default: EmptyView()
        }
    }

    // MARK: - Timeline Tab

    private func timelineTab(_ session: DaycareSession) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                statsRow(session)
                    .padding(.bottom, 4)

                if session.events.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No events logged yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Use the quick-log button to record activities")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(session.events.reversed()) { event in
                        eventRow(event)
                    }
                }

                // Incidents section
                if !session.incidents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Incidents (\(session.incidents.count))")
                                .font(.subheadline.bold())
                        }
                        .padding(.top, 8)

                        ForEach(session.incidents) { incident in
                            incidentRow(incident)
                        }
                    }
                }

                Spacer(minLength: 100) // room for FAB
            }
            .padding(16)
        }
    }

    private func eventRow(_ event: DaycareEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.type.color)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: event.type.icon)
                        .font(.caption)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.type.label)
                        .font(.subheadline.bold())
                    if let dogName = event.dogName {
                        Text("- \(dogName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let temp = event.temperament {
                    Text("\(temp.emoji) \(temp.label)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(event.formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
    }

    private func incidentRow(_ incident: DaycareIncident) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(incident.severity.color)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(incident.type.label)
                        .font(.subheadline.bold())
                    Text(incident.severity.label)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(incident.severity.color))
                }

                Text(incident.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                if let action = incident.actionTaken, !action.isEmpty {
                    Text("Action: \(action)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()

            Text(incident.formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
    }

    // MARK: - Dogs Tab

    private func dogsTab(_ session: DaycareSession) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(session.dogs) { dog in
                    dogCard(dog, session: session)
                }
                Spacer(minLength: 100)
            }
            .padding(16)
        }
    }

    private func dogCard(_ dog: DaycareDog, session: DaycareSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(darkTeal.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(dog.name.prefix(1)).uppercased())
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(dog.name)
                            .font(.headline)
                        if dog.isNapping {
                            Text("Napping")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple))
                        }
                    }
                    if let breed = dog.breed {
                        Text(breed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(dog.currentTemperament.emoji) \(dog.currentTemperament.label)")
                        .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(dog.eventCount)")
                        .font(.title3.bold())
                    Text("events")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Special instructions
            if let instructions = dog.specialInstructions, !instructions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let feeding = dog.feedingInstructions, !feeding.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(feeding)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let meds = dog.medicationInstructions, !meds.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "pills.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(meds)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Quick actions for this dog
            HStack(spacing: 8) {
                quickDogAction("Water", icon: "drop.fill", color: .blue) {
                    viewModel.logEvent(type: .water, dogId: dog.id)
                }

                if dog.isNapping {
                    quickDogAction("Wake", icon: "sun.max.fill", color: .yellow) {
                        viewModel.logEvent(type: .napEnd, dogId: dog.id)
                    }
                } else {
                    quickDogAction("Nap", icon: "bed.double.fill", color: .purple) {
                        viewModel.logEvent(type: .napStart, dogId: dog.id)
                    }
                }

                quickDogAction("Pee", icon: "drop", color: .blue) {
                    viewModel.logEvent(type: .bathroomPee, dogId: dog.id)
                }

                quickDogAction("Poo", icon: "leaf.circle", color: .brown) {
                    viewModel.logEvent(type: .bathroomPoo, dogId: dog.id)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
    }

    private func quickDogAction(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.1)))
        }
    }

    // MARK: - Photos Tab

    private func photosTab(_ session: DaycareSession) -> some View {
        ScrollView {
            if session.photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No photos yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        viewModel.showPhotoCapture = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                            Text("Take Photo")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(darkTeal))
                    }
                }
                .padding(.top, 60)
            } else {
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(session.photos.enumerated()), id: \.offset) { _, _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(darkTeal.opacity(0.2))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(darkTeal)
                            )
                    }
                }
                .padding(16)
            }
            Spacer(minLength: 100)
        }
    }

    // MARK: - Speed Dial FAB

    private var speedDialFAB: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Spacer()

            if viewModel.fabExpanded {
                speedDialOption("Feed", icon: "fork.knife", color: .orange) {
                    viewModel.fabExpanded = false
                    viewModel.showFeedingSheet = true
                }
                speedDialOption("Water", icon: "drop.fill", color: .blue) {
                    viewModel.fabExpanded = false
                    viewModel.logEvent(type: .water, dogId: viewModel.selectedDogId)
                }
                speedDialOption("Nap", icon: "bed.double.fill", color: .purple) {
                    viewModel.fabExpanded = false
                    viewModel.showNapSheet = true
                }
                speedDialOption("Play", icon: "sportscourt.fill", color: .green) {
                    viewModel.fabExpanded = false
                    viewModel.showPlaySheet = true
                }
                speedDialOption("Bathroom", icon: "drop", color: .cyan) {
                    viewModel.fabExpanded = false
                    // Quick log a bathroom break
                    viewModel.logEvent(type: .bathroomPee, dogId: viewModel.selectedDogId)
                }
                speedDialOption("Social", icon: "heart.fill", color: .pink) {
                    viewModel.fabExpanded = false
                    viewModel.showSocialisationSheet = true
                }
                speedDialOption("Mood", icon: "brain.head.profile", color: .indigo) {
                    viewModel.fabExpanded = false
                    viewModel.showTemperamentSheet = true
                }
                speedDialOption("Photo", icon: "camera.fill", color: .teal) {
                    viewModel.fabExpanded = false
                    viewModel.showPhotoCapture = true
                }
                speedDialOption("Note", icon: "note.text", color: .gray) {
                    viewModel.fabExpanded = false
                    viewModel.showNoteSheet = true
                }
                speedDialOption("Incident", icon: "exclamationmark.triangle.fill", color: .red) {
                    viewModel.fabExpanded = false
                    viewModel.showIncidentSheet = true
                }
                speedDialOption("Complete", icon: "checkmark.circle.fill", color: .green) {
                    viewModel.fabExpanded = false
                    viewModel.showCompletionSheet = true
                }
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.fabExpanded.toggle()
                }
            } label: {
                Image(systemName: viewModel.fabExpanded ? "xmark" : "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(darkTeal))
                    .shadow(radius: 4)
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func speedDialOption(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(cardBackground))

                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(color))
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(error)
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Go Back") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(darkTeal)
        }
        .padding(32)
    }

    // MARK: - Completion Summary

    private func completionSummaryView(_ session: DaycareSession) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                    .padding(.top, 24)

                Text("Session Complete!")
                    .font(.title2.bold())

                VStack(spacing: 12) {
                    summaryRow(icon: "clock", label: "Duration", value: session.elapsedFormatted)
                    summaryRow(icon: "pawprint.fill", label: "Dogs", value: "\(session.dogs.count)")
                    summaryRow(icon: "list.bullet", label: "Events", value: "\(session.events.count)")
                    summaryRow(icon: "camera.fill", label: "Photos", value: "\(session.photos.count)")
                    if !session.incidents.isEmpty {
                        summaryRow(icon: "exclamationmark.triangle", label: "Incidents", value: "\(session.incidents.count)")
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))

                if let notes = session.sessionNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Notes")
                            .font(.subheadline.bold())
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
                }

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(darkTeal))
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(tealAccent)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    // MARK: - Feeding Sheet

    private var feedingSheet: some View {
        NavigationStack {
            DogAndTypePickerSheet(
                title: "Log Feeding",
                dogs: viewModel.session?.dogs ?? [],
                options: [
                    ("Breakfast", DaycareUpdateType.feedBreakfast),
                    ("Lunch", DaycareUpdateType.feedLunch),
                    ("Snack", DaycareUpdateType.feedSnack)
                ]
            ) { dogId, type in
                viewModel.logEvent(type: type, dogId: dogId)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Nap Sheet

    private var napSheet: some View {
        NavigationStack {
            DogAndTypePickerSheet(
                title: "Log Nap",
                dogs: viewModel.session?.dogs ?? [],
                options: [
                    ("Nap Started", DaycareUpdateType.napStart),
                    ("Nap Ended", DaycareUpdateType.napEnd)
                ]
            ) { dogId, type in
                viewModel.logEvent(type: type, dogId: dogId)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Play Sheet

    private var playSheet: some View {
        NavigationStack {
            DogAndTypePickerSheet(
                title: "Log Play",
                dogs: viewModel.session?.dogs ?? [],
                options: [
                    ("Solo Play (Indoor)", DaycareUpdateType.playSoloIndoor),
                    ("Solo Play (Outdoor)", DaycareUpdateType.playSoloOutdoor),
                    ("Group Play (Indoor)", DaycareUpdateType.playGroupIndoor),
                    ("Group Play (Outdoor)", DaycareUpdateType.playGroupOutdoor)
                ]
            ) { dogId, type in
                viewModel.logEvent(type: type, dogId: dogId)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Socialisation Sheet

    private var socialisationSheet: some View {
        NavigationStack {
            SocialisationLogSheet(dogs: viewModel.session?.dogs ?? []) { dogId, note in
                viewModel.logEvent(type: .socialisation, dogId: dogId, note: note)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Temperament Sheet

    private var temperamentSheet: some View {
        NavigationStack {
            TemperamentLogSheet(dogs: viewModel.session?.dogs ?? []) { dogId, temperament in
                viewModel.logEvent(type: .temperament, dogId: dogId, temperament: temperament)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Note Sheet

    private var noteSheet: some View {
        NavigationStack {
            NoteLogSheet { note in
                viewModel.logEvent(type: .note, note: note)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Incident Sheet

    private var incidentSheet: some View {
        NavigationStack {
            IncidentLogSheet(dogs: viewModel.session?.dogs ?? []) { type, description, severity, actionTaken, dogId in
                viewModel.logIncident(type: type, description: description, severity: severity, actionTaken: actionTaken, dogId: dogId)
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Completion Sheet

    private var completionSheet: some View {
        NavigationStack {
            CompletionSheet(
                autoSummary: viewModel.generateSessionSummary()
            ) { summary in
                viewModel.completeSession(summary: summary)
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Photo Capture Sheet

    private var photoCaptureSheet: some View {
        DaycarePhotoCaptureSheet(dogs: viewModel.session?.dogs ?? []) { image, dogId, caption in
            viewModel.uploadPhoto(image: image, dogId: dogId, caption: caption)
        }
    }
}

// MARK: - Supporting Sheet Views

private struct DogAndTypePickerSheet<T>: View {
    let title: String
    let dogs: [DaycareDog]
    let options: [(String, T)]
    let onSelect: (String?, T) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDogId: String?
    @State private var selectedOption: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Dog (optional)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    dogChip(name: "All Dogs", id: nil)
                    ForEach(dogs) { dog in
                        dogChip(name: dog.name, id: dog.id)
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider()

            Text("Select Type")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        selectedOption = index
                    } label: {
                        HStack {
                            Text(option.0)
                                .font(.subheadline)
                            Spacer()
                            if selectedOption == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedOption == index ? Color.green.opacity(0.1) : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 16)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Log") {
                    onSelect(selectedDogId, options[selectedOption].1)
                    dismiss()
                }
            }
        }
    }

    private func dogChip(name: String, id: String?) -> some View {
        Button {
            selectedDogId = id
        } label: {
            Text(name)
                .font(.caption.bold())
                .foregroundColor(selectedDogId == id ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selectedDogId == id ? Color(red: 0.0, green: 0.59, blue: 0.53) : Color(.systemGray5))
                )
        }
    }
}

private struct SocialisationLogSheet: View {
    let dogs: [DaycareDog]
    let onLog: (String?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDogId: String?
    @State private var note = ""

    var body: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dogs) { dog in
                        Button {
                            selectedDogId = dog.id
                        } label: {
                            Text(dog.name)
                                .font(.caption.bold())
                                .foregroundColor(selectedDogId == dog.id ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(selectedDogId == dog.id ? Color.pink : Color(.systemGray5))
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            TextEditor(text: $note)
                .frame(minHeight: 80)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 16)
        .navigationTitle("Log Socialisation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Log") {
                    onLog(selectedDogId, note)
                    dismiss()
                }
            }
        }
    }
}

private struct TemperamentLogSheet: View {
    let dogs: [DaycareDog]
    let onLog: (String?, DogTemperament) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDogId: String?
    @State private var selectedTemperament: DogTemperament = .happy

    var body: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dogs) { dog in
                        Button {
                            selectedDogId = dog.id
                        } label: {
                            Text(dog.name)
                                .font(.caption.bold())
                                .foregroundColor(selectedDogId == dog.id ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(selectedDogId == dog.id ? Color.indigo : Color(.systemGray5))
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(DogTemperament.allCases, id: \.self) { temp in
                    Button {
                        selectedTemperament = temp
                    } label: {
                        VStack(spacing: 4) {
                            Text(temp.emoji)
                                .font(.title)
                            Text(temp.label)
                                .font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTemperament == temp ? Color.indigo.opacity(0.2) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedTemperament == temp ? Color.indigo : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 16)
        .navigationTitle("Temperament Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Log") {
                    onLog(selectedDogId, selectedTemperament)
                    dismiss()
                }
                .disabled(selectedDogId == nil)
            }
        }
    }
}

private struct NoteLogSheet: View {
    let onLog: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add a session note")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $note)
                .frame(minHeight: 120)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

            Spacer()
        }
        .padding(16)
        .navigationTitle("Session Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onLog(note.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct IncidentLogSheet: View {
    let dogs: [DaycareDog]
    let onLog: (DaycareIncidentType, String, DaycareIncidentSeverity, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDogId: String?
    @State private var selectedType: DaycareIncidentType = .other
    @State private var selectedSeverity: DaycareIncidentSeverity = .low
    @State private var description = ""
    @State private var actionTaken = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Dog picker
                Text("Affected Dog")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dogs) { dog in
                            Button {
                                selectedDogId = dog.id
                            } label: {
                                Text(dog.name)
                                    .font(.caption.bold())
                                    .foregroundColor(selectedDogId == dog.id ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(selectedDogId == dog.id ? Color.red : Color(.systemGray5)))
                            }
                        }
                    }
                }

                // Incident type
                Text("Incident Type")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(DaycareIncidentType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            Text(type.label)
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedType == type ? Color.red.opacity(0.2) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedType == type ? Color.red : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Severity
                Text("Severity")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach(DaycareIncidentSeverity.allCases, id: \.self) { sev in
                        Button {
                            selectedSeverity = sev
                        } label: {
                            Text(sev.label)
                                .font(.caption.bold())
                                .foregroundColor(selectedSeverity == sev ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedSeverity == sev ? sev.color : Color(.systemGray6))
                                )
                        }
                    }
                }

                // Description
                Text("Description")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $description)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

                // Action taken
                Text("Action Taken")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $actionTaken)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            }
            .padding(16)
        }
        .navigationTitle("Log Incident")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Log") {
                    let action = actionTaken.trimmingCharacters(in: .whitespacesAndNewlines)
                    onLog(
                        selectedType,
                        description.trimmingCharacters(in: .whitespacesAndNewlines),
                        selectedSeverity,
                        action.isEmpty ? nil : action,
                        selectedDogId
                    )
                    dismiss()
                }
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct CompletionSheet: View {
    let autoSummary: String
    let onComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var summary: String

    init(autoSummary: String, onComplete: @escaping (String) -> Void) {
        self.autoSummary = autoSummary
        self.onComplete = onComplete
        self._summary = State(initialValue: autoSummary)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("Complete Session")
                    .font(.title3.bold())

                Text("Review and edit the session summary before completing.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $summary)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

                Button {
                    onComplete(summary)
                    dismiss()
                } label: {
                    Text("Complete Session")
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
                }
            }
            .padding(16)
        }
        .navigationTitle("Session Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
    }
}

private struct DaycarePhotoCaptureSheet: View {
    let dogs: [DaycareDog]
    let onCapture: (UIImage, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var selectedDogId: String?
    @State private var caption = ""
    @State private var showCamera = true

    var body: some View {
        NavigationStack {
            if let image = capturedImage {
                VStack(spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(dogs) { dog in
                                Button {
                                    selectedDogId = dog.id
                                } label: {
                                    Text(dog.name)
                                        .font(.caption.bold())
                                        .foregroundColor(selectedDogId == dog.id ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(selectedDogId == dog.id ? Color.teal : Color(.systemGray5)))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    TextField("Caption (optional)", text: $caption)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 16)
                .navigationTitle("Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let cap = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                            onCapture(image, selectedDogId, cap.isEmpty ? nil : cap)
                            dismiss()
                        }
                    }
                }
            } else {
                DaycareImagePicker(image: $capturedImage)
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

private struct DaycareImagePicker: UIViewControllerRepresentable {
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
        let parent: DaycareImagePicker

        init(_ parent: DaycareImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DaycareConsoleScreen(
            sessionId: "",
            bookingId: "preview-booking",
            dogIds: ["dog1", "dog2"]
        )
    }
    .preferredColorScheme(.dark)
}
