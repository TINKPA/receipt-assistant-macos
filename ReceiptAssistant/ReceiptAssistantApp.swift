import Darwin
import SwiftUI

@main
struct ReceiptAssistantApp: App {
    @StateObject private var store = ReceiptStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var uploads = UploadService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(uploads)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1100, minHeight: 700)
                .task {
                    if ProcessInfo.processInfo.environment["RUN_SMOKE_TEST"] == "1" {
                        await smokeTestGeneratedClient()
                        exit(0)
                    }
                    await store.refreshAll()
                }
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
