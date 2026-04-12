import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case transactions = "Transactions"
    case monthly = "Monthly Review"
    case yearly = "Yearly Review"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .transactions: return "list.bullet.rectangle"
        case .monthly: return "calendar"
        case .yearly: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: ReceiptStore
    @EnvironmentObject var settings: AppSettings
    @State private var selection: SidebarItem? = .dashboard
    @State private var showUpload = false
    @State private var client: APIClient?

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.symbol)
                }
            }
            .navigationTitle("Wealth")
            .frame(minWidth: 220)
            .safeAreaInset(edge: .bottom) {
                Button {
                    showUpload = true
                } label: {
                    Label("Add Transaction", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("u", modifiers: [.command])
                .padding()
            }
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard: DashboardView()
                case .transactions: TransactionsView()
                case .monthly: MonthlyReviewView()
                case .yearly: YearlyReviewView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            if client == nil {
                let c = APIClient(settings: settings)
                client = c
                store.attach(c)
                await store.refreshAll()
            }
        }
        .sheet(isPresented: $showUpload) {
            if let client {
                AddTransactionSheet(client: client, store: store)
                    .environmentObject(store)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUploadSheet)) { _ in
            showUpload = true
        }
    }
}
