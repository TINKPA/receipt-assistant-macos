//
//  ReceiptStore.swift
//
//  Holds the in-memory cache of ledger transactions + the latest spending
//  summary. Despite the legacy name, after the v1 ledger migration this
//  is a Transaction store — `receipts` is kept as a property name so the
//  views (Dashboard / Transactions list / etc.) don't need to be renamed
//  in lock-step. A future PR can rename store + property if desired.
//

import Foundation
import Combine

@MainActor
final class ReceiptStore: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var summary: SummaryReport?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var client: APIClient?

    func attach(_ client: APIClient) {
        self.client = client
    }

    func refreshAll() async {
        await refreshTransactions()
        await refreshSummary()
    }

    func refreshTransactions(limit: Int = 100) async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            transactions = try await client.listTransactions(limit: limit)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    func refreshSummary() async {
        guard let client else { return }
        do {
            summary = try await client.summary(groupBy: .category)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Stubbed in the v1-ledger migration PR — delete/void both need an
    /// If-Match header with the transaction's ETag, which the facade
    /// doesn't yet expose. Surfaces an error so callers don't silently
    /// succeed.
    func delete(_ id: String) async {
        errorMessage = "Delete not implemented (needs ETag/If-Match — TODO)"
    }

    func void(_ id: String, reason: String? = nil) async {
        errorMessage = "Void not implemented (needs ETag/If-Match — TODO)"
    }

    // MARK: - Derived

    /// Total in the report's reporting currency (minor units).
    var totalSpentMinor: Int {
        summary?.grandTotalMinor ?? 0
    }

    /// Total spend formatted as Decimal. Most currencies use 100 minor
    /// units per major; JPY is the notable exception (no fractional units).
    var totalSpent: Decimal {
        let divisor: Int = (summary?.currency == "JPY") ? 1 : 100
        return Decimal(totalSpentMinor) / Decimal(divisor)
    }

    var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }
}
