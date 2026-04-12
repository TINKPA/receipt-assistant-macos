import SwiftUI
import Charts

struct MonthlyReviewView: View {
    @EnvironmentObject var store: ReceiptStore

    private var thisMonth: [Receipt] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        let key = f.string(from: Date())
        return store.receipts.filter { $0.date.hasPrefix(key) }
    }

    private var lastMonth: [Receipt] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        let cal = Calendar.current
        let prev = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let key = f.string(from: prev)
        return store.receipts.filter { $0.date.hasPrefix(key) }
    }

    private struct WeekBucket: Identifiable {
        let id = UUID()
        let week: Int
        let total: Double
    }

    private var weeks: [WeekBucket] {
        let cal = Calendar.current
        var buckets: [Int: Double] = [:]
        for r in thisMonth {
            guard let d = r.date.asDate else { continue }
            let w = cal.component(.weekOfMonth, from: d)
            buckets[w, default: 0] += r.total
        }
        return buckets.keys.sorted().map { WeekBucket(week: $0, total: buckets[$0]!) }
    }

    private struct Compare: Identifiable {
        let id = UUID()
        let category: String
        let this: Double
        let last: Double
        var delta: Double { last == 0 ? 0 : (this - last) / last }
    }

    private var comparison: [Compare] {
        let groupThis = Dictionary(grouping: thisMonth, by: { $0.category.displayName })
            .mapValues { $0.reduce(0) { $0 + $1.total } }
        let groupLast = Dictionary(grouping: lastMonth, by: { $0.category.displayName })
            .mapValues { $0.reduce(0) { $0 + $1.total } }
        let keys = Set(groupThis.keys).union(groupLast.keys)
        return keys.sorted().map { Compare(category: $0, this: groupThis[$0] ?? 0, last: groupLast[$0] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Spent this month: \(thisMonth.reduce(0) { $0 + $1.total }.currency())")
                    .font(.title2.weight(.semibold))

                card("Weekly Breakdown") {
                    if weeks.isEmpty {
                        Text("No data this month").foregroundStyle(.secondary)
                    } else {
                        Chart(weeks) { w in
                            BarMark(x: .value("Week", "W\(w.week)"),
                                    y: .value("Total", w.total))
                        }
                        .frame(height: 220)
                    }
                }

                card("vs Last Month") {
                    if comparison.isEmpty {
                        Text("No comparison available").foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(comparison) { c in
                                HStack {
                                    Text(c.category)
                                    Spacer()
                                    Text(c.this.currency()).foregroundStyle(.primary)
                                    Text(String(format: "%+.0f%%", c.delta * 100))
                                        .foregroundStyle(abs(c.delta) > 0.2 ? .orange : .secondary)
                                        .frame(width: 70, alignment: .trailing)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Monthly Review")
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
