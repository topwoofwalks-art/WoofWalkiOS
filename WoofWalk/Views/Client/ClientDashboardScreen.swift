import SwiftUI

struct ClientDashboardScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // My dogs section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("My Dogs")
                            .font(.title2.bold())
                        Spacer()
                        Button {
                            // Add dog action
                        } label: {
                            Label("Add Dog", systemImage: "plus")
                                .font(.subheadline.bold())
                        }
                    }

                    HStack(spacing: 16) {
                        Image(systemName: "dog.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No dogs added yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Add your dog to get started with bookings")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
                }
                .padding()

                // Next booking
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next Booking")
                        .font(.headline)

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No upcoming bookings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Book a walk for your dog")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }
                        Spacer()
                        Button {
                            // Book now action
                        } label: {
                            Text("Book")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.blue))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }
                .padding(.horizontal)

                // Your walker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Walker")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.green)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No walker assigned")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Find a walker in Discovery")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }
                .padding(.horizontal)

                // Recent activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)

                    VStack(spacing: 0) {
                        ForEach(["No walks yet", "No invoices", "No messages"], id: \.self) { item in
                            HStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 8, height: 8)
                                Text(item)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Home")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        ClientDashboardScreen()
    }
}
