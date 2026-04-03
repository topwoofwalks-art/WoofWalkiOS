import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreateCommunitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var isCreating = false

    // Step 1: Type
    @State private var selectedType: CommunityType?

    // Step 2: Name + Description + Rules
    @State private var name = ""
    @State private var description = ""
    @State private var rules = ""

    // Step 3: Privacy + Tags
    @State private var isPrivate = false
    @State private var tagInput = ""
    @State private var tags: [String] = []

    // Step 4: Type-specific config
    @State private var breedName = ""
    @State private var neighborhoodArea = ""
    @State private var trainingLevel = "Beginner"
    @State private var sportType = ""

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)
    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                // Step content
                TabView(selection: $currentStep) {
                    step1TypeSelection.tag(0)
                    step2NameDescription.tag(1)
                    step3PrivacyTags.tag(2)
                    step4TypeConfig.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentStep)

                // Navigation buttons
                bottomButtons
            }
            .navigationTitle("Create Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step <= currentStep ? brandColor : Color(.systemGray4))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Step 1: Type Selection

    private var step1TypeSelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What type of community?")
                    .font(.title3.bold())
                    .padding(.horizontal, 20)

                Text("Choose the category that best fits your community.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(CommunityType.allCases) { type in
                        typeCard(type)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
    }

    private func typeCard(_ type: CommunityType) -> some View {
        let isSelected = selectedType == type
        return Button {
            selectedType = type
        } label: {
            VStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : type.color)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(isSelected ? type.color : type.color.opacity(0.12))
                    )

                Text(type.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? type.color : .primary)

                Text(typeSubtitle(type))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.08) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func typeSubtitle(_ type: CommunityType) -> String {
        switch type {
        case .breedSpecific: return "Connect with breed owners"
        case .neighborhood: return "Local dog community"
        case .training: return "Share training tips"
        case .rescue: return "Help dogs find homes"
        case .social: return "General dog fun"
        case .sport: return "Agility, flyball & more"
        }
    }

    // MARK: - Step 2: Name + Description

    private var step2NameDescription: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name your community")
                    .font(.title3.bold())
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Community Name")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField("e.g. Golden Retriever Lovers", text: $name)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Community Rules (optional)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextEditor(text: $rules)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Step 3: Privacy + Tags

    private var step3PrivacyTags: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy & Tags")
                    .font(.title3.bold())
                    .padding(.horizontal, 20)

                // Privacy toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $isPrivate) {
                        HStack(spacing: 10) {
                            Image(systemName: isPrivate ? "lock.fill" : "globe")
                                .foregroundColor(brandColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isPrivate ? "Private Community" : "Public Community")
                                    .font(.subheadline.bold())
                                Text(isPrivate
                                     ? "Only members can see posts and members"
                                     : "Anyone can discover and view this community")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(brandColor)
                }
                .padding(.horizontal, 20)

                // Cover photo placeholder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cover Photo")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Button { } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: 120)
                            VStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                                Text("Add Cover Photo")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("Add a tag...", text: $tagInput)
                            .textFieldStyle(.plain)
                            .onSubmit { addTag() }
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(brandColor)
                        }
                        .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )

                    if !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.caption)
                                    Button {
                                        tags.removeAll { $0 == tag }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                }
                                .foregroundColor(brandColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(brandColor.opacity(0.12)))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        tagInput = ""
    }

    // MARK: - Step 4: Type-specific Config

    private var step4TypeConfig: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Additional Details")
                    .font(.title3.bold())
                    .padding(.horizontal, 20)

                switch selectedType {
                case .breedSpecific:
                    configField(label: "Breed Name", placeholder: "e.g. Golden Retriever", text: $breedName)
                case .neighborhood:
                    configField(label: "Neighborhood / Area", placeholder: "e.g. Downtown Portland", text: $neighborhoodArea)
                case .training:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Training Level")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Picker("Level", selection: $trainingLevel) {
                            Text("Beginner").tag("Beginner")
                            Text("Intermediate").tag("Intermediate")
                            Text("Advanced").tag("Advanced")
                            Text("All Levels").tag("All Levels")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 20)
                case .sport:
                    configField(label: "Sport Type", placeholder: "e.g. Agility, Flyball, Dock Diving", text: $sportType)
                case .rescue:
                    Text("Your rescue community is almost ready! You can add adoptable dogs after creation.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                case .social, .none:
                    Text("You're all set! Review your details and create the community.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }

                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        summaryRow("Name", name)
                        summaryRow("Type", selectedType?.displayName ?? "")
                        summaryRow("Privacy", isPrivate ? "Private" : "Public")
                        if !tags.isEmpty {
                            summaryRow("Tags", tags.joined(separator: ", "))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
    }

    private func configField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
        }
        .padding(.horizontal, 20)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(brandColor)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(brandColor, lineWidth: 1.5)
                        )
                }
            }

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    Task {
                        isCreating = true
                        await createCommunity()
                        dismiss()
                    }
                }
            } label: {
                Group {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep == totalSteps - 1 ? "Create" : "Next")
                    }
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canProceed ? brandColor : Color(.systemGray3))
                )
            }
            .disabled(!canProceed || isCreating)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).shadow(color: .black.opacity(0.05), radius: 4, y: -2))
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return selectedType != nil
        case 1: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
        case 3: return true
        default: return false
        }
    }

    // MARK: - Create

    private func createCommunity() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let type = selectedType else { return }
        let userName = Auth.auth().currentUser?.displayName ?? "Unknown"

        var data: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "description": description.trimmingCharacters(in: .whitespaces),
            "type": type.rawValue,
            "isPrivate": isPrivate,
            "rules": rules,
            "tags": tags,
            "ownerId": userId,
            "ownerName": userName,
            "adminIds": [userId],
            "memberIds": [userId],
            "memberCount": 1,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        // Type-specific fields
        switch type {
        case .breedSpecific: data["breedName"] = breedName
        case .neighborhood: data["neighborhoodArea"] = neighborhoodArea
        case .training: data["trainingLevel"] = trainingLevel
        case .sport: data["sportType"] = sportType
        default: break
        }

        let db = Firestore.firestore()
        do {
            try await db.collection("communities").addDocument(data: data)
        } catch {
            print("Create community error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
