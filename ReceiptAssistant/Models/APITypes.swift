//
//  APITypes.swift
//
//  Friendly typealiases over the swift-openapi-generator output.
//  All API data flows as Components.Schemas.* — these aliases just
//  shorten the spelling. Do not add hand-written shapes here; if the
//  backend OpenAPI spec changes, refresh-openapi.sh + xcodegen will
//  update the underlying types and the rest of the app picks up the
//  changes via tsc-equivalent compile errors.
//

import Foundation
import OpenAPIRuntime

// Core ledger
typealias Transaction = Components.Schemas.Transaction
typealias Posting = Components.Schemas.Posting
typealias TransactionStatus = Components.Schemas.Transaction.StatusPayload
typealias TransactionDocumentRef = Components.Schemas.TransactionDocumentRef

// Accounts (chart of accounts tree)
typealias Account = Components.Schemas.Account
typealias AccountBalance = Components.Schemas.AccountBalance
typealias AccountRegister = Components.Schemas.AccountRegister

// Documents (receipt images, PDFs)
typealias Document = Components.Schemas.Document

// Ingest pipeline (upload → extract → reconcile)
typealias Ingest = Components.Schemas.Ingest
typealias IngestStatus = Components.Schemas.IngestStatus
typealias Batch = Components.Schemas.Batch
typealias BatchSummary = Components.Schemas.BatchSummary
typealias BatchStatus = Components.Schemas.BatchStatus
typealias CreateBatchResponse = Components.Schemas.CreateBatchResponse

// Reports
typealias SummaryReport = Components.Schemas.SummaryReport
typealias SummaryItem = Components.Schemas.SummaryItem
typealias TrendsReport = Components.Schemas.TrendsReport
typealias NetWorthReport = Components.Schemas.NetWorthReport

// MARK: - Display helpers (derived view-model fields)

extension Transaction {
    /// The "headline" amount in minor units. For a normal 2-line transaction
    /// (debit one account, credit another), both postings have the same |amount|;
    /// we pick the absolute value of the first posting. Multi-leg transactions
    /// take the largest absolute amount as a heuristic.
    var headlineAmountMinor: Int {
        postings.map { abs($0.amountMinor) }.max() ?? 0
    }

    /// Headline amount expressed as a Decimal in the transaction's primary
    /// currency (uses the first posting's currency). Caller is responsible
    /// for currency-aware formatting.
    var headlineAmount: Decimal {
        Decimal(headlineAmountMinor) / Decimal(currencyMinorUnit)
    }

    var primaryCurrency: String {
        postings.first?.currency ?? "USD"
    }

    /// Minor unit divisor for the transaction's currency. JPY uses 1,
    /// most others use 100. Bitcoin/satoshi would be 100_000_000 — not
    /// in scope here.
    private var currencyMinorUnit: Int {
        switch primaryCurrency {
        case "JPY", "KRW", "VND", "ISK": return 1
        default: return 100
        }
    }

    var displayPayee: String {
        if let p = payee, !p.isEmpty { return p }
        if let n = narration, !n.isEmpty { return n }
        return "Untitled"
    }

    /// First posting that hits an expense account would be the "category"
    /// account in single-receipt land. We don't have the account tree here,
    /// so callers that need a name string look up the account by id.
    var primaryAccountId: String? {
        postings.first?.accountId
    }

    /// `occurred_on` is `YYYY-MM-DD`; used directly in lists.
    var displayDate: String { occurredOn }
}

extension Transaction.StatusPayload {
    var isLive: Bool {
        switch self {
        case .posted, .reconciled: return true
        case .draft, .voided, .error: return false
        }
    }
}
