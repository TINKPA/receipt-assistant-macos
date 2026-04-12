import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AddTransactionSheet: View {
    @EnvironmentObject var uploads: UploadService
    @Environment(\.dismiss) var dismiss
    @State private var isTargeted = false
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Upload Receipt").font(.title2.weight(.semibold))

            dropZone

            TextField("Notes (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)

            Text("Processing runs in the background — you can keep working.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Choose File…") { pickFile() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 420)
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
                Text("JPG, PNG, HEIC — auto-compressed to ~1 MB")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in submit(url: url) }
            }
            return true
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            submit(url: url)
        }
    }

    private func submit(url: URL) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        uploads.submit(fileURL: url, notes: trimmed.isEmpty ? nil : trimmed)
        dismiss()
    }
}
