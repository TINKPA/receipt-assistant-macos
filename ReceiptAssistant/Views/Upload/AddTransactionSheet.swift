import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AddTransactionSheet: View {
    let client: APIClient
    @EnvironmentObject var store: ReceiptStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var upload: UploadManager
    @State private var isTargeted = false
    @State private var notes: String = ""

    init(client: APIClient, store: ReceiptStore) {
        self.client = client
        _upload = StateObject(wrappedValue: UploadManager(client: client, store: store))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Upload Receipt").font(.title2.weight(.semibold))
            content
            TextField("Notes (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)
                .disabled(!canEdit)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if case .done = upload.state {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Choose File…") { pickFile() }
                        .disabled(!canEdit)
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 440)
        .onAppear {
            upload.objectWillChange.send()
        }
    }

    private var canEdit: Bool {
        if case .idle = upload.state { return true }
        if case .failed = upload.state { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch upload.state {
        case .idle, .failed:
            dropZone
        case .uploading:
            processingView(title: "Uploading…", quick: nil)
        case .queued:
            processingView(title: "Queued…", quick: nil)
        case .quickPreview(let q):
            processingView(title: "Quick preview — extracting details…", quick: q)
        case .processingFull(let q):
            processingView(title: "Extracting items with Claude…", quick: q)
        case .done(let r):
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text(r.merchant).font(.title3.weight(.semibold))
                Text(r.total.currency(r.currency)).font(.title2.weight(.bold))
                Text(r.category.displayName).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
        if case .failed(let msg) = upload.state {
            Text(msg).foregroundStyle(.red).font(.caption)
        }
    }

    @ViewBuilder
    private func processingView(title: String, quick: QuickResult?) -> some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(title).foregroundStyle(.secondary)
            if let q = quick {
                VStack(spacing: 2) {
                    Text(q.merchant ?? "—").font(.title3.weight(.semibold))
                    if let t = q.total {
                        Text(t.currency(q.currency ?? "USD"))
                            .font(.title2.weight(.bold))
                    }
                    if let d = q.date, !d.isEmpty {
                        Text(d).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.doc.on.clipboard")
                    .font(.system(size: 40, weight: .light))
                Text("Drop an image here").font(.headline)
                Text("JPG, PNG, HEIC — up to 20 MB")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in await upload.upload(fileURL: url, notes: notes) }
            }
            return true
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await upload.upload(fileURL: url, notes: notes) }
        }
    }
}
