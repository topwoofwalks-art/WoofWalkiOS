import SwiftUI
import MapKit

struct HazardDetailScreen: View {
    let hazardId: String

    @State private var showConfirmReport: Bool = false

    private var hazard: HazardInfo {
        HazardInfo.sample(id: hazardId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Severity banner
                severityBanner

                // Map preview
                mapPreview

                // Details
                detailsSection

                // Reporter info
                reporterSection

                // Community votes
                communitySection

                // Actions
                actionsSection

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Hazard Detail")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Confirm Still Present", isPresented: $showConfirmReport) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") { }
        } message: {
            Text("Confirm this hazard is still present at this location?")
        }
    }

    // MARK: - Severity Banner

    private var severityBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(hazard.title)
                    .font(.headline)
                Text("Severity: \(hazard.severity)")
                    .font(.subheadline)
            }
            Spacer()
            Text(hazard.severity.uppercased())
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(severityColor)
                .cornerRadius(8)
        }
        .padding()
        .background(severityColor.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        Map(coordinateRegion: .constant(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )))
        .frame(height: 180)
        .cornerRadius(12)
        .padding(.horizontal)
        .allowsHitTesting(false)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Details")
                    .font(.headline)
                Spacer()
            }

            detailRow(icon: "mappin.circle", label: "Location", value: hazard.location)
            detailRow(icon: "calendar", label: "Reported", value: hazard.reportedDate)
            detailRow(icon: "clock", label: "Last confirmed", value: hazard.lastConfirmed)
            detailRow(icon: "tag", label: "Type", value: hazard.hazardType)

            if !hazard.description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(hazard.description)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }

    // MARK: - Reporter Section

    private var reporterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.accentColor)
                Text("Reported By")
                    .font(.headline)
                Spacer()
            }
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hazard.reporterName)
                        .font(.subheadline.bold())
                    Text("Community member")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Community Section

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.accentColor)
                Text("Community Reports")
                    .font(.headline)
                Spacer()
            }
            HStack(spacing: 24) {
                VStack {
                    Text("\(hazard.confirmCount)")
                        .font(.title2.bold())
                        .foregroundColor(.red)
                    Text("Confirmed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(hazard.resolvedCount)")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("Resolved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showConfirmReport = true
            } label: {
                Label("Confirm Still Present", systemImage: "exclamationmark.triangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button {
                // Mark resolved
            } label: {
                Label("Mark as Resolved", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var severityColor: Color {
        switch hazard.severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .green
        default: return .gray
        }
    }
}

// MARK: - Hazard Info Model

private struct HazardInfo {
    let id: String
    let title: String
    let severity: String
    let hazardType: String
    let location: String
    let description: String
    let reportedDate: String
    let lastConfirmed: String
    let reporterName: String
    let confirmCount: Int
    let resolvedCount: Int

    static func sample(id: String) -> HazardInfo {
        HazardInfo(
            id: id,
            title: "Broken Glass on Path",
            severity: "High",
            hazardType: "Debris / Sharp Objects",
            location: "Riverside Walk, near bench #3",
            description: "Broken glass scattered across the main footpath. Dangerous for dogs' paws. Area is approximately 2 metres wide.",
            reportedDate: "17 Mar 2026",
            lastConfirmed: "2 hours ago",
            reporterName: "Sarah T.",
            confirmCount: 5,
            resolvedCount: 1
        )
    }
}

// MARK: - Pub Detail Screen

struct PubDetailScreen: View {
    let pubId: String

    @State private var showDirections: Bool = false

    private var pub: PubInfo {
        PubInfo.sample(id: pubId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero image placeholder
                heroImage

                // Quick info
                quickInfo

                // Dog Policy
                dogPolicySection

                // Amenities
                amenitiesSection

                // Details
                detailsSection

                // Reviews
                reviewsSection

                // Actions
                actionsSection

                Spacer(minLength: 40)
            }
        }
        .navigationTitle(pub.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.brown.opacity(0.4), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack {
                Image(systemName: "mug.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.7))
                Text(pub.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .frame(height: 200)
    }

    // MARK: - Quick Info

    private var quickInfo: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(pub.rating)
                    .font(.headline)
                Text("\(pub.reviewCount) reviews")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text(pub.distance)
                    .font(.headline)
                Text("away")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Image(systemName: pub.isOpen ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(pub.isOpen ? .green : .red)
                Text(pub.isOpen ? "Open" : "Closed")
                    .font(.headline)
                Text(pub.hours)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Dog Policy

    private var dogPolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.green)
                Text("Dog Policy")
                    .font(.headline)
                Spacer()
                Text("Dog Friendly")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }

            VStack(spacing: 6) {
                policyRow(text: "Dogs welcome in beer garden", allowed: true)
                policyRow(text: "Dogs welcome in bar area", allowed: true)
                policyRow(text: "Dogs welcome in restaurant", allowed: false)
                policyRow(text: "Water bowls provided", allowed: true)
                policyRow(text: "Dog treats available", allowed: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func policyRow(text: String, allowed: Bool) -> some View {
        HStack {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(allowed ? .green : .red)
                .font(.caption)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Amenities

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Amenities")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                amenityItem(icon: "cup.and.saucer.fill", text: "Food Served")
                amenityItem(icon: "leaf.fill", text: "Beer Garden")
                amenityItem(icon: "wifi", text: "Free WiFi")
                amenityItem(icon: "car.fill", text: "Car Park")
                amenityItem(icon: "figure.child", text: "Family Friendly")
                amenityItem(icon: "fireplace.fill", text: "Open Fire")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func amenityItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.caption)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Details")
                    .font(.headline)
                Spacer()
            }

            detailRow(icon: "mappin", text: pub.address)
            detailRow(icon: "phone", text: pub.phone)
            detailRow(icon: "globe", text: pub.website)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.accentColor)
                Text("Dog Walker Reviews")
                    .font(.headline)
                Spacer()
            }

            ForEach(pub.reviews, id: \.name) { review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(review.name)
                            .font(.subheadline.bold())
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<review.stars, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    Text(review.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showDirections = true
            } label: {
                Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                // Share
            } label: {
                Label("Share with Friends", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .alert("Directions", isPresented: $showDirections) {
            Button("Open in Maps") { }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Open directions to \(pub.name) in Apple Maps?")
        }
    }
}

// MARK: - Pub Info Model

private struct PubInfo {
    let id: String
    let name: String
    let rating: String
    let reviewCount: Int
    let distance: String
    let isOpen: Bool
    let hours: String
    let address: String
    let phone: String
    let website: String
    let reviews: [PubReview]

    static func sample(id: String) -> PubInfo {
        PubInfo(
            id: id,
            name: "The Dog & Duck",
            rating: "4.5",
            reviewCount: 23,
            distance: "0.4 km",
            isOpen: true,
            hours: "11 AM - 11 PM",
            address: "42 High Street, London",
            phone: "020 7123 4567",
            website: "thedogandduck.co.uk",
            reviews: [
                PubReview(name: "Sarah T.", stars: 5, text: "Lovely pub, very welcoming to dogs. Bella got treats from the staff!"),
                PubReview(name: "Tom W.", stars: 4, text: "Good beer garden for dogs. Gets busy on weekends though."),
                PubReview(name: "Emma C.", stars: 5, text: "Best dog-friendly pub in the area. Water bowls at every table."),
            ]
        )
    }
}

private struct PubReview {
    let name: String
    let stars: Int
    let text: String
}
