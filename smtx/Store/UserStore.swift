import Foundation
import SwiftUI

@MainActor
class UserStore: ObservableObject {
    static let shared: UserStore = {
        let store = UserStore()
        return store
    }()
    
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    
    private init() {
        let instanceId = UUID().uuidString.prefix(8)
        print("UserStore init [\(instanceId)]: checking token")
        if let token = TokenManager.shared.accessToken {
            print("[\(instanceId)] Found token:", token)
            Task {
                do {
                    try await validateToken(token, instanceId: instanceId)
                } catch {
                    print("[\(instanceId)] Token validation failed:", error)
                    self.logout()
                }
            }
        } else {
            print("[\(instanceId)] No token found")
        }
    }
    
    // 处理注册成功
    func handleRegisterSuccess(user: User, accessToken: String, refreshToken: String) {
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
        isAuthenticated = true
        currentUser = user
    }
    
    // 处理登录成功
    func handleLoginSuccess(user: User, accessToken: String, refreshToken: String) {
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
        isAuthenticated = true
        currentUser = user
    }
    
    // 登出
    func logout() {
        TokenManager.shared.clearTokens()
        currentUser = nil
        isAuthenticated = false
    }
    
    // 更新用户信息
    func updateUserInfo(_ user: User) {
        currentUser = user
    }
    
    // 刷新 token
    func refreshTokenIfNeeded() async throws {
        guard let refreshToken = TokenManager.shared.refreshToken else {
            throw AuthError.networkError("No refresh token")
        }
        
        // TODO: 实现 token 刷新逻辑
        throw AuthError.networkError("Token refresh not implemented")
    }
    
    // 验证 token
    private func validateToken(_ token: String, instanceId: String.SubSequence) async throws {
        print("[\(instanceId)] Starting token validation")
        
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
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            print("[\(instanceId)] Token validation completed")
        }
    }
}

// 用于在视图中访问 UserStore
struct UserStateKey: EnvironmentKey {
    static let defaultValue = UserStore.shared
}

extension EnvironmentValues {
    var userStore: UserStore {
        get { self[UserStateKey.self] }
        set { self[UserStateKey.self] = newValue }
    }
}

// 用于在视图中检查认证状态
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