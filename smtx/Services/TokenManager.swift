import Foundation

class TokenManager {
    static let shared = TokenManager()
    
    private let accessTokenKey = "auth.accessToken"
    private let refreshTokenKey = "auth.refreshToken"
    
    private init() {}
    
    // 存储 tokens
    func saveTokens(access: String, refresh: String) {
        KeychainHelper.standard.save(access, service: accessTokenKey, account: "smtx")
        KeychainHelper.standard.save(refresh, service: refreshTokenKey, account: "smtx")
    }
    
    // 获取 access token
    var accessToken: String? {
        KeychainHelper.standard.readString(service: accessTokenKey, account: "smtx")
    }
    
    // 获取 refresh token
    var refreshToken: String? {
        KeychainHelper.standard.readString(service: refreshTokenKey, account: "smtx")
    }
    
    // 清除 tokens
    func clearTokens() {
        KeychainHelper.standard.delete(service: accessTokenKey, account: "smtx")
        KeychainHelper.standard.delete(service: refreshTokenKey, account: "smtx")
    }
}

// 用于安全存储的 KeychainHelper
class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}
    
    func save(_ data: String, service: String, account: String) {
        if let data = data.data(using: .utf8) {
            saveData(data, service: service, account: account)
        }
    }
    
    func readString(service: String, account: String) -> String? {
        guard let data = readData(service: service, account: account) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private func saveData(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        // 先删除旧数据
        SecItemDelete(query)
        
        // 保存新数据
        let status = SecItemAdd(query, nil)
        if status != errSecSuccess {
            print("Error: \(status)")
        }
    }
    
    private func readData(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        return result as? Data
    }
    
    func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary
        
        SecItemDelete(query)
    }
} 