import Foundation
import Combine

/// Service for credit card transaction monitoring via Plaid (v2.0 feature)
/// Detects bar/liquor store charges to trigger protection
class PlaidService: ObservableObject {
    static let shared = PlaidService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var linkedAccounts: [LinkedAccount] = []
    @Published private(set) var recentTransactions: [PlaidTransaction] = []
    @Published private(set) var barChargeDetected: Bool = false
    @Published private(set) var lastDetectedCharge: PlaidTransaction?
    
    // MARK: - Private Properties
    
    private var accessToken: String?
    
    // Plaid API (sandbox for development)
    private let baseURL = "https://sandbox.plaid.com"
    
    // MCC codes for bars and liquor stores
    private let barMCCCodes: Set<String> = [
        "5813", // Drinking Places (Bars, Taverns, Nightclubs)
        "5921", // Package Stores - Beer, Wine, Liquor
        "5811", // Caterers
        "5812"  // Eating Places, Restaurants (late night)
    ]
    
    private init() {
        loadLinkedAccounts()
    }
    
    // MARK: - Plaid Link
    
    /// Create a link token for Plaid Link
    func createLinkToken(clientId: String, secret: String) async -> String? {
        guard let url = URL(string: "\(baseURL)/link/token/create") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": clientId,
            "secret": secret,
            "user": ["client_user_id": UUID().uuidString],
            "client_name": "Booze Blocker",
            "products": ["transactions"],
            "country_codes": ["US"],
            "language": "en"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONDecoder().decode(LinkTokenResponse.self, from: data) {
                return response.linkToken
            }
        } catch {
            print("Plaid link token error: \(error)")
        }
        
        return nil
    }
    
    /// Exchange public token for access token after Plaid Link
    func exchangePublicToken(publicToken: String, clientId: String, secret: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/item/public_token/exchange") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": clientId,
            "secret": secret,
            "public_token": publicToken
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONDecoder().decode(ExchangeTokenResponse.self, from: data) {
                accessToken = response.accessToken
                saveAccessToken()
                
                await MainActor.run {
                    isConnected = true
                }
                
                // Fetch account info
                await fetchAccounts(clientId: clientId, secret: secret)
                
                return true
            }
        } catch {
            print("Plaid token exchange error: \(error)")
        }
        
        return false
    }
    
    /// Disconnect from Plaid
    func disconnect() {
        accessToken = nil
        linkedAccounts = []
        recentTransactions = []
        isConnected = false
        clearAccessToken()
    }
    
    // MARK: - Transaction Monitoring
    
    /// Fetch recent transactions and check for bar charges
    func checkForBarCharges(clientId: String, secret: String) async {
        guard let token = accessToken else { return }
        guard let url = URL(string: "\(baseURL)/transactions/get") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -6, to: endDate) ?? endDate
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let body: [String: Any] = [
            "client_id": clientId,
            "secret": secret,
            "access_token": token,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONDecoder().decode(TransactionsResponse.self, from: data) {
                await MainActor.run {
                    recentTransactions = response.transactions
                    checkTransactionsForBars(response.transactions)
                }
            }
        } catch {
            print("Plaid transactions error: \(error)")
        }
    }
    
    /// Check transactions for bar/liquor store charges
    private func checkTransactionsForBars(_ transactions: [PlaidTransaction]) {
        for transaction in transactions {
            // Check MCC code
            if let mcc = transaction.merchantCategoryCode,
               barMCCCodes.contains(mcc) {
                triggerBarChargeDetection(transaction)
                return
            }
            
            // Check merchant name keywords
            let merchantLower = transaction.merchantName?.lowercased() ?? ""
            let barKeywords = ["bar", "pub", "tavern", "brewery", "liquor", "wine", "spirits", "nightclub"]
            
            for keyword in barKeywords {
                if merchantLower.contains(keyword) {
                    triggerBarChargeDetection(transaction)
                    return
                }
            }
        }
    }
    
    private func triggerBarChargeDetection(_ transaction: PlaidTransaction) {
        barChargeDetected = true
        lastDetectedCharge = transaction
        
        NotificationCenter.default.post(
            name: .barChargeDetected,
            object: transaction
        )
    }
    
    /// Clear the bar charge detection flag
    func clearBarChargeDetection() {
        barChargeDetected = false
        lastDetectedCharge = nil
    }
    
    // MARK: - Account Management
    
    private func fetchAccounts(clientId: String, secret: String) async {
        guard let token = accessToken else { return }
        guard let url = URL(string: "\(baseURL)/accounts/get") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": clientId,
            "secret": secret,
            "access_token": token
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let response = try? JSONDecoder().decode(AccountsResponse.self, from: data) {
                await MainActor.run {
                    linkedAccounts = response.accounts
                    saveLinkedAccounts()
                }
            }
        } catch {
            print("Plaid accounts error: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func saveAccessToken() {
        // In production, use Keychain
        UserDefaults.standard.set(accessToken, forKey: "plaidAccessToken")
    }
    
    private func clearAccessToken() {
        UserDefaults.standard.removeObject(forKey: "plaidAccessToken")
    }
    
    private func saveLinkedAccounts() {
        if let data = try? JSONEncoder().encode(linkedAccounts) {
            UserDefaults.standard.set(data, forKey: "plaidLinkedAccounts")
        }
    }
    
    private func loadLinkedAccounts() {
        accessToken = UserDefaults.standard.string(forKey: "plaidAccessToken")
        isConnected = accessToken != nil
        
        if let data = UserDefaults.standard.data(forKey: "plaidLinkedAccounts"),
           let accounts = try? JSONDecoder().decode([LinkedAccount].self, from: data) {
            linkedAccounts = accounts
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let barChargeDetected = Notification.Name("barChargeDetected")
}

// MARK: - Data Models

struct LinkTokenResponse: Codable {
    let linkToken: String
    
    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

struct ExchangeTokenResponse: Codable {
    let accessToken: String
    let itemId: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case itemId = "item_id"
    }
}

struct AccountsResponse: Codable {
    let accounts: [LinkedAccount]
}

struct LinkedAccount: Codable, Identifiable {
    let id: String
    let name: String
    let officialName: String?
    let type: String
    let subtype: String?
    let mask: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "account_id"
        case name
        case officialName = "official_name"
        case type
        case subtype
        case mask
    }
    
    var displayName: String {
        if let mask = mask {
            return "\(name) ••••\(mask)"
        }
        return name
    }
}

struct TransactionsResponse: Codable {
    let transactions: [PlaidTransaction]
}

struct PlaidTransaction: Codable, Identifiable {
    let id: String
    let amount: Double
    let date: String
    let merchantName: String?
    let merchantCategoryCode: String?
    let name: String
    let pending: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "transaction_id"
        case amount
        case date
        case merchantName = "merchant_name"
        case merchantCategoryCode = "merchant_category_code"
        case name
        case pending
    }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
