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
            processingView(title: "Uploading…")
        case .queued:
            processingView(title: "Extracting with Claude…")
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
    private func processingView(title: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(title).foregroundStyle(.secondary)
            Text("This can take up to 2 minutes for complex receipts.")
                .font(.caption).foregroundStyle(.tertiary)
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
