import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var baseURLString: String {
        didSet { UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL) }
    }

    @Published var bearerToken: String? {
        didSet {
            if let t = bearerToken, !t.isEmpty {
                Keychain.set(t, for: Keys.bearer)
            } else {
                Keychain.delete(for: Keys.bearer)
            }
        }
    }

    var baseURL: URL {
        URL(string: baseURLString) ?? URL(string: "http://localhost:3000")!
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Keys.baseURL) ?? "http://localhost:3000"
        self.baseURLString = saved
        self.bearerToken = Keychain.get(for: Keys.bearer)
    }

    private enum Keys {
        static let baseURL = "ReceiptAssistant.baseURL"
        static let bearer = "ReceiptAssistant.bearerToken"
    }
}
