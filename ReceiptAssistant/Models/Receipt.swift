import Foundation

struct Receipt: Codable, Identifiable, Hashable {
    let id: String
    let merchant: String
    let date: String
    let total: Double
    let currency: String
    let category: Category
    let paymentMethod: String?
    let tax: Double?
    let tip: Double?
    let notes: String?
    let rawText: String?
    let imagePath: String?
    let extractionMeta: ExtractionMeta?
    let status: String
    let createdAt: String?
    let updatedAt: String?
    let items: [ReceiptItem]?

    enum CodingKeys: String, CodingKey {
        case id, merchant, date, total, currency, category
        case paymentMethod = "payment_method"
        case tax, tip, notes
        case rawText = "raw_text"
        case imagePath = "image_path"
        case extractionMeta = "extraction_meta"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        merchant = (try? c.decode(String.self, forKey: .merchant)) ?? "Unknown"
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        total = Receipt.decodeDouble(c, .total) ?? 0
        currency = (try? c.decode(String.self, forKey: .currency)) ?? "USD"
        category = (try? c.decode(Category.self, forKey: .category)) ?? .other
        paymentMethod = try? c.decode(String.self, forKey: .paymentMethod)
        tax = Receipt.decodeDouble(c, .tax)
        tip = Receipt.decodeDouble(c, .tip)
        notes = try? c.decode(String.self, forKey: .notes)
        rawText = try? c.decode(String.self, forKey: .rawText)
        imagePath = try? c.decode(String.self, forKey: .imagePath)
        extractionMeta = try? c.decode(ExtractionMeta.self, forKey: .extractionMeta)
        status = (try? c.decode(String.self, forKey: .status)) ?? "done"
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        updatedAt = try? c.decode(String.self, forKey: .updatedAt)
        items = try? c.decode([ReceiptItem].self, forKey: .items)
    }

    private static func decodeDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(merchant, forKey: .merchant)
        try c.encode(date, forKey: .date)
        try c.encode(total, forKey: .total)
        try c.encode(currency, forKey: .currency)
        try c.encode(category.rawValue, forKey: .category)
        try c.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
        try c.encodeIfPresent(tax, forKey: .tax)
        try c.encodeIfPresent(tip, forKey: .tip)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(status, forKey: .status)
    }

    var confidenceScore: Double? { extractionMeta?.quality?.confidenceScore }
}

struct ReceiptItem: Codable, Identifiable, Hashable {
    let id: Int
    let receiptId: String?
    let name: String
    let quantity: Double?
    let unitPrice: Double?
    let totalPrice: Double?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id
        case receiptId = "receipt_id"
        case name, quantity
        case unitPrice = "unit_price"
        case totalPrice = "total_price"
        case category
    }
}

struct ExtractionMeta: Codable, Hashable {
    let quality: Quality?
    let business: Business?

    struct Quality: Codable, Hashable {
        let confidenceScore: Double?
        let missingFields: [String]?
        let warnings: [String]?
        enum CodingKeys: String, CodingKey {
            case confidenceScore = "confidence_score"
            case missingFields = "missing_fields"
            case warnings
        }
    }

    struct Business: Codable, Hashable {
        let isReimbursable: Bool?
        let isTaxDeductible: Bool?
        let isRecurring: Bool?
        let isSplitBill: Bool?
        enum CodingKeys: String, CodingKey {
            case isReimbursable = "is_reimbursable"
            case isTaxDeductible = "is_tax_deductible"
            case isRecurring = "is_recurring"
            case isSplitBill = "is_split_bill"
        }
    }
}
