import SwiftUI

struct UploadToastStack: View {
    @EnvironmentObject var uploads: UploadService

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(uploads.jobs.prefix(4)) { job in
                UploadToastCard(job: job)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.25), value: uploads.jobs)
        .allowsHitTesting(!uploads.jobs.isEmpty)
    }
}

struct UploadToastCard: View {
    let job: UploadService.Job
    @EnvironmentObject var uploads: UploadService

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button {
                uploads.dismiss(job.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(width: 320, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    private var tint: Color {
        switch job.state {
        case .uploading, .processing: return .accentColor
        case .done: return .green
        case .failed: return .red
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch job.state {
        case .uploading:
            ProgressView().controlSize(.small)
                .frame(width: 26, height: 26)
        case .processing:
            ProgressView().controlSize(.small)
                .frame(width: 26, height: 26)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.red)
        }
    }

    private var title: String {
        switch job.state {
        case .uploading: return "Uploading receipt…"
        case .processing: return "Extracting with Claude…"
        case .done(_, let txId): return txId == nil ? "Document ingested" : "Transaction created"
        case .failed: return "Upload failed"
        }
    }

    private var subtitle: String {
        switch job.state {
        case .uploading, .processing:
            return job.filename
        case .done(let docId, let txId):
            if let txId { return "tx: \(txId.prefix(8))…" }
            if let docId { return "doc: \(docId.prefix(8))…" }
            return job.filename
        case .failed(let msg):
            return msg
        }
    }
}
