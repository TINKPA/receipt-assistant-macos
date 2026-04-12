import SwiftUI
import Charts

struct YearlyReviewView: View {
    @EnvironmentObject var store: ReceiptStore

    private struct MonthBucket: Identifiable {
        let id = UUID()
        let month: String
        let total: Double
    }

    private var months: [MonthBucket] {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        var buckets: [Int: Double] = [:]
        for r in store.receipts {
            guard let d = r.date.asDate, cal.component(.year, from: d) == year else { continue }
            let m = cal.component(.month, from: d)
            buckets[m, default: 0] += r.total
        }
        let fmt = DateFormatter().monthSymbols ?? []
        return (1...12).map { m in
            MonthBucket(month: fmt.indices.contains(m - 1) ? String(fmt[m - 1].prefix(3)) : "\(m)",
                        total: buckets[m] ?? 0)
        }
    }

    private var annualTotal: Double { months.reduce(0) { $0 + $1.total } }

    private struct Quarter: Identifiable {
        let id = UUID()
        let name: String
        let total: Double
    }

    private var quarters: [Quarter] {
        let q = stride(from: 0, to: 12, by: 3).map { start -> Quarter in
            let slice = months[start..<(start + 3)]
            return Quarter(name: "Q\(start / 3 + 1)", total: slice.reduce(0) { $0 + $1.total })
        }
        return q
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Annual Total").font(.subheadline).foregroundStyle(.secondary)
                    Text(annualTotal.currency()).font(.system(size: 42, weight: .bold, design: .rounded))
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                card("Monthly Growth") {
                    Chart(months) { m in
                        LineMark(x: .value("Month", m.month),
                                 y: .value("Total", m.total))
                        PointMark(x: .value("Month", m.month),
                                  y: .value("Total", m.total))
                    }
                    .frame(height: 220)
                }

                card("Quarterly Breakdown") {
                    VStack(spacing: 0) {
                        ForEach(quarters) { q in
                            HStack {
                                Text(q.name).frame(width: 50, alignment: .leading)
                                Spacer()
                                Text(q.total.currency()).font(.body.weight(.semibold))
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
