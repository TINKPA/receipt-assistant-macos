import SwiftUI
import Charts

struct MonthlyReviewView: View {
    @EnvironmentObject var store: ReceiptStore

    private var thisMonthKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private var lastMonthKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        let prev = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return f.string(from: prev)
    }

    private var thisMonth: [Transaction] {
        store.transactions.filter { $0.occurredOn.hasPrefix(thisMonthKey) }
    }

    private var lastMonth: [Transaction] {
        store.transactions.filter { $0.occurredOn.hasPrefix(lastMonthKey) }
    }

    private struct WeekBucket: Identifiable {
        let id = UUID()
        let week: Int
        let totalMinor: Int
    }

    private var weeks: [WeekBucket] {
        let cal = Calendar.current
        var buckets: [Int: Int] = [:]
        for t in thisMonth {
            guard let d = t.occurredOn.asDate else { continue }
            let w = cal.component(.weekOfMonth, from: d)
            buckets[w, default: 0] += t.headlineAmountMinor
        }
        return buckets.keys.sorted().map { WeekBucket(week: $0, totalMinor: buckets[$0]!) }
    }

    private struct Compare: Identifiable {
        let id = UUID()
        let payee: String
        let thisMinor: Int
        let lastMinor: Int
        var delta: Double {
            lastMinor == 0 ? 0 : Double(thisMinor - lastMinor) / Double(lastMinor)
        }
    }

    private var comparison: [Compare] {
        let groupThis = Dictionary(grouping: thisMonth, by: { $0.displayPayee })
            .mapValues { $0.reduce(0) { $0 + $1.headlineAmountMinor } }
        let groupLast = Dictionary(grouping: lastMonth, by: { $0.displayPayee })
            .mapValues { $0.reduce(0) { $0 + $1.headlineAmountMinor } }
        let keys = Set(groupThis.keys).union(groupLast.keys)
        return keys.sorted().map {
            Compare(payee: $0,
                    thisMinor: groupThis[$0] ?? 0,
                    lastMinor: groupLast[$0] ?? 0)
        }
    }

    private var currency: String {
        store.summary?.currency ?? "USD"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let monthTotal = thisMonth.reduce(0) { $0 + $1.headlineAmountMinor }
                Text("Spent this month: \(monthTotal.currencyFromMinor(currency))")
                    .font(.title2.weight(.semibold))

                card("Weekly Breakdown") {
                    if weeks.isEmpty {
                        Text("No data this month").foregroundStyle(.secondary)
                    } else {
                        Chart(weeks) { w in
                            BarMark(x: .value("Week", "W\(w.week)"),
                                    y: .value("Total", w.totalMinor))
                        }
                        .frame(height: 220)
                    }
                }

                card("vs Last Month (by Payee)") {
                    if comparison.isEmpty {
                        Text("No comparison available").foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(comparison) { c in
                                HStack {
                                    Text(c.payee).lineLimit(1)
                                    Spacer()
                                    Text(c.thisMinor.currencyFromMinor(currency))
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
