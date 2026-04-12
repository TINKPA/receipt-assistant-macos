import SwiftUI

@main
struct ReceiptAssistantApp: App {
    @StateObject private var store = ReceiptStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1100, minHeight: 700)
                .task { await store.refreshAll() }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Upload Receipt…") {
                    NotificationCenter.default.post(name: .showUploadSheet, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let showUploadSheet = Notification.Name("ShowUploadSheet")
}
