import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

/// 5-step community-create wizard:
///   1. Type — pick a CommunityType
///   2. Basics — name + description + tags
///   3. Privacy — public / private / invite-only + cover photo
///   4. Type-specific — breed / location+map / sports / focus / generic
///   5. Review — confirm and create
///
/// On success, calls `onComplete(communityId)` — the caller (the list
/// screen) navigates to the new community's detail page.
struct CreateCommunityScreen: View {
    let onComplete: (String?) -> Void

    @StateObject private var viewModel = CommunityCreateViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var photosItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepProgress
                Divider()
                ScrollView {
                    Group {
                        switch viewModel.step {
                        case .type: typeStep
                        case .basics: basicsStep
                        case .privacy: privacyStep
                        case .typeSpecific: typeSpecificStep
                        case .review: reviewStep
                        }
                    }
                    .padding(20)
                }
                Divider()
                navButtons
            }
            .navigationTitle("New Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onComplete(nil)
                    }
                }
            }
            .onChange(of: viewModel.isSuccess) { isSuccess in
                if isSuccess {
                    dismiss()
                    onComplete(viewModel.createdCommunityId)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    // MARK: - Progress

    private var stepProgress: some View {
        let total = CreateCommunityStep.allCases.count
        let current = viewModel.step.stepNumber
        return VStack(spacing: 4) {
            HStack {
                Text("Step \(current) of \(total) — \(viewModel.step.title)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            ProgressView(value: Double(current), total: Double(total))
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
        }
    }

    private var navButtons: some View {
        HStack(spacing: 12) {
            if viewModel.step != .type {
                Button("Back") {
                    viewModel.previousStep()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if viewModel.step == .review {
                Button {
                    Task { await viewModel.createCommunity() }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        }
                        Text("Create Community")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isLoading)
            } else {
                Button("Next") {
                    viewModel.nextStep()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.canProceedFromCurrentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!viewModel.canProceedFromCurrentStep)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Step 1: Type

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What kind of community is this?")
                .font(.title3)
                .fontWeight(.bold)
            Text("Pick a type — it determines the type-specific tab and tools members get.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CommunityType.allCases) { type in
                    let isSelected = viewModel.type == type
                    let c = type.color
                    Button {
                        viewModel.type = type
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.iconSystemName)
                                .font(.system(size: 22))
                                .foregroundColor(Color(red: c.red, green: c.green, blue: c.blue))
                            Text(type.displayName)
                                .font(.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .multilineTextAlignment(.center)
                            Text(type.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(isSelected ? Color(red: c.red, green: c.green, blue: c.blue).opacity(0.18) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color(red: c.red, green: c.green, blue: c.blue) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Basics

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Community details")
                .font(.title3)
                .fontWeight(.bold)
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption).foregroundColor(.secondary)
                TextField("e.g. South London Cockapoo Club", text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Description").font(.caption).foregroundColor(.secondary)
                TextField("What's this community about?", text: $viewModel.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Rules (optional)").font(.caption).foregroundColor(.secondary)
                TextField("Be kind, no spam, etc.", text: $viewModel.rules, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
            }
            tagEditor
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags").font(.caption).foregroundColor(.secondary)
            TagInput(tags: $viewModel.tags)
        }
    }

    // MARK: - Step 3: Privacy + cover

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Who can see this community?")
                .font(.title3)
                .fontWeight(.bold)

            ForEach(CommunityPrivacy.allCases) { p in
                let isSelected = viewModel.privacy == p
                Button {
                    viewModel.privacy = p
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: p.iconSystemName)
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(p.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.vertical, 4)

            Text("Cover photo (optional)")
                .font(.subheadline)
                .fontWeight(.semibold)
            ZStack(alignment: .center) {
                if let data = viewModel.coverPhotoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 160)
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("Tap to choose")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if viewModel.isUploadingCover {
                    ProgressView().tint(.white)
                }
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.coverPhotoData != nil {
                    Button {
                        viewModel.coverPhotoData = nil
                        viewModel.coverPhotoUrl = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5).clipShape(Circle()))
                    }
                    .padding(8)
                }
            }
            PhotosPicker(selection: $photosItem, matching: .images) {
                Label(viewModel.coverPhotoData == nil ? "Choose photo" : "Replace photo",
                      systemImage: "photo")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .onChange(of: photosItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await viewModel.setCoverPhoto(imageData: data)
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Type specific

    private var typeSpecificStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(typeSpecificTitle)
                .font(.title3)
                .fontWeight(.bold)
            switch viewModel.type {
            case .breedSpecific: breedSelector
            case .localNeighbourhood: locationPicker
            case .dogSports: sportsSelector
            case .healthNutrition: focusSelector
            default:
                Text("No additional setup needed for \(viewModel.type.displayName) communities. Tap Next to review.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var typeSpecificTitle: String {
        switch viewModel.type {
        case .breedSpecific: return "Which breed?"
        case .localNeighbourhood: return "Where's the area?"
        case .dogSports: return "Which sports?"
        case .healthNutrition: return "Health & nutrition focus"
        default: return "Almost done"
        }
    }

    private var breedSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick the primary breed for this community.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Custom breed", text: Binding(
                get: { viewModel.breedFilter ?? "" },
                set: { viewModel.breedFilter = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CommunityCreateOptions.popularBreeds, id: \.self) { breed in
                        let isSelected = viewModel.breedFilter == breed
                        Button {
                            viewModel.breedFilter = breed
                        } label: {
                            Text(breed)
                                .font(.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                                .foregroundColor(isSelected ? .accentColor : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drop a pin in the centre of your area. Members nearby will see this community first.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Area name (e.g. South Fallowfield)", text: $viewModel.locationName)
                .textFieldStyle(.roundedBorder)
            Map(coordinateRegion: $mapRegion, annotationItems: pinItems) { item in
                MapMarker(coordinate: item.coordinate, tint: .red)
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: mapRegion.center.latitude) { _ in
                viewModel.locationLatitude = mapRegion.center.latitude
                viewModel.locationLongitude = mapRegion.center.longitude
            }
            .onChange(of: mapRegion.center.longitude) { _ in
                viewModel.locationLatitude = mapRegion.center.latitude
                viewModel.locationLongitude = mapRegion.center.longitude
            }
            HStack {
                Text("Radius:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { viewModel.radiusKm ?? 5 },
                    set: { viewModel.radiusKm = $0 }
                ), in: 1...50, step: 1)
                Text("\(Int(viewModel.radiusKm ?? 5)) km")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50)
            }
        }
    }

    private struct PinItem: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    private var pinItems: [PinItem] {
        [PinItem(coordinate: mapRegion.center)]
    }

    private var sportsSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick all that apply — these become tags on the community.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CommunityCreateOptions.sports, id: \.self) { sport in
                        let isSelected = viewModel.sports.contains(sport)
                        Button {
                            if isSelected {
                                viewModel.sports.remove(sport)
                            } else {
                                viewModel.sports.insert(sport)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                Text(sport).font(.caption)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

    private var focusSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick all that apply — sets the focus for posts in this community.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CommunityCreateOptions.healthFocus, id: \.self) { focus in
                        let isSelected = viewModel.focus.contains(focus)
                        Button {
                            if isSelected {
                                viewModel.focus.remove(focus)
                            } else {
                                viewModel.focus.insert(focus)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                Text(focus).font(.caption)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

    // MARK: - Step 5: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review")
                .font(.title3)
                .fontWeight(.bold)
            row("Type", viewModel.type.displayName)
            row("Privacy", viewModel.privacy.displayName)
            row("Name", viewModel.name)
            if !viewModel.description.isEmpty {
                row("Description", viewModel.description)
            }
            if !viewModel.tags.isEmpty {
                row("Tags", viewModel.tags.joined(separator: ", "))
            }
            if let breed = viewModel.breedFilter, !breed.isEmpty {
                row("Breed", breed)
            }
            if !viewModel.locationName.isEmpty {
                row("Location", viewModel.locationName)
            }
            if !viewModel.sports.isEmpty {
                row("Sports", viewModel.sports.sorted().joined(separator: ", "))
            }
            if !viewModel.focus.isEmpty {
                row("Focus", viewModel.focus.sorted().joined(separator: ", "))
            }
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tag input

private struct TagInput: View {
    @Binding var tags: [String]
    @State private var entry: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Add a tag (press +)", text: $entry)
                    .textFieldStyle(.roundedBorder)
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = entry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        entry = ""
    }
}
