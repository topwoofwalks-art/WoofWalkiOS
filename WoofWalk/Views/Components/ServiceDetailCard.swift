import SwiftUI

// MARK: - Service Detail Card Dispatcher

/// Read-only card showing service-specific booking details.
/// Adapts content based on booking status (confirmed, in-progress, completed).
/// Matches Android's ServiceDetailCard composable.
struct ServiceDetailCard: View {
    let serviceType: BookingServiceType
    let bookingStatus: BookingStatus
    let serviceDetails: [String: Any]?

    var body: some View {
        switch serviceType {
        case .walk:
            WalkDetailCardView(status: bookingStatus, details: serviceDetails)
        case .grooming:
            GroomingDetailCardView(status: bookingStatus, details: serviceDetails)
        case .inSitting, .outSitting, .petSitting:
            SittingDetailCardView(status: bookingStatus, details: serviceDetails)
        case .boarding:
            BoardingDetailCardView(status: bookingStatus, details: serviceDetails)
        case .daycare:
            DaycareDetailCardView(status: bookingStatus, details: serviceDetails)
        case .training:
            TrainingDetailCardView(status: bookingStatus, details: serviceDetails)
        case .meetGreet:
            FallbackDetailCardView(title: "Meet & Greet Details", details: serviceDetails)
        }
    }
}

// MARK: - Card Shell

private struct CardShell<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: () -> Content

    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            Divider()
                .background(AppColors.Dark.outlineVariant.opacity(0.5))

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }
}

// MARK: - Detail Row

private struct DetailRowView: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
                    .lineLimit(3)
            }
            Spacer()
        }
    }
}

// MARK: - Section Dividers

private struct ResultsDivider: View {
    let label: String
    let color: Color

    var body: some View {
        HStack {
            Rectangle().fill(AppColors.Dark.outlineVariant).frame(height: 1)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
            Rectangle().fill(AppColors.Dark.outlineVariant).frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

private struct CompletedDivider: View {
    var body: some View {
        ResultsDivider(label: "Results", color: AppColors.Dark.primary)
    }
}

private struct LiveSessionDivider: View {
    var body: some View {
        ResultsDivider(label: "Live Session", color: Color(red: 0.3, green: 0.69, blue: 0.31))
    }
}

// MARK: - Service Chip

private struct ServiceChipView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(AppColors.Dark.primaryContainer.opacity(0.5))
            )
            .foregroundColor(AppColors.Dark.onPrimaryContainer)
    }
}

// MARK: - Empty Details

private struct EmptyDetails: View {
    var body: some View {
        Text("No additional details")
            .font(.subheadline)
            .foregroundColor(AppColors.Dark.onSurfaceVariant)
    }
}

// MARK: - Dict helpers

private extension Dictionary where Key == String, Value == Any {
    func str(_ key: String) -> String? {
        self[key] as? String
    }

    func intVal(_ key: String) -> Int? {
        if let i = self[key] as? Int { return i }
        if let d = self[key] as? Double { return Int(d) }
        if let s = self[key] as? String { return Int(s) }
        return nil
    }

    func number(_ key: String) -> Double? {
        if let d = self[key] as? Double { return d }
        if let i = self[key] as? Int { return Double(i) }
        if let s = self[key] as? String { return Double(s) }
        return nil
    }

    func stringList(_ key: String) -> [String]? {
        self[key] as? [String]
    }
}

// MARK: - 1. Walk Detail Card

private struct WalkDetailCardView: View {
    let status: BookingStatus
    let details: [String: Any]?

    var body: some View {
        CardShell(title: "Walk Details", icon: "figure.walk", iconColor: Color(red: 0.3, green: 0.69, blue: 0.31)) {
            if let details = details {
                if let loc = details.str("pickupLocation") {
                    DetailRowView(icon: "mappin.and.ellipse", label: "Pickup Location", value: loc)
                }
                if let dist = details.str("estimatedDistance") {
                    DetailRowView(icon: "ruler", label: "Estimated Distance", value: dist)
                }
                if let pace = details.str("pace") {
                    let route = details.str("routeType")
                    let pref = [pace, route].compactMap { $0 }.joined(separator: " - ")
                    DetailRowView(icon: "speedometer", label: "Walk Preference", value: pref)
                }

                if status == .completed {
                    CompletedDivider()
                    if let walked = details.str("distanceWalked") {
                        DetailRowView(icon: "ruler", label: "Distance Walked", value: walked)
                    }
                    if let dur = details.str("duration") {
                        DetailRowView(icon: "timer", label: "Duration", value: dur)
                    }
                    if let adherence = details.number("routeAdherence") {
                        RouteAdherenceBar(percentage: adherence)
                    }
                    if let photoCount = details.intVal("photosCount") {
                        DetailRowView(icon: "camera.fill", label: "Photos", value: "\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                    }
                }
            } else {
                EmptyDetails()
            }
        }
    }
}

// MARK: - 2. Grooming Detail Card

private struct GroomingDetailCardView: View {
    let status: BookingStatus
    let details: [String: Any]?

    var body: some View {
        CardShell(title: "Grooming Details", icon: "scissors", iconColor: Color(red: 0.61, green: 0.15, blue: 0.69)) {
            if let details = details {
                if let type = details.str("groomType") {
                    DetailRowView(icon: "scissors", label: "Groom Type", value: type)
                }
                if let coat = details.str("coatCondition") {
                    DetailRowView(icon: "pawprint.fill", label: "Coat Condition", value: coat)
                }
                if let services = details.stringList("additionalServices"), !services.isEmpty {
                    Text("Additional Services")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(services, id: \.self) { ServiceChipView(label: $0) }
                        }
                    }
                }

                if status == .inProgress {
                    LiveSessionDivider()
                    if let steps = details.stringList("steps"),
                       let currentStep = details.intVal("currentStep") {
                        GroomingStepProgressView(steps: steps, currentStep: currentStep)
                    }
                }

                if status == .completed {
                    CompletedDivider()
                    if let photos = details.intVal("beforeAfterPhotos") {
                        DetailRowView(icon: "photo.stack", label: "Before/After Photos", value: "\(photos) pair\(photos == 1 ? "" : "s")")
                    }
                    if let findings = details.str("healthFindings") {
                        HealthBanner(text: findings)
                    }
                }
            } else {
                EmptyDetails()
            }
        }
    }
}

// MARK: - 3. Sitting Detail Card

private struct SittingDetailCardView: View {
    let status: BookingStatus
    let details: [String: Any]?

    var body: some View {
        CardShell(title: "Sitting Details", icon: "house.fill", iconColor: .orange) {
            if let details = details {
                if let ci = details.str("checkIn") {
                    DetailRowView(icon: "calendar", label: "Check-in", value: ci)
                }
                if let co = details.str("checkOut") {
                    DetailRowView(icon: "calendar", label: "Check-out", value: co)
                }
                if let access = details.str("accessMethod") {
                    DetailRowView(icon: "key.fill", label: "Access Method", value: access)
                }
                if let feeding = details.str("feedingSchedule") {
                    DetailRowView(icon: "fork.knife", label: "Feeding Schedule", value: feeding)
                }
                if let meds = details.str("medicationSchedule") {
                    DetailRowView(icon: "pills.fill", label: "Medication Schedule", value: meds)
                }

                if status == .inProgress {
                    LiveSessionDivider()
                    if let completed = details.intVal("tasksCompletedToday"),
                       let total = details.intVal("totalTasksToday"), total > 0 {
                        TaskProgressView(label: "Tasks Completed Today", completed: completed, total: total)
                    }
                }

                if status == .completed {
                    CompletedDivider()
                    if let summary = details.str("dailySummary") {
                        DetailRowView(icon: "doc.text", label: "Daily Summary", value: summary)
                    }
                    if let total = details.intVal("totalTasksCompleted") {
                        DetailRowView(icon: "checkmark.circle.fill", label: "Total Tasks Completed", value: "\(total)")
                    }
                }
            } else {
                EmptyDetails()
            }
        }
    }
}

// MARK: - 4. Boarding Detail Card

private struct BoardingDetailCardView: View {
    let status: BookingStatus
    let details: [String: Any]?

    var body: some View {
        CardShell(title: "Boarding Details", icon: "bed.double.fill", iconColor: .blue) {
            if let details = details {
                if let ci = details.str("checkIn") {
                    DetailRowView(icon: "calendar", label: "Check-in", value: ci)
                }
                if let co = details.str("checkOut") {
                    DetailRowView(icon: "calendar", label: "Check-out", value: co)
                }
                if let room = details.str("roomType") {
                    let desc = details.str("roomDescription")
                    DetailRowView(icon: "bed.double", label: "Room Type", value: desc != nil ? "\(room) - \(desc!)" : room)
                }
                if let nights = details.intVal("stayDuration") {
                    DetailRowView(icon: "moon.stars.fill", label: "Stay Duration", value: "\(nights) night\(nights == 1 ? "" : "s")")
                }
                if let feeding = details.str("feedingSchedule") {
                    DetailRowView(icon: "fork.knife", label: "Feeding Schedule", value: feeding)
                }
                if let exercise = details.str("exercisePreference") {
                    DetailRowView(icon: "figure.run", label: "Exercise Preference", value: exercise)
                }

                if status == .inProgress {
                    LiveSessionDivider()
                    if let today = details.str("todayStatus") {
                        DetailRowView(icon: "sun.max.fill", label: "Today's Status", value: today)
                    }
                    if let medsDue = details.str("medicationDue") {
                        MedicationBanner(text: medsDue)
                    }
                    if let lastUpdate = details.str("lastUpdateTime") {
                        DetailRowView(icon: "clock.arrow.circlepath", label: "Last Update", value: lastUpdate)
                    }
                }

                if status == .completed {
                    CompletedDivider()
                    if let summary = details.str("totalStaySummary") {
                        DetailRowView(icon: "doc.text", label: "Stay Summary", value: summary)
                    }
                    if let incidents = details.str("incidents") {
                        IncidentBanner(text: incidents)
                    }
                }
            } else {
                EmptyDetails()
            }
        }
    }
}

// MARK: - 5. Daycare Detail Card

private struct DaycareDetailCardView: View {
    let status: BookingStatus
    let details: [String: Any]?

    var body: some View {
        CardShell(title: "Daycare Details", icon: "sun.and.horizon.fill", iconColor: Color(red: 0.91, green: 0.12, blue: 0.39)) {
            if let details = details {
                if let dropOff = details.str("dropOffTime") {
                    DetailRowView(icon: "clock", label: "Drop-off", value: dropOff)
                }
                if let pickup = details.str("pickupTime") {
                    DetailRowView(icon: "clock", label: "Pickup", value: pickup)
                }
                if let activity = details.str("activityPreference") {
                    DetailRowView(icon: "figure.run", label: "Activity Preference", value: activity)
                }
                if let social = details.str("socializationPreference") {
                    DetailRowView(icon: "person.3.fill", label: "Socialisation Preference", value: social)
                }

                if let days = details.stringList("weeklySchedule"), !days.isEmpty {
                    Text("Weekly Schedule")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(days, id: \.self) { ServiceChipView(label: $0) }
                        }
                    }
                }

                if status == .inProgress {
                    LiveSessionDivider()
                    if let mood = details.str("currentMood") {
                        DetailRowView(icon: "face.smiling", label: "Current Mood", value: mood)
                    }
                    if let nap = details.str("napStatus") {
                        DetailRowView(icon: "bed.double", label: "Nap Status", value: nap)
                    }
                    if let count = details.intVal("activitiesTodayCount") {
                        DetailRowView(icon: "figure.run", label: "Activities Today", value: "\(count)")
                    }
                }

                if status == .completed {
                    CompletedDivider()
                    if let summary = details.str("daySummary") {
                        DetailRowView(icon: "doc.text", label: "Day Summary", value: summary)
                    }
                    if let count = details.intVal("activityCount") {
                        DetailRowView(icon: "figure.run", label: "Total Activities", value: "\(count)")
                    }
                }
            } else {
                EmptyDetails()
            }
        }
    }
}

// MARK: - 6. Training Detail Card

private struct TrainingDetailCardView: View {
    let status: BookingStatus
    let details: [String: Any]?

    var body: some View {
        CardShell(title: "Training Details", icon: "star.fill", iconColor: Color(red: 0.47, green: 0.33, blue: 0.28)) {
            if let details = details {
                if let areas = details.stringList("focusAreas"), !areas.isEmpty {
                    Text("Focus Areas")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(areas, id: \.self) { ServiceChipView(label: $0) }
                        }
                    }
                }
                if let level = details.str("dogLevel") {
                    DetailRowView(icon: "star", label: "Dog's Level", value: level)
                }
                if let method = details.str("trainingMethod") {
                    DetailRowView(icon: "brain.head.profile", label: "Training Method", value: method)
                }
                if let goals = details.str("goals") {
                    DetailRowView(icon: "flag.fill", label: "Goals", value: goals)
                }
                if let sessionType = details.str("sessionType") {
                    DetailRowView(icon: "doc.plaintext", label: "Session Type", value: sessionType)
                }

                if status == .inProgress {
                    LiveSessionDivider()
                    if let skills = details.str("skillsBeingWorked") {
                        DetailRowView(icon: "figure.run", label: "Skills Being Worked", value: skills)
                    }
                    if let rate = details.str("currentSuccessRate") {
                        DetailRowView(icon: "chart.line.uptrend.xyaxis", label: "Current Success Rate", value: rate)
                    }
                }

                if status == .completed {
                    CompletedDivider()
                    if let improved = details.str("skillsImproved") {
                        DetailRowView(icon: "trophy.fill", label: "Skills Improved", value: improved)
                    }
                    if let homework = details.str("homeworkAssigned") {
                        DetailRowView(icon: "bookmark.fill", label: "Homework Assigned", value: homework)
                    }
                    if let next = details.str("nextSessionRecommendation") {
                        NextSessionBanner(text: next)
                    }
                }
            } else {
                EmptyDetails()
            }
        }
    }
}

// MARK: - Fallback Detail Card

private struct FallbackDetailCardView: View {
    let title: String
    let details: [String: Any]?

    var body: some View {
        CardShell(title: title, icon: "pawprint.fill", iconColor: AppColors.Dark.primary) {
            if let details = details {
                ForEach(Array(details.keys.sorted()), id: \.self) { key in
                    if let value = details[key] {
                        DetailRowView(
                            icon: "pawprint",
                            label: key.camelCaseToTitle,
                            value: "\(value)"
                        )
                    }
                }
            } else {
                EmptyDetails()
            }
        }
    }
}

// MARK: - Route Adherence Bar

private struct RouteAdherenceBar: View {
    let percentage: Double

    private var color: Color {
        if percentage >= 80 { return Color(red: 0.3, green: 0.69, blue: 0.31) }
        if percentage >= 50 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        .font(.subheadline)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                        .frame(width: 20)
                    Text("Route Adherence")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.Dark.surfaceVariant)
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(percentage / 100, 1)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Grooming Step Progress

private struct GroomingStepProgressView: View {
    let steps: [String]
    let currentStep: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(min(currentStep + 1, steps.count)) of \(steps.count)")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.Dark.primary)

            GeometryReader { geo in
                let progress = steps.isEmpty ? 0.0 : Double(currentStep + 1) / Double(steps.count)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.purple.opacity(0.12))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.purple)
                        .frame(width: geo.size.width * CGFloat(min(progress, 1)), height: 8)
                }
            }
            .frame(height: 8)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    Image(systemName: index < currentStep ? "checkmark.circle.fill" : index == currentStep ? "circle.inset.filled" : "circle")
                        .font(.caption)
                        .foregroundColor(
                            index < currentStep ? Color(red: 0.3, green: 0.69, blue: 0.31) :
                            index == currentStep ? Color.purple : AppColors.Dark.onSurfaceVariant
                        )
                    Text(step)
                        .font(.caption)
                        .foregroundColor(index <= currentStep ? AppColors.Dark.onSurface : AppColors.Dark.onSurfaceVariant)
                }
            }
        }
    }
}

// MARK: - Task Progress

private struct TaskProgressView: View {
    let label: String
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.Dark.primary)
            }

            GeometryReader { geo in
                let progress = total > 0 ? Double(completed) / Double(total) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.Dark.surfaceVariant).frame(height: 6)
                    Capsule().fill(AppColors.Dark.primary)
                        .frame(width: geo.size.width * CGFloat(min(progress, 1)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Alert Banners

private struct HealthBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.text.square.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading) {
                Text("Health Findings")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                Text(text)
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

private struct MedicationBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pills.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text("Medication Due")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
                Text(text)
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

private struct IncidentBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            VStack(alignment: .leading) {
                Text("Incidents")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
                Text(text)
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }
}

private struct NextSessionBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(AppColors.Dark.primary)
            VStack(alignment: .leading) {
                Text("Next Session Recommendation")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.Dark.primary)
                Text(text)
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.Dark.primaryContainer.opacity(0.3))
        )
    }
}

// MARK: - String Extension

private extension String {
    /// Convert camelCase to Title Case (e.g. "pickupLocation" -> "Pickup Location")
    var camelCaseToTitle: String {
        let result = self.unicodeScalars.reduce("") { acc, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) && !acc.isEmpty {
                return acc + " " + String(scalar)
            }
            return acc + String(scalar)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}
