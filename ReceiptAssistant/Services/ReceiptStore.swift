import Foundation
import Combine

@MainActor
final class ReceiptStore: ObservableObject {
    @Published var receipts: [Receipt] = []
    @Published var summary: [SpendingSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var client: APIClient?

    func attach(_ client: APIClient) {
        self.client = client
    }

    func refreshAll() async {
        await refreshReceipts()
        await refreshSummary()
    }

    func refreshReceipts(category: Category? = nil) async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            receipts = try await client.listReceipts(category: category)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    func refreshSummary() async {
        guard let client else { return }
        do {
            summary = try await client.summary()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    func delete(_ id: String) async {
        guard let client else { return }
        do {
            try await client.deleteReceipt(id)
            receipts.removeAll { $0.id == id }
            await refreshSummary()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    var totalSpent: Double { summary.reduce(0) { $0 + $1.totalSpent } }

    var recentReceipts: [Receipt] { Array(receipts.prefix(5)) }
}
