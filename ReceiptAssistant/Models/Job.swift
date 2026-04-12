import Foundation

struct JobStatus: Codable, Hashable {
    let jobId: String
    let receiptId: String?
    let status: String
    let error: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "jobId"
        case receiptId = "receiptId"
        case status, error
    }

    var isTerminal: Bool { status == "done" || status == "error" }
}

struct UploadResponse: Codable {
    let jobId: String
    let receiptId: String
    let status: String
}

struct SpendingSummary: Codable, Identifiable, Hashable {
    var id: String { category }
    let category: String
    let count: Int
    let totalSpent: Double
    let avgPerReceipt: Double

    enum CodingKeys: String, CodingKey {
        case category, count
        case totalSpent = "total_spent"
        case avgPerReceipt = "avg_per_receipt"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        category = try c.decode(String.self, forKey: .category)
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        totalSpent = SpendingSummary.decodeDouble(c, .totalSpent) ?? 0
        avgPerReceipt = SpendingSummary.decodeDouble(c, .avgPerReceipt) ?? 0
    }

    private static func decodeDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return nil
    }
}
