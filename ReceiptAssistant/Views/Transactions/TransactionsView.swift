import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var search: String = ""
    @State private var selectedId: String?

    var filtered: [Transaction] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.transactions }
        return store.transactions.filter {
            ($0.payee ?? "").lowercased().contains(q) ||
            ($0.narration ?? "").lowercased().contains(q)
        }
    }

    private var selectedTxn: Transaction? {
        guard let id = selectedId else { return nil }
        return store.transactions.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if store.isLoading && store.transactions.isEmpty {
                LoadingView()
            } else if filtered.isEmpty {
                EmptyStateView(symbol: "doc.text.magnifyingglass",
                               title: "No transactions",
                               subtitle: "Upload a receipt to get started.")
            } else {
                List(filtered, id: \.id, selection: $selectedId) { t in
                    TransactionRow(txn: t)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedId = t.id }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Transactions")
        .sheet(isPresented: Binding(
            get: { selectedTxn != nil },
            set: { if !$0 { selectedId = nil } }
        )) {
            if let t = selectedTxn {
                TransactionDetailSheet(txn: t)
            }
        }
        .task { await store.refreshTransactions() }
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
            TextField("Search payee / memo…", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            Spacer()
            Text("\(filtered.count) items").foregroundStyle(.secondary).font(.caption)
        }
        .padding()
    }
}

struct TransactionRow: View {
    let txn: Transaction

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(key: nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.displayPayee).font(.body.weight(.medium))
                if let n = txn.narration, !n.isEmpty {
                    Text(n).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(txn.headlineAmount.currency(txn.primaryCurrency))
                    .font(.body.weight(.semibold))
                Text(txn.displayDate).font(.caption).foregroundStyle(.secondary)
            }
            statusBadge
        }
        .padding(.vertical, 6)
    }

    private var statusBadge: some View {
        let (text, tint): (String, Color) = {
            switch txn.status {
            case .draft: return ("Draft", .yellow)
            case .posted: return ("Posted", .green)
            case .reconciled: return ("Reconciled", .blue)
            case .voided: return ("Voided", .gray)
            case .error: return ("Error", .red)
            }
        }()
        return StatusBadge(text: text, tint: tint)
    }
}

struct TransactionDetailSheet: View {
    let txn: Transaction
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CategoryIcon(key: nil, size: 44)
                VStack(alignment: .leading) {
                    Text(txn.displayPayee).font(.title2.weight(.semibold))
                    Text(txn.displayDate).foregroundStyle(.secondary)
                }
                Spacer()
                Text(txn.headlineAmount.currency(txn.primaryCurrency))
                    .font(.title.weight(.bold))
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    row("Status", txn.status.rawValue)
                    row("Currency", txn.primaryCurrency)
                    row("Version", "\(txn.version)")
                    if let narration = txn.narration {
                        Divider()
                        Text("Narration").font(.headline)
                        Text(narration).foregroundStyle(.secondary)
                    }
                    Divider()
                    Text("Postings (\(txn.postings.count))").font(.headline)
                    ForEach(txn.postings, id: \.id) { p in
                        HStack {
                            Text(p.accountId)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(p.amountMinor.currencyFromMinor(p.currency))
                                .foregroundStyle(p.amountMinor < 0 ? .red : .green)
                        }
                        if let memo = p.memo {
                            Text(memo).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if !txn.documents.isEmpty {
                        Divider()
                        Text("Documents (\(txn.documents.count))").font(.headline)
                        ForEach(txn.documents, id: \.id) { d in
                            HStack {
                                Text(d.kind).font(.caption.weight(.semibold))
                                Spacer()
                                Text(d.id)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
                .padding()
            }
            HStack {
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
