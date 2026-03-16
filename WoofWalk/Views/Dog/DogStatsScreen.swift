import SwiftUI

struct DogStatsScreen: View {
    let dog: DogProfile
    @StateObject private var viewModel = DogStatsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Dog header
                VStack(spacing: 8) {
                    Circle().fill(Color.neutral90).frame(width: 80, height: 80)
                        .overlay {
                            if let url = dog.photoUrl, let imgUrl = URL(string: url) {
                                AsyncImage(url: imgUrl) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "pawprint.fill").font(.largeTitle).foregroundColor(.turquoise60)
                            }
                        }
                    Text(dog.name).font(.title2.bold())
                    Text(dog.breed).font(.subheadline).foregroundColor(.secondary)

                    if let birthdate = dog.birthdate {
                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "yyyy-MM-dd"
                        if let date = formatter.date(from: birthdate) {
                            let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
                            Text("\(age) years old").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding()

                // Birthday countdown
                if let birthdate = dog.birthdate {
                    BirthdayCountdown(birthdateString: birthdate, dogName: dog.name)
                        .padding(.horizontal)
                }

                // Walk stats
                if let stats = viewModel.dogStats {
                    VStack(spacing: 12) {
                        Text("Walk Stats").font(.headline).frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            dogStatCard(title: "Total Walks", value: "\(stats.totalWalks)", icon: "figure.walk")
                            dogStatCard(title: "Distance", value: FormatUtils.formatDistance(Double(stats.totalDistanceMeters)), icon: "map")
                            dogStatCard(title: "Current Streak", value: "\(stats.currentStreak) days", icon: "flame.fill")
                            dogStatCard(title: "Best Streak", value: "\(stats.longestStreak) days", icon: "trophy")
                        }
                    }
                    .padding(.horizontal)

                    // Milestones
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Milestones").font(.headline)
                        ForEach(MilestoneRepository.allMilestones) { milestone in
                            let achieved = stats.achievedMilestones.contains(milestone.id)
                            HStack {
                                Image(systemName: achieved ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(achieved ? .green : .secondary)
                                Text(milestone.title).font(.subheadline)
                                Spacer()
                                Text("+\(milestone.pawPointsBonus)").font(.caption).foregroundColor(achieved ? .turquoise60 : .secondary)
                            }
                            .opacity(achieved ? 1.0 : 0.5)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("\(dog.name)'s Stats")
        .task { await viewModel.load(dogId: dog.id) }
    }

    private func dogStatCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(.turquoise60)
            Text(value).font(.headline)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}

@MainActor
class DogStatsViewModel: ObservableObject {
    @Published var dogStats: DogWalkStats?
    private let repository = MilestoneRepository()

    func load(dogId: String) async {
        dogStats = try? await repository.getDogWalkStats(dogId: dogId)
    }
}
