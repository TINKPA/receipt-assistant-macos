import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var categoryFilter: Category? = nil
    @State private var selected: Receipt?

    var filtered: [Receipt] {
        guard let c = categoryFilter else { return store.receipts }
        return store.receipts.filter { $0.category == c }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if store.isLoading && store.receipts.isEmpty {
                LoadingView()
            } else if filtered.isEmpty {
                EmptyStateView(symbol: "doc.text.magnifyingglass",
                               title: "No transactions",
                               subtitle: "Upload a receipt to get started.")
            } else {
                List(filtered, selection: $selected) { r in
                    TransactionRow(receipt: r)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = r }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Transactions")
        .sheet(item: $selected) { r in
            ReceiptDetailSheet(receipt: r)
        }
        .task { await store.refreshReceipts() }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await store.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var filterBar: some View {
        HStack {
            Picker("Category", selection: $categoryFilter) {
                Text("All").tag(Category?.none)
                ForEach(Category.allCases) { c in
                    Text(c.displayName).tag(Category?.some(c))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            Spacer()
            Text("\(filtered.count) items").foregroundStyle(.secondary).font(.caption)
        }
        .padding()
    }
}

struct TransactionRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: receipt.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchant).font(.body.weight(.medium))
                Text(receipt.category.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(receipt.total.currency(receipt.currency))
                    .font(.body.weight(.semibold))
                Text(receipt.date).font(.caption).foregroundStyle(.secondary)
            }
            statusBadge
        }
        .padding(.vertical, 6)
    }

    private var statusBadge: some View {
        let (text, tint): (String, Color) = {
            if receipt.status == "processing" { return ("Processing", .orange) }
            if receipt.status == "error" { return ("Error", .red) }
            if let c = receipt.confidenceScore, c < 0.7 { return ("Pending", .yellow) }
            return ("Verified", .green)
        }()
        return StatusBadge(text: text, tint: tint)
    }
}

struct ReceiptDetailSheet: View {
    let receipt: Receipt
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.apiClient) var apiClient

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CategoryIcon(category: receipt.category, size: 44)
                VStack(alignment: .leading) {
                    Text(receipt.merchant).font(.title2.weight(.semibold))
                    Text(receipt.date).foregroundStyle(.secondary)
                }
                Spacer()
                Text(receipt.total.currency(receipt.currency))
                    .font(.title.weight(.bold))
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AuthedAsyncImage(
                        url: apiClient?.imageURL(for: receipt.id),
                        token: apiClient?.authToken
                    )
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 320)
                    .background(Color.black.opacity(0.25),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 4)

                    row("Category", receipt.category.displayName)
                    row("Currency", receipt.currency)
                    if let pm = receipt.paymentMethod { row("Payment", pm) }
                    if let t = receipt.tax { row("Tax", t.currency(receipt.currency)) }
                    if let t = receipt.tip { row("Tip", t.currency(receipt.currency)) }
                    row("Status", receipt.status)
                    if let conf = receipt.confidenceScore {
                        row("Confidence", String(format: "%.0f%%", conf * 100))
                    }
                    if let notes = receipt.notes {
                        Divider()
                        Text("Notes").font(.headline)
                        Text(notes).foregroundStyle(.secondary)
                    }
                    if let items = receipt.items, !items.isEmpty {
                        Divider()
                        Text("Items").font(.headline)
                        ForEach(items) { it in
                            HStack {
                                Text(it.name)
                                Spacer()
                                if let tp = it.totalPrice {
                                    Text(tp.currency(receipt.currency)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            HStack {
                Button(role: .destructive) {
                    Task {
                        await store.delete(receipt.id)
                        dismiss()
                    }
                } label: { Label("Delete", systemImage: "trash") }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    @ViewBuilder
    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v)
        }
    }
}
