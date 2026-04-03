import SwiftUI

struct ProfileDogsSection: View {
    let dogs: [UnifiedDog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Dogs")
                .font(.headline)

            if dogs.isEmpty {
                Text("No dogs added yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(dogs) { dog in
                    NavigationLink(destination: DogStatsScreen(dog: dog)) {
                        DogCard(dog: dog)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}
