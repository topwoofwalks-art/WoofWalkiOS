import SwiftUI
import PhotosUI
import CoreLocation

struct LostDogReportScreen: View {
    @StateObject private var vm = LostDogReportViewModel()
    @Environment(\.dismiss) private var dismiss

    /// Optional pre-fill — when the user taps "Report as lost" from a
    /// dog they own, we wire that dog's id + name in. Leave nil for
    /// the "I found a stray" entry path.
    var prefillDogId: String?
    var prefillDogName: String?
    var prefillDogBreed: String?

    @State private var pickedItem: PhotosPickerItem?
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                dogSection
                locationSection
                contactSection
                durationSection
                if let err = vm.submitError {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Report Lost Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.submit() }
                    } label: {
                        if vm.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Send Alert").bold()
                        }
                    }
                    .disabled(!vm.canSubmit)
                }
            }
            .task {
                if let dogId = prefillDogId { vm.prefillDogId = dogId }
                if let name = prefillDogName, vm.dogName.isEmpty { vm.dogName = name }
                if let breed = prefillDogBreed, vm.dogBreed.isEmpty { vm.dogBreed = breed }
                await vm.captureLocation()
            }
            .alert("Alert sent", isPresented: Binding(
                get: { vm.submitSuccess },
                set: { vm.submitSuccess = $0 }
            )) {
                Button("Done") { dismiss() }
            } message: {
                Text("Anyone within \(Int(vm.alertRadiusKm)) km will be notified. You'll get an alert if someone matches the description nearby. You can mark the dog as found from the Lost Dogs tab.")
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            VStack(spacing: 12) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    if let data = vm.selectedImageData,
                       let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("Add a photo (optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Recent, clear shot helps people recognise the dog")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .background(Color(.systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .onChange(of: pickedItem) { _, newItem in
                    Task {
                        if let item = newItem,
                           let data = try? await item.loadTransferable(type: Data.self) {
                            vm.selectedImageData = data
                            vm.uploadedPhotoUrl = nil
                        }
                    }
                }
            }
        } header: {
            Text("Photo")
        }
    }

    private var dogSection: some View {
        Section {
            TextField("Dog's name", text: $vm.dogName)
                .textInputAutocapitalization(.words)
            TextField("Breed (or 'mixed')", text: $vm.dogBreed)
                .textInputAutocapitalization(.words)
            ZStack(alignment: .topLeading) {
                if vm.description.isEmpty {
                    Text("Description: colour, size, collar, distinguishing features…")
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $vm.description)
                    .frame(minHeight: 100)
            }
        } header: {
            Text("Dog")
        }
    }

    private var locationSection: some View {
        Section {
            if vm.isFetchingLocation {
                HStack {
                    ProgressView()
                    Text("Getting your location…")
                        .foregroundColor(.secondary)
                }
            } else if let coord = vm.coordinate {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.green)
                    Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Refresh") {
                        Task { await vm.captureLocation() }
                    }
                    .font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.locationError ?? "Location not yet captured")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Button("Use current location") {
                        Task { await vm.captureLocation() }
                    }
                }
            }

            TextField("Where was the dog last seen? (e.g. \"Hampstead Heath, near East gate\")",
                      text: $vm.locationDescription, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Location")
        } footer: {
            Text("We use your current location as the alert centre. Add a description so people know exactly where to look.")
        }
    }

    private var contactSection: some View {
        Section {
            TextField("Phone number for finders to call (optional)",
                      text: $vm.reporterPhone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
        } header: {
            Text("Contact")
        } footer: {
            Text("If you skip this, finders will message you in-app.")
        }
    }

    private var durationSection: some View {
        Section {
            Picker("Alert active for", selection: $vm.durationHours) {
                Text("12 hours").tag(12)
                Text("24 hours").tag(24)
                Text("48 hours").tag(48)
                Text("72 hours").tag(72)
                Text("1 week").tag(168)
            }
            VStack(alignment: .leading) {
                Text("Alert radius: \(Int(vm.alertRadiusKm)) km")
                Slider(value: $vm.alertRadiusKm, in: 1...25, step: 1)
            }
        } header: {
            Text("Reach")
        } footer: {
            Text("Bigger radius = more eyes on the alert, but more notifications for people far from the area.")
        }
    }
}

#Preview {
    LostDogReportScreen()
}
