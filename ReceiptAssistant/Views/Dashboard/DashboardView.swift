import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var store: ReceiptStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                HStack(alignment: .top, spacing: 16) {
                    categoryBar
                    donut
                }
                recent
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total Spent").font(.subheadline).foregroundStyle(.secondary)
            Text(store.totalSpent.currency(store.summary?.currency ?? "USD"))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
            Text("\(store.transactions.count) transactions tracked")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summaryItems: [SummaryItem] {
        store.summary?.items ?? []
    }

    private var summaryCurrency: String {
        store.summary?.currency ?? "USD"
    }

    private var categoryBar: some View {
        card(title: "Spending by Category") {
            if summaryItems.isEmpty {
                emptyChart
            } else {
                Chart(summaryItems, id: \.key) { s in
                    BarMark(
                        x: .value("Category", s.key),
                        y: .value("Total", s.totalMinor)
                    )
                    .foregroundStyle(by: .value("Category", s.key))
                }
                .frame(height: 240)
            }
        }
    }

    private var donut: some View {
        card(title: "Breakdown") {
            if summaryItems.isEmpty {
                emptyChart
            } else {
                Chart(summaryItems, id: \.key) { s in
                    SectorMark(
                        angle: .value("Total", s.totalMinor),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", s.key))
                }
                .frame(height: 240)
            }
        }
    }

    private var recent: some View {
        card(title: "Recent Activity") {
            if store.recentTransactions.isEmpty {
                EmptyStateView(symbol: "tray", title: "No transactions yet",
                               subtitle: "Upload a receipt to get started.")
                    .frame(height: 160)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.recentTransactions, id: \.id) { t in
                        HStack(spacing: 12) {
                            CategoryIcon(key: nil)
                            VStack(alignment: .leading) {
                                Text(t.displayPayee).font(.body.weight(.medium))
                                Text(t.displayDate).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(t.headlineAmount.currency(t.primaryCurrency))
                                .font(.body.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyChart: some View {
        Text("No data").foregroundStyle(.secondary).frame(height: 240)
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
