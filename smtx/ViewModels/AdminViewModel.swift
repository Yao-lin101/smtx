import Foundation

@MainActor
class AdminViewModel: ObservableObject {
    private let service = CloudTemplateService.shared
    private let authService = AuthService.shared
    
    // MARK: - Published Properties
    
    @Published var languageSections: [LanguageSection] = []
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var hasMoreUsers = true
    @Published var currentPage = 1
    
    // MARK: - Language Section Management
    
    func loadLanguageSections() async {
        isLoading = true
        errorMessage = nil
        
        do {
            languageSections = try await service.fetchLanguageSections()
        } catch CloudTemplateError.unauthorized {
            errorMessage = "请先登录"
            showError = true
        } catch CloudTemplateError.serverError(let message) {
            errorMessage = message
            showError = true
        } catch {
            errorMessage = "加载语言分区失败"
            showError = true
        }
        
        isLoading = false
    }
    
    func createLanguageSection(name: String, chineseName: String = "") async {
        print("🔄 开始创建语言分区: \(name)")
        isLoading = true
        errorMessage = nil
        showError = false  // 重置错误状态
        
        do {
            let section = try await service.createLanguageSection(name: name, chineseName: chineseName)
            print("✅ 语言分区创建成功: \(section.name)")
            // 创建成功后重新加载列表
            await loadLanguageSections()
        } catch CloudTemplateError.unauthorized {
            print("❌ 未授权错误")
            errorMessage = "请先登录"
            showError = true
        } catch CloudTemplateError.serverError(let message) {
            print("❌ 服务器错误: \(message)")
            errorMessage = message
            showError = true
        } catch {
            print("❌ 创建失败: \(error)")
            errorMessage = "创建语言分区失败"
            showError = true
        }
        
        isLoading = false
    }
    
    func deleteLanguageSection(uid: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await service.deleteLanguageSection(uid: uid)
            // 删除成功后重新加载列表
            await loadLanguageSections()
        } catch CloudTemplateError.unauthorized {
            errorMessage = "请先登录"
            showError = true
        } catch CloudTemplateError.serverError(let message) {
            errorMessage = message
            showError = true
        } catch {
            errorMessage = "删除语言分区失败"
            showError = true
        }
        
        isLoading = false
    }
    
    func updateLanguageSection(uid: String, name: String, chineseName: String = "") async {
        isLoading = true
        showError = false
        errorMessage = nil
        
        do {
            _ = try await service.updateLanguageSection(uid: uid, name: name, chineseName: chineseName)
            // 更新成功后重新加载列表
            await loadLanguageSections()
        } catch let error as CloudTemplateError {
            showError = true
            errorMessage = error.localizedDescription
        } catch {
            showError = true
            errorMessage = "更新语言分区失败"
        }
        
        isLoading = false
    }
    
    // MARK: - User Management
    
    // 用户列表过滤
    func filteredUsers(searchText: String, showBanned: Bool) -> [User] {
        let filtered = users.filter { user in
            let matchesSearch = searchText.isEmpty ||
                user.uid.localizedCaseInsensitiveContains(searchText) ||
                user.username.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = user.isActive != showBanned
            return matchesSearch && matchesStatus
        }
        return filtered
    }
    
    // 加载用户列表
    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await authService.fetchUsers()
            users = response.results
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = "加载用户列表失败"
            showError = true
        }
        
        isLoading = false
    }
    
    // 封禁/解封用户
    func toggleUserBan(uid: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await authService.toggleUserBan(uid: uid)
            // 更新本地用户列表中的状态
            if let index = users.firstIndex(where: { $0.uid == uid }) {
                users[index].isActive.toggle()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func searchUsers(query: String, reset: Bool = true) async {
        if reset {
            currentPage = 1
            users = []
            hasMoreUsers = true
        }
        
        guard hasMoreUsers else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await authService.fetchUsers(search: query, page: currentPage)
            if reset {
                users = response.results
            } else {
                users.append(contentsOf: response.results)
            }
            hasMoreUsers = response.next != nil
            currentPage += 1
        } catch AuthError.unauthorized {
            errorMessage = "请先登录"
            showError = true
        } catch AuthError.serverError(let message) {
            errorMessage = message
            showError = true
        } catch {
            errorMessage = "加载用户列表失败"
            showError = true
        }
        
        isLoading = false
    }
    
    func loadMoreIfNeeded(currentUser: User) async {
        // 如果当前用户是列表中的最后几个，就加载更多
        guard !isLoading && hasMoreUsers,
              let index = users.firstIndex(where: { $0.id == currentUser.id }),
              index >= users.count - 5 else {
            return
        }
        
        await searchUsers(query: "", reset: false)
    }
} 