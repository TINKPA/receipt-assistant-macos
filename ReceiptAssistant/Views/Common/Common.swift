import SwiftUI

struct CategoryIcon: View {
    let category: Category
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            Circle().fill(category.tint.opacity(0.18))
            Image(systemName: category.symbol)
                .foregroundStyle(category.tint)
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

extension String {
    var asDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: self)
    }
}
