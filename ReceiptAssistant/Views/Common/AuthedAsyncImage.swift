import SwiftUI
import AppKit

struct AuthedAsyncImage: View {
    let url: URL?
    let token: String?

    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed || url == nil {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .light))
                    Text("No preview").font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else { failed = true; return }
        var req = URLRequest(url: url)
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                failed = true
                return
            }
            if let ns = NSImage(data: data) {
                image = ns
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
    }
}
