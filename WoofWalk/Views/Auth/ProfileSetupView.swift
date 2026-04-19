import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    headerSection
                    profileFields
                    dogsSection
                    completeButton
                    Spacer(minLength: 40)
                }
            }

            if viewModel.profileSetupUiState.isLoading {
                LoadingOverlay(message: "Setting up your profile...")
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Profile Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorAlertMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 8)

            Text("Complete Your Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text("Tell us about you and your dog")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Profile Fields

    private var profileFields: some View {
        VStack(spacing: 16) {
            CustomTextField(
                text: Binding(
                    get: { viewModel.profileSetupUiState.displayName },
                    set: { viewModel.updateProfileDisplayName($0) }
                ),
                placeholder: "Your name",
                label: "Display Name",
                icon: "person",
                error: viewModel.profileSetupUiState.displayName.isEmpty ? nil : nil
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Bio")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: Binding(
                    get: { viewModel.profileSetupUiState.bio },
                    set: { viewModel.updateProfileBio($0) }
                ))
                .frame(minHeight: 80, maxHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.profileSetupUiState.bio.isEmpty {
                        Text("A bit about you (optional)")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Dogs Section

    private var dogsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.blue)
                Text("Your Dogs")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            ForEach(Array(viewModel.profileSetupUiState.dogs.enumerated()), id: \.element.id) { index, dog in
                dogCard(dog: dog, index: index)
            }

            Button(action: { viewModel.addDog() }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add another dog")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
        }
    }

    private func dogCard(dog: DogFormData, index: Int) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Dog \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.profileSetupUiState.dogs.count > 1 {
                    Button(action: { viewModel.removeDog(dogId: dog.id) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }

            CustomTextField(
                text: Binding(
                    get: { dog.name },
                    set: { viewModel.updateDogName(dogId: dog.id, name: $0) }
                ),
                placeholder: "Dog's name",
                label: "Name",
                icon: "pawprint",
                error: nil
            )

            HStack(spacing: 12) {
                CustomTextField(
                    text: Binding(
                        get: { dog.breed },
                        set: { viewModel.updateDogBreed(dogId: dog.id, breed: $0) }
                    ),
                    placeholder: "Breed (optional)",
                    label: "Breed",
                    icon: "pawprint.circle",
                    error: nil
                )

                CustomTextField(
                    text: Binding(
                        get: { dog.age },
                        set: { viewModel.updateDogAge(dogId: dog.id, age: $0) }
                    ),
                    placeholder: "Age",
                    label: "Age",
                    icon: "calendar",
                    keyboardType: .numberPad,
                    error: nil
                )
                .frame(width: 100)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        PrimaryButton(
            title: "Complete Setup",
            isLoading: viewModel.profileSetupUiState.isLoading,
            action: {
                completeSetup()
            }
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func completeSetup() {
        // Validate display name
        let displayName = viewModel.profileSetupUiState.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName.isEmpty {
            errorAlertMessage = "Please enter a display name."
            showErrorAlert = true
            return
        }

        // Validate at least one dog has a name
        let dogs = viewModel.profileSetupUiState.dogs
        let hasValidDog = dogs.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !hasValidDog {
            errorAlertMessage = "Please enter at least one dog's name."
            showErrorAlert = true
            return
        }

        viewModel.completeProfileSetup(
            onSuccess: { onComplete() },
            onError: { message in
                errorAlertMessage = message
                showErrorAlert = true
            }
        )
    }
}
