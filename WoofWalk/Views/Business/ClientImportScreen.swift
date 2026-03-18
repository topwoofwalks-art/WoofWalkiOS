import SwiftUI
import UniformTypeIdentifiers
import Contacts

// MARK: - Import Source

enum ImportSource: String, CaseIterable {
    case csv = "CSV File"
    case contacts = "Device Contacts"
    case manual = "Manual Entry"

    var icon: String {
        switch self {
        case .csv: return "doc.text"
        case .contacts: return "person.crop.rectangle.stack"
        case .manual: return "square.and.pencil"
        }
    }

    var description: String {
        switch self {
        case .csv: return "Import from a .csv file with client data"
        case .contacts: return "Import from your device's address book"
        case .manual: return "Add a single client manually"
        }
    }
}

// MARK: - Client Import Screen

struct ClientImportScreen: View {
    @ObservedObject var viewModel: BusinessViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 0
    @State private var selectedSource: ImportSource = .csv
    @State private var importedClients: [ImportedClient] = []
    @State private var isImporting: Bool = false
    @State private var importProgress: Double = 0.0
    @State private var importComplete: Bool = false
    @State private var importedCount: Int = 0
    @State private var totalCount: Int = 0
    @State private var showingFilePicker: Bool = false
    @State private var showingContactsAlert: Bool = false
    @State private var errorMessage: String?

    // Manual entry fields
    @State private var manualName: String = ""
    @State private var manualEmail: String = ""
    @State private var manualPhone: String = ""
    @State private var manualDogs: String = ""
    @State private var manualNotes: String = ""

    private let steps = ["Source", "Preview", "Duplicates", "Import"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 12)

                // Content
                TabView(selection: $currentStep) {
                    sourceSelectionStep
                        .tag(0)
                    previewStep
                        .tag(1)
                    duplicateDetectionStep
                        .tag(2)
                    importStep
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Navigation buttons
                if !importComplete {
                    navigationButtons
                        .padding()
                }
            }
            .navigationTitle("Import Clients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Contacts Access", isPresented: $showingContactsAlert) {
                Button("OK") { }
            } message: {
                Text("Please grant access to Contacts in Settings to import clients.")
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                HStack(spacing: 4) {
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Group {
                                if index < currentStep {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.caption2.bold())
                                        .foregroundColor(index == currentStep ? .white : .secondary)
                                }
                            }
                        )
                    Text(steps[index])
                        .font(.caption2)
                        .foregroundColor(index <= currentStep ? .primary : .secondary)
                }
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.accentColor : Color(.systemGray4))
                        .frame(height: 2)
                }
            }
        }
    }

    // MARK: - Step 1: Source Selection

    private var sourceSelectionStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose Import Source")
                    .font(.title3.bold())
                    .padding(.top, 20)

                ForEach(ImportSource.allCases, id: \.self) { source in
                    Button {
                        selectedSource = source
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: source.icon)
                                .font(.title2)
                                .foregroundColor(selectedSource == source ? .white : .accentColor)
                                .frame(width: 48, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedSource == source ? Color.accentColor : Color.accentColor.opacity(0.1))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(source.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            if selectedSource == source {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedSource == source ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Step 2: Preview

    private var previewStep: some View {
        Group {
            if selectedSource == .manual {
                manualEntryForm
            } else if importedClients.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No clients loaded yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Go back and select a source to load clients.")
                        .font(.subheadline)
                        .foregroundColor(Color(.tertiaryLabel))
                    Spacer()
                }
            } else {
                previewList
            }
        }
    }

    private var manualEntryForm: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Enter Client Details")
                    .font(.title3.bold())
                    .padding(.top, 20)

                VStack(spacing: 12) {
                    TextField("Full Name *", text: $manualName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Email", text: $manualEmail)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $manualPhone)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                    TextField("Dogs (comma separated)", text: $manualDogs)
                        .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: $manualNotes)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if !manualName.isEmpty {
                    Button {
                        let dogs = manualDogs.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let client = ImportedClient(
                            name: manualName,
                            email: manualEmail,
                            phone: manualPhone,
                            dogs: dogs,
                            notes: manualNotes,
                            source: "manual"
                        )
                        importedClients.append(client)
                        // Reset fields
                        manualName = ""
                        manualEmail = ""
                        manualPhone = ""
                        manualDogs = ""
                        manualNotes = ""
                    } label: {
                        Label("Add Client", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                if !importedClients.isEmpty {
                    Divider()
                    Text("Added Clients (\(importedClients.count))")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ForEach(importedClients) { client in
                        importedClientRow(client)
                    }
                }
            }
        }
    }

    private var previewList: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Preview (\(importedClients.count) clients)")
                    .font(.title3.bold())
                    .padding(.top, 20)

                ForEach(importedClients) { client in
                    importedClientRow(client)
                }
            }
            .padding(.horizontal)
        }
    }

    private func importedClientRow(_ client: ImportedClient) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.subheadline.bold())
                if !client.email.isEmpty {
                    Text(client.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !client.dogs.isEmpty {
                    Text("Dogs: \(client.dogs.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            Spacer()

            if client.isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Step 3: Duplicate Detection

    private var duplicateDetectionStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Duplicate Check")
                    .font(.title3.bold())
                    .padding(.top, 20)

                let duplicates = importedClients.filter { $0.isDuplicate }
                let clean = importedClients.filter { !$0.isDuplicate }

                // Summary
                HStack(spacing: 16) {
                    VStack {
                        Text("\(clean.count)")
                            .font(.title.bold())
                            .foregroundColor(.green)
                        Text("New")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)

                    VStack {
                        Text("\(duplicates.count)")
                            .font(.title.bold())
                            .foregroundColor(.orange)
                        Text("Duplicates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }

                if duplicates.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No duplicates found!")
                            .font(.headline)
                        Text("All clients are ready to import.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                } else {
                    Text("The following clients match existing records and will be skipped:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    ForEach(duplicates) { client in
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.subheadline.bold())
                                if let match = client.duplicateMatch {
                                    Text("Matches: \(match)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Text("Skip")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(.systemGray5)))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Step 4: Import

    private var importStep: some View {
        VStack(spacing: 24) {
            Spacer()

            if importComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Import Complete!")
                    .font(.title2.bold())

                Text("\(importedCount) of \(totalCount) clients imported successfully.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
            } else if isImporting {
                ProgressView(value: importProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text("Importing clients...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("\(Int(importProgress * 100))%")
                    .font(.title3.bold())
                    .foregroundColor(.accentColor)
            } else {
                let clientsToImport = importedClients.filter { !$0.isDuplicate }

                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Ready to Import")
                    .font(.title2.bold())

                Text("\(clientsToImport.count) clients will be added to your client list.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if importedClients.contains(where: { $0.isDuplicate }) {
                    Text("\(importedClients.filter { $0.isDuplicate }.count) duplicates will be skipped.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }

            Button {
                handleNext()
            } label: {
                HStack {
                    Text(currentStep == 3 ? "Import" : "Next")
                    if currentStep < 3 {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceed)
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return true
        case 1: return !importedClients.isEmpty
        case 2: return !importedClients.filter({ !$0.isDuplicate }).isEmpty
        case 3: return !isImporting
        default: return true
        }
    }

    // MARK: - Actions

    private func handleNext() {
        switch currentStep {
        case 0:
            // Trigger source action
            switch selectedSource {
            case .csv:
                showingFilePicker = true
            case .contacts:
                loadContacts()
            case .manual:
                // Move to manual entry form directly
                withAnimation { currentStep = 1 }
            }
        case 1:
            // Check for duplicates
            detectDuplicates()
            withAnimation { currentStep = 2 }
        case 2:
            withAnimation { currentStep = 3 }
        case 3:
            performImport()
        default:
            break
        }
    }

    // MARK: - CSV Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                importedClients = parseCSV(content)
                errorMessage = nil
                withAnimation { currentStep = 1 }
            } catch {
                errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = "File selection failed: \(error.localizedDescription)"
        }
    }

    private func parseCSV(_ content: String) -> [ImportedClient] {
        var clients: [ImportedClient] = []
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count > 1 else { return clients }

        // Parse header to find column indices
        let header = parseCSVLine(lines[0]).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let nameIdx = header.firstIndex(of: "name") ?? header.firstIndex(of: "full name") ?? header.firstIndex(of: "client name")
        let emailIdx = header.firstIndex(of: "email") ?? header.firstIndex(of: "email address")
        let phoneIdx = header.firstIndex(of: "phone") ?? header.firstIndex(of: "phone number") ?? header.firstIndex(of: "mobile")
        let dogsIdx = header.firstIndex(of: "dogs") ?? header.firstIndex(of: "pets") ?? header.firstIndex(of: "dog names")
        let notesIdx = header.firstIndex(of: "notes") ?? header.firstIndex(of: "comments")

        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i])
            guard !fields.isEmpty else { continue }

            let name = nameIdx.flatMap { $0 < fields.count ? fields[$0] : nil } ?? (fields.count > 0 ? fields[0] : "")
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let email = emailIdx.flatMap { $0 < fields.count ? fields[$0] : nil } ?? (fields.count > 1 ? fields[1] : "")
            let phone = phoneIdx.flatMap { $0 < fields.count ? fields[$0] : nil } ?? (fields.count > 2 ? fields[2] : "")
            let dogsStr = dogsIdx.flatMap { $0 < fields.count ? fields[$0] : nil } ?? ""
            let notes = notesIdx.flatMap { $0 < fields.count ? fields[$0] : nil } ?? ""

            let dogs = dogsStr.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

            clients.append(ImportedClient(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                dogs: dogs,
                notes: notes.trimmingCharacters(in: .whitespaces),
                source: "csv"
            ))
        }

        return clients
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Contacts Import

    private func loadContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [self] granted, error in
            guard granted else {
                DispatchQueue.main.async {
                    self.showingContactsAlert = true
                }
                return
            }

            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]

            var contacts: [ImportedClient] = []

            do {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                try store.enumerateContacts(with: request) { contact, _ in
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }

                    let email = contact.emailAddresses.first?.value as String? ?? ""
                    let phone = contact.phoneNumbers.first?.value.stringValue ?? ""

                    contacts.append(ImportedClient(
                        name: name,
                        email: email,
                        phone: phone,
                        dogs: [],
                        notes: "",
                        source: "contacts"
                    ))
                }

                DispatchQueue.main.async {
                    self.importedClients = contacts
                    withAnimation { self.currentStep = 1 }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to read contacts: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Duplicate Detection

    private func detectDuplicates() {
        let existingNames = Set(viewModel.clients.map { $0.name.lowercased() })
        let existingEmails = Set(viewModel.clients.filter { !$0.email.isEmpty }.map { $0.email.lowercased() })

        for i in 0..<importedClients.count {
            let client = importedClients[i]
            let nameLower = client.name.lowercased()
            let emailLower = client.email.lowercased()

            if existingNames.contains(nameLower) {
                importedClients[i].isDuplicate = true
                importedClients[i].duplicateMatch = "Name: \(client.name)"
            } else if !emailLower.isEmpty && existingEmails.contains(emailLower) {
                importedClients[i].isDuplicate = true
                importedClients[i].duplicateMatch = "Email: \(client.email)"
            }
        }
    }

    // MARK: - Perform Import

    private func performImport() {
        isImporting = true
        importProgress = 0.0

        let clientsToImport = importedClients.filter { !$0.isDuplicate }
        totalCount = clientsToImport.count

        // Simulate progress animation
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.importProgress < 0.9 {
                    self.importProgress += 0.02
                } else {
                    timer.invalidate()
                }
            }
        }

        viewModel.importClients(clientsToImport) { success, total in
            DispatchQueue.main.async {
                timer.invalidate()
                self.importProgress = 1.0
                self.importedCount = success
                self.isImporting = false
                self.importComplete = true
            }
        }
    }
}

#Preview {
    ClientImportScreen(viewModel: BusinessViewModel())
}
