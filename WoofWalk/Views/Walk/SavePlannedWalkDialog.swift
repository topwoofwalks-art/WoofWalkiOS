import SwiftUI
import CoreLocation

struct SavePlannedWalkDialog: View {
    @Binding var isPresented: Bool
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var scheduledDate: Date = Date()
    @State private var useScheduledDate: Bool = false

    let waypoints: [CLLocationCoordinate2D]
    let distance: Double
    let duration: Int
    let onSave: (String, String, Date?) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Route Details") {
                    TextField("Walk Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Stats") {
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text(FormatUtils.formatDistance(distance))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Est. Duration")
                        Spacer()
                        Text(FormatUtils.formatDuration(duration))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Waypoints")
                        Spacer()
                        Text("\(waypoints.count)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Schedule") {
                    Toggle("Schedule for later", isOn: $useScheduledDate)
                    if useScheduledDate {
                        DatePicker("Date & Time", selection: $scheduledDate, in: Date()...)
                    }
                }
            }
            .navigationTitle("Save Planned Walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, description, useScheduledDate ? scheduledDate : nil)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
