import SwiftUI

struct CategoryIcon: View {
    /// Category lookup is best-effort post v1-ledger migration: the old
    /// Receipt.category Codable enum no longer exists. We try to map the
    /// summary bucket key (which can be a category name, an account id,
    /// or a payee depending on group_by) to a display Category, and fall
    /// back to a neutral icon.
    let key: String?
    var size: CGFloat = 32
    var body: some View {
        let cat = Category(rawValue: (key ?? "").lowercased()) ?? .other
        ZStack {
            Circle().fill(cat.tint.opacity(0.18))
            Image(systemName: cat.symbol)
                .foregroundStyle(cat.tint)
                .font(.system(size: size * 0.5, weight: .semibold))
        }
        .frame(width: size, height: size)
    }
}

struct StatusBadge: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Double {
    func currency(_ code: String = "USD") -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: self as NSNumber) ?? "\(self)"
    }
}

extension Decimal {
    func currency(_ code: String = "USD") -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}

extension Int {
    /// Format a minor-units amount (cents) as the given currency.
    func currencyFromMinor(_ code: String = "USD") -> String {
        let divisor: Int = (code == "JPY" || code == "KRW" || code == "VND") ? 1 : 100
        return (Decimal(self) / Decimal(divisor)).currency(code)
    }
}

extension String {
    var asDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: self)
    }
}
