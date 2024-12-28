import Foundation
import SwiftUI

@MainActor
class UserStore: ObservableObject {
    // 使用 actor-isolated 的方式实现单例
    private static var _shared: UserStore?
    
    static var shared: UserStore {
        if _shared == nil {
            _shared = UserStore()
        }
        return _shared!
    }
    
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    
    private init() {
        // 尝试从本地加载用户信息
        if let token = TokenManager.shared.accessToken {
            if let savedUser = loadUserFromUserDefaults() {
                // 如果有本地缓存的用户信息，先使用它
                self.currentUser = savedUser
                self.isAuthenticated = true
            }
            
            // 然后在后台验证 token 并更新用户信息
            Task {
                do {
                    try await validateToken(token)
                } catch {
                    self.logout()
                }
            }
        }
    }
    
    // 保存用户信息到 UserDefaults
    private func saveUserToUserDefaults(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
        }
    }
    
    // 从 UserDefaults 加载用户信息
    private func loadUserFromUserDefaults() -> User? {
        if let data = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            return user
        }
        return nil
    }
    
    // 更新用户信息时同时更新本地缓存
    func updateUserInfo(_ user: User) {
        currentUser = user
        saveUserToUserDefaults(user)
    }
    
    // 登出时清除本地缓存
    func logout() {
        TokenManager.shared.clearTokens()
        UserDefaults.standard.removeObject(forKey: "currentUser")
        currentUser = nil
        isAuthenticated = false
    }
    
    // 处理登录成功时保存用户信息
    func handleLoginSuccess(user: User, accessToken: String, refreshToken: String) {
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
        isAuthenticated = true
        currentUser = user
        saveUserToUserDefaults(user)
    }
    
    // 处理注册成功时保存用户信息
    func handleRegisterSuccess(user: User, accessToken: String, refreshToken: String) {
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
        isAuthenticated = true
        currentUser = user
        saveUserToUserDefaults(user)
    }
    
    // 验证 token - 只在应用启动时调用
    private func validateToken(_ token: String) async throws {
        let url = URL(string: "\(AuthService.shared.baseURL)/users/profile/")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("无效的响应")
        }
        
        if httpResponse.statusCode == 401 {
            throw AuthError.serverError("Token 已过期")
        }
        
        if httpResponse.statusCode != 200 {
            throw AuthError.serverError("验证失败：\(httpResponse.statusCode)")
        }
        
        let user = try JSONDecoder().decode(User.self, from: data)
        
        self.currentUser = user
        self.isAuthenticated = true
    }
}

// MARK: - Environment
struct UserStateKey: EnvironmentKey {
    @MainActor
    static var defaultValue: UserStore {
        UserStore.shared
    }
}

extension EnvironmentValues {
    var userStore: UserStore {
        get { self[UserStateKey.self] }
        set { self[UserStateKey.self] = newValue }
    }
}

// MARK: - RequireAuth
struct RequireAuth<Content: View>: View {
    @Environment(\.userStore) private var userStore
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        Group {
            if userStore.isAuthenticated {
                content()
            } else {
                // 显示未登录状态的视图
                VStack {
                    Text("请先登录")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Button("去登录") {
                        // TODO: 导航到登录页面
                    }
                    .padding()
                }
            }
        }
    } 
}
