import SwiftUI

struct BreedAutocomplete: View {
    @Binding var selectedBreed: String
    @State private var searchText = ""
    @State private var showSuggestions = false
    @FocusState private var isFieldFocused: Bool

    static let topBreeds = [
        "Labrador Retriever", "French Bulldog", "Cocker Spaniel", "Bulldog",
        "German Shepherd", "Golden Retriever", "Springer Spaniel", "Staffordshire Bull Terrier",
        "Border Collie", "Cavalier King Charles Spaniel", "Miniature Schnauzer", "Dachshund",
        "Pug", "Beagle", "Shih Tzu", "Yorkshire Terrier", "Whippet", "Boxer",
        "Jack Russell Terrier", "Rottweiler", "Poodle", "Dobermann", "Dalmatian",
        "Maltese", "Chihuahua", "Border Terrier", "Vizsla", "Lhasa Apso",
        "Bernese Mountain Dog", "West Highland White Terrier", "Siberian Husky",
        "Australian Shepherd", "Rhodesian Ridgeback", "Great Dane", "Weimaraner",
        "Bichon Frise", "Basset Hound", "Akita", "Newfoundland", "Irish Setter",
        "Greyhound", "Collie", "Shar Pei", "Samoyed", "Havanese",
        "Cairn Terrier", "English Setter", "Corgi", "Lurcher", "Mixed Breed"
    ]

    private var filteredBreeds: [String] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return Self.topBreeds }
        return Self.topBreeds.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Breed", text: $searchText)
                    .focused($isFieldFocused)
                    .onChange(of: searchText) { _ in
                        showSuggestions = true
                    }
                    .onChange(of: isFieldFocused) { focused in
                        if focused {
                            showSuggestions = true
                            if searchText.isEmpty {
                                searchText = selectedBreed
                            }
                        }
                    }
                    .onSubmit {
                        commitSelection()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        selectedBreed = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showSuggestions && isFieldFocused && !filteredBreeds.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredBreeds, id: \.self) { breed in
                            Button {
                                searchText = breed
                                selectedBreed = breed
                                showSuggestions = false
                                isFieldFocused = false
                            } label: {
                                HStack {
                                    Text(breed)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if breed == selectedBreed {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.turquoise60)
                                            .font(.caption)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                            }
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .onAppear {
            searchText = selectedBreed
        }
    }

    private func commitSelection() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if let match = Self.topBreeds.first(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            selectedBreed = match
            searchText = match
        } else {
            selectedBreed = trimmed
        }
        showSuggestions = false
        isFieldFocused = false
    }
}
