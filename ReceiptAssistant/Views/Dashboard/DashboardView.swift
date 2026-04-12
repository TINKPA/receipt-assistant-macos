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
            Text(store.totalSpent.currency())
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
            Text("\(store.receipts.count) receipts tracked")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var categoryBar: some View {
        card(title: "Spending by Category") {
            if store.summary.isEmpty {
                emptyChart
            } else {
                Chart(store.summary) { s in
                    BarMark(
                        x: .value("Category", s.category),
                        y: .value("Total", s.totalSpent)
                    )
                    .foregroundStyle(by: .value("Category", s.category))
                }
                .frame(height: 240)
            }
        }
    }

    private var donut: some View {
        card(title: "Breakdown") {
            if store.summary.isEmpty {
                emptyChart
            } else {
                Chart(store.summary) { s in
                    SectorMark(
                        angle: .value("Total", s.totalSpent),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", s.category))
                }
                .frame(height: 240)
            }
        }
    }

    private var recent: some View {
        card(title: "Recent Activity") {
            if store.recentReceipts.isEmpty {
                EmptyStateView(symbol: "tray", title: "No receipts yet", subtitle: "Upload one to get started.")
                    .frame(height: 160)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.recentReceipts) { r in
                        HStack(spacing: 12) {
                            CategoryIcon(category: r.category)
                            VStack(alignment: .leading) {
                                Text(r.merchant).font(.body.weight(.medium))
                                Text(r.date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(r.total.currency(r.currency))
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
