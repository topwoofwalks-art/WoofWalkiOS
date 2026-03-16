import SwiftUI
import MapKit

struct PoiDetailView: View {
    let poi: POI
    @StateObject private var viewModel: PoiDetailViewModel
    @Environment(\.dismiss) var dismiss

    init(poi: POI) {
        self.poi = poi
        _viewModel = StateObject(wrappedValue: PoiDetailViewModel(poi: poi))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !poi.photoUrls.isEmpty, let firstPhotoUrl = poi.photoUrls.first, let url = URL(string: firstPhotoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(height: 250)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: poi.poiType.iconName)
                            .font(.title2)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text(poi.title)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(poi.poiType.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    if !poi.desc.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.headline)
                            Text(poi.desc)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.headline)
                        Text(poi.displayLocation)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Map(coordinateRegion: .constant(
                        MKCoordinateRegion(
                            center: poi.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    ), annotationItems: [poi]) { poi in
                        MapMarker(coordinate: poi.coordinate, tint: .blue)
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button {
                            openInMaps()
                        } label: {
                            Label("Navigate", systemImage: "location.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            viewModel.showingReportSheet = true
                        } label: {
                            Label("Report", systemImage: "flag")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 24) {
                        Button {
                            Task {
                                await viewModel.votePoi(upvote: true)
                            }
                        } label: {
                            VStack {
                                Image(systemName: "hand.thumbsup.fill")
                                    .foregroundColor(.green)
                                Text("\(poi.voteUp)")
                                    .font(.caption)
                            }
                        }

                        Button {
                            Task {
                                await viewModel.votePoi(upvote: false)
                            }
                        } label: {
                            VStack {
                                Image(systemName: "hand.thumbsdown.fill")
                                    .foregroundColor(.red)
                                Text("\(poi.voteDown)")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comments")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.authorName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if let createdAt = comment.createdAt {
                                        Text(createdAt.dateValue(), style: .relative)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text(comment.text)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }

                        HStack(spacing: 8) {
                            TextField("Add a comment...", text: $viewModel.commentText)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                Task {
                                    await viewModel.addComment()
                                }
                            } label: {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.blue)
                            }
                            .disabled(viewModel.commentText.isEmpty)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("POI Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Report POI", isPresented: $viewModel.showingReportSheet) {
            Button("Not Here") {
                Task {
                    await viewModel.reportPoiMissing()
                }
            }
            Button("Inappropriate") {
                Task {
                    await viewModel.reportPoi(reason: "Inappropriate content")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Why are you reporting this POI?")
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {}
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: poi.coordinate))
        mapItem.name = poi.title
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
