import SwiftUI

struct ClientInvoicesScreen: View {
    @State private var selectedFilter: InvoiceFilter = .all

    private enum InvoiceFilter: String, CaseIterable {
        case all = "All"
        case unpaid = "Unpaid"
        case paid = "Paid"
    }

    private var filteredInvoices: [ClientInvoiceItem] {
        switch selectedFilter {
        case .all: return sampleInvoices
        case .unpaid: return sampleInvoices.filter { !$0.isPaid }
        case .paid: return sampleInvoices.filter { $0.isPaid }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary card
            invoiceSummary
                .padding()

            // Filter
            Picker("Filter", selection: $selectedFilter) {
                ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Invoice list
            if filteredInvoices.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                List(filteredInvoices) { invoice in
                    invoiceRow(invoice)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Invoices")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary

    private var invoiceSummary: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Outstanding")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("£45.00")
                    .font(.title2.bold())
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("Paid (Month)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("£120.00")
                    .font(.title2.bold())
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("£165.00")
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Invoice Row

    private func invoiceRow(_ invoice: ClientInvoiceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(invoice.title)
                        .font(.body.bold())
                    Text(invoice.walkerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(invoice.amount)
                    .font(.body.bold())
                    .foregroundColor(invoice.isPaid ? .green : .orange)
            }

            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(invoice.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()

                if invoice.isPaid {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                } else {
                    Button("Pay Now") {
                        // Handle payment
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }

            if !invoice.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(invoice.items, id: \.self) { item in
                        HStack {
                            Text("  \(item)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Invoices")
                .font(.headline)
            Text("You don't have any \(selectedFilter == .all ? "" : selectedFilter.rawValue.lowercased() + " ")invoices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sample Data

    private var sampleInvoices: [ClientInvoiceItem] {
        [
            ClientInvoiceItem(id: "INV-001", title: "Walk - Bella", walkerName: "Pawsome Walks", amount: "£15.00", date: "18 Mar 2026", isPaid: false, items: ["1x Standard Walk (60 min)"]),
            ClientInvoiceItem(id: "INV-002", title: "Group Walk - Bella & Max", walkerName: "Pawsome Walks", amount: "£30.00", date: "17 Mar 2026", isPaid: false, items: ["2x Standard Walk (60 min)", "Group discount: -£0.00"]),
            ClientInvoiceItem(id: "INV-003", title: "Walk - Bella", walkerName: "Pawsome Walks", amount: "£15.00", date: "15 Mar 2026", isPaid: true, items: ["1x Standard Walk (60 min)"]),
            ClientInvoiceItem(id: "INV-004", title: "Walk - Bella", walkerName: "Pawsome Walks", amount: "£15.00", date: "13 Mar 2026", isPaid: true, items: ["1x Standard Walk (60 min)"]),
            ClientInvoiceItem(id: "INV-005", title: "Walk - Bella (Extended)", walkerName: "Pawsome Walks", amount: "£22.50", date: "10 Mar 2026", isPaid: true, items: ["1x Extended Walk (90 min)"]),
            ClientInvoiceItem(id: "INV-006", title: "Walk - Bella", walkerName: "Pawsome Walks", amount: "£15.00", date: "8 Mar 2026", isPaid: true, items: ["1x Standard Walk (60 min)"]),
        ]
    }
}

// MARK: - Client Invoice Model

private struct ClientInvoiceItem: Identifiable {
    let id: String
    let title: String
    let walkerName: String
    let amount: String
    let date: String
    let isPaid: Bool
    let items: [String]
}

