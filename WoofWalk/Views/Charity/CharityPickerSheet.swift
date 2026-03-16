import SwiftUI

struct CharityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCharityId: String

    var body: some View {
        NavigationView {
            List(CharityOrg.supportedCharities) { charity in
                Button(action: {
                    selectedCharityId = charity.id
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        Text(charity.logoEmoji)
                            .font(.title)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.turquoise90))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(charity.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(charity.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        if charity.id == selectedCharityId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.turquoise60)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Choose Charity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
