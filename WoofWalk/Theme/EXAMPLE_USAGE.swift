#if false
import SwiftUI

// MARK: - Example: Complete Screen Using Theme
struct WalkHistoryScreen: View {
    @Environment(\.woofWalkTheme) var theme
    @State private var selectedFilter = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    statsSection
                    filterChips
                    walksList
                }
                .paddingMD()
            }
            .background(theme.background)
            .navigationTitle("Walk History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Filter action
                    } label: {
                        ThemedIcon(AppIcons.filter, size: 20, color: .onSurface)
                    }
                }
            }
        }
    }

    // MARK: - Stats Section
    var statsSection: some View {
        HStack(spacing: Spacing.md) {
            statCard(
                icon: AppIcons.distance,
                value: "24.5 km",
                label: "This Week"
            )

            statCard(
                icon: AppIcons.duration,
                value: "8h 32m",
                label: "Total Time"
            )

            statCard(
                icon: AppIcons.steps,
                value: "18",
                label: "Walks"
            )
        }
    }

    func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            ThemedIcon(icon, size: 24, color: .primary)

            Text(value)
                .titleMedium()
                .foregroundColor(theme.onSurface)

            Text(label)
                .bodySmall()
                .foregroundColor(theme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle(elevation: 1)
    }

    // MARK: - Filter Chips
    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(["All", "This Week", "This Month", "Favorites"], id: \.self) { filter in
                    Text(filter)
                        .chipStyle(isSelected: filter == "All")
                        .onTapGesture {
                            // Handle selection
                        }
                }
            }
        }
    }

    // MARK: - Walks List
    var walksList: some View {
        VStack(spacing: Spacing.md) {
            walkListItem(
                date: "Today, 9:30 AM",
                distance: "3.2 km",
                duration: "45 min",
                dogName: "Max",
                rating: 5
            )

            walkListItem(
                date: "Yesterday, 6:15 PM",
                distance: "2.8 km",
                duration: "38 min",
                dogName: "Bella",
                rating: 4
            )

            walkListItem(
                date: "2 days ago, 8:00 AM",
                distance: "4.1 km",
                duration: "52 min",
                dogName: "Max",
                rating: 5
            )
        }
    }

    func walkListItem(
        date: String,
        distance: String,
        duration: String,
        dogName: String,
        rating: Int
    ) -> some View {
        HStack(spacing: Spacing.md) {
            // Dog icon
            ThemedIcon(AppIcons.dog, size: 40, color: .primary)

            // Walk details
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(date)
                    .bodySmall()
                    .foregroundColor(theme.onSurfaceVariant)

                Text("\(distance) • \(duration)")
                    .titleMedium()
                    .foregroundColor(theme.onSurface)

                HStack(spacing: Spacing.xxs) {
                    Text(dogName)
                        .bodySmall()
                        .foregroundColor(theme.onSurfaceVariant)

                    ForEach(0..<rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.secondary)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(theme.onSurfaceVariant)
        }
        .padding()
        .cardStyle(elevation: 1)
        .onTapGesture {
            // Navigate to walk details
        }
    }
}

// MARK: - Example: Form Screen Using Theme
struct DogProfileForm: View {
    @Environment(\.woofWalkTheme) var theme
    @State private var dogName = ""
    @State private var breed = ""
    @State private var age = ""
    @State private var weight = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    profilePhoto
                    formFields
                    actionButtons
                }
                .paddingMD()
            }
            .background(theme.background)
            .navigationTitle("Dog Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    var profilePhoto: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(theme.primaryContainer)
                    .frame(width: 120, height: 120)

                ThemedIcon(AppIcons.dog, size: 48, color: .primary)
            }

            Button("Change Photo") {
                // Photo picker
            }
            .buttonStyle(TextButtonStyle())
        }
    }

    var formFields: some View {
        VStack(spacing: Spacing.md) {
            formField(label: "Dog Name", text: $dogName, placeholder: "Enter name")
            formField(label: "Breed", text: $breed, placeholder: "Enter breed")
            formField(label: "Age (years)", text: $age, placeholder: "Enter age")
            formField(label: "Weight (kg)", text: $weight, placeholder: "Enter weight")
        }
    }

    func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .bodySmall()
                .foregroundColor(theme.onSurfaceVariant)

            TextField(placeholder, text: text)
                .font(AppTypography.bodyLarge)
                .foregroundColor(theme.onSurface)
                .padding()
                .background(theme.surfaceVariant)
                .cornerRadius(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(theme.outline, lineWidth: 1)
                )
        }
    }

    var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            Button("Save Profile") {
                // Save action
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)

            Button("Cancel") {
                // Cancel action
            }
            .buttonStyle(OutlinedButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .paddingLG()
    }
}

// MARK: - Example: Card-Based Dashboard
struct DashboardView: View {
    @Environment(\.woofWalkTheme) var theme

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                welcomeCard
                quickActionsCard
                upcomingWalksCard
                activitySummaryCard
            }
            .paddingMD()
        }
        .background(theme.background)
    }

    var welcomeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Good Morning!")
                    .headlineSmall()
                    .foregroundColor(theme.onPrimaryContainer)

                Text("Ready for a walk?")
                    .bodyMedium()
                    .foregroundColor(theme.onPrimaryContainer.opacity(0.8))
            }

            Spacer()

            ThemedIcon(AppIcons.sunny, size: 32, color: .custom(theme.onPrimaryContainer))
        }
        .padding()
        .background(theme.primaryContainer)
        .cornerRadius(CornerRadius.md)
    }

    var quickActionsCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Quick Actions")
                    .titleMedium()
                    .foregroundColor(theme.onSurface)

                Spacer()
            }

            HStack(spacing: Spacing.md) {
                quickActionButton(icon: AppIcons.startWalk, label: "Start Walk")
                quickActionButton(icon: AppIcons.addDog, label: "Add Dog")
                quickActionButton(icon: AppIcons.map, label: "Explore")
            }
        }
        .padding()
        .cardStyle(elevation: 2)
    }

    func quickActionButton(icon: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Button {
                // Action
            } label: {
                ThemedIcon(icon, size: 24, color: .onPrimaryContainer)
            }
            .fabStyle(size: .medium)

            Text(label)
                .bodySmall()
                .foregroundColor(theme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }

    var upcomingWalksCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Upcoming Walks")
                    .titleMedium()
                    .foregroundColor(theme.onSurface)

                Spacer()

                Button("See All") {
                    // See all action
                }
                .buttonStyle(TextButtonStyle())
            }

            walkItem(time: "3:00 PM", dog: "Max", location: "Central Park")
            walkItem(time: "6:30 PM", dog: "Bella", location: "River Trail")
        }
        .padding()
        .cardStyle(elevation: 2)
    }

    func walkItem(time: String, dog: String, location: String) -> some View {
        HStack(spacing: Spacing.sm) {
            ThemedIcon(AppIcons.clock, size: 20, color: .primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(time)
                    .bodyMedium()
                    .foregroundColor(theme.onSurface)

                Text("\(dog) • \(location)")
                    .bodySmall()
                    .foregroundColor(theme.onSurfaceVariant)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    var activitySummaryCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("This Week")
                    .titleMedium()
                    .foregroundColor(theme.onSurface)

                Spacer()

                CountBadge(count: 3)
            }

            HStack(spacing: Spacing.lg) {
                activityStat(value: "12", label: "Walks", icon: AppIcons.steps)
                activityStat(value: "18.5 km", label: "Distance", icon: AppIcons.distance)
                activityStat(value: "6h 20m", label: "Duration", icon: AppIcons.duration)
            }
        }
        .padding()
        .cardStyle(elevation: 2)
    }

    func activityStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.xs) {
            ThemedIcon(icon, size: 24, color: .secondary)

            Text(value)
                .titleSmall()
                .foregroundColor(theme.onSurface)

            Text(label)
                .bodySmall()
                .foregroundColor(theme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
struct ThemeExamples_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WalkHistoryScreen()
                .applyTheme()
                .preferredColorScheme(.light)
                .previewDisplayName("Walk History - Light")

            WalkHistoryScreen()
                .applyTheme()
                .preferredColorScheme(.dark)
                .previewDisplayName("Walk History - Dark")

            DogProfileForm()
                .applyTheme()
                .preferredColorScheme(.light)
                .previewDisplayName("Dog Form - Light")

            DashboardView()
                .applyTheme()
                .preferredColorScheme(.light)
                .previewDisplayName("Dashboard - Light")
        }
    }
}
#endif
