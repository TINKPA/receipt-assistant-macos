import SwiftUI
import Charts

struct YearlyReviewView: View {
    @EnvironmentObject var store: ReceiptStore

    private struct MonthBucket: Identifiable {
        let id = UUID()
        let month: String
        let totalMinor: Int
    }

    private var months: [MonthBucket] {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        var buckets: [Int: Int] = [:]
        for t in store.transactions {
            guard let d = t.occurredOn.asDate, cal.component(.year, from: d) == year else { continue }
            let m = cal.component(.month, from: d)
            buckets[m, default: 0] += t.headlineAmountMinor
        }
        let fmt = DateFormatter().monthSymbols ?? []
        return (1...12).map { m in
            MonthBucket(month: fmt.indices.contains(m - 1) ? String(fmt[m - 1].prefix(3)) : "\(m)",
                        totalMinor: buckets[m] ?? 0)
        }
    }

    private var annualTotalMinor: Int { months.reduce(0) { $0 + $1.totalMinor } }

    private struct Quarter: Identifiable {
        let id = UUID()
        let name: String
        let totalMinor: Int
    }

    private var quarters: [Quarter] {
        stride(from: 0, to: 12, by: 3).map { start in
            let slice = months[start..<(start + 3)]
            return Quarter(name: "Q\(start / 3 + 1)",
                           totalMinor: slice.reduce(0) { $0 + $1.totalMinor })
        }
    }

    private var currency: String {
        store.summary?.currency ?? "USD"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Annual Total").font(.subheadline).foregroundStyle(.secondary)
                    Text(annualTotalMinor.currencyFromMinor(currency))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                card("Monthly Growth") {
                    Chart(months) { m in
                        LineMark(x: .value("Month", m.month),
                                 y: .value("Total", m.totalMinor))
                        PointMark(x: .value("Month", m.month),
                                  y: .value("Total", m.totalMinor))
                    }
                    .frame(height: 220)
                }

                card("Quarterly Breakdown") {
                    VStack(spacing: 0) {
                        ForEach(quarters) { q in
                            HStack {
                                Text(q.name).frame(width: 50, alignment: .leading)
                                Spacer()
                                Text(q.totalMinor.currencyFromMinor(currency))
                                    .font(.body.weight(.semibold))
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Yearly Review")
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
