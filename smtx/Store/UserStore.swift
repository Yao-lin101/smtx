import Foundation
import SwiftUI

@MainActor
class UserStore: ObservableObject {
    static let shared = UserStore()
    
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    
    private init() {
        // 检查是否有保存的 token
        if TokenManager.shared.accessToken != nil {
            Task {
                await checkAuthState()
            }
        }
    }
    
    // 处理注册成功
    func handleRegisterSuccess(user: User, accessToken: String, refreshToken: String) {
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
        currentUser = user
        isAuthenticated = true
    }
    
    // 处理登录成功
    func handleLoginSuccess(user: User, accessToken: String, refreshToken: String) {
        TokenManager.shared.saveTokens(access: accessToken, refresh: refreshToken)
        currentUser = user
        isAuthenticated = true
    }
    
    // 登出
    func logout() {
        TokenManager.shared.clearTokens()
        currentUser = nil
        isAuthenticated = false
    }
    
    // 检查认证状态
    func checkAuthState() async {
        guard let token = TokenManager.shared.accessToken else {
            logout()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: 调用后端 API 验证 token 并获取用户信息
            // 这里暂时只验证 token 是否存在
            isAuthenticated = true
        } catch {
            logout()
        }
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