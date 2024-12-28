import Foundation

@MainActor
class CloudTemplateViewModel: ObservableObject {
    private let service = CloudTemplateService.shared
    
    // MARK: - Published Properties
    
    @Published var languageSections: [LanguageSection] = []
    @Published var templates: [CloudTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Language Section Management
    
    func loadLanguageSections() {
        Task {
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
    }
    
    func createLanguageSection(name: String) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let newSection = try await service.createLanguageSection(name: name)
                languageSections.append(newSection)
                // 按名称重新排序
                languageSections.sort { $0.name < $1.name }
            } catch CloudTemplateError.unauthorized {
                errorMessage = "请先登录"
                showError = true
            } catch CloudTemplateError.serverError(let message) {
                errorMessage = message
                showError = true
            } catch {
                errorMessage = "创建语言分区失败"
                showError = true
            }
            
            isLoading = false
        }
    }
    
    func deleteLanguageSection(uid: String) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                try await service.deleteLanguageSection(uid: uid)
                languageSections.removeAll { $0.uid == uid }
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
    }
    
    // MARK: - Template Management
    
    func loadTemplate(_ uid: String) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let template = try await service.fetchTemplate(uid: uid)
                templates = [template]
            } catch CloudTemplateError.unauthorized {
                errorMessage = "请先登录"
                showError = true
            } catch CloudTemplateError.serverError(let message) {
                errorMessage = message
                showError = true
            } catch {
                errorMessage = "加载模板失败"
                showError = true
            }
            
            isLoading = false
        }
    }
    
    func loadTemplates(languageSection: String? = nil, tag: String? = nil, authorUid: String? = nil) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                templates = try await service.fetchTemplates(
                    languageSection: languageSection,
                    tag: tag,
                    authorUid: authorUid
                )
            } catch CloudTemplateError.unauthorized {
                errorMessage = "请先登录"
                showError = true
            } catch CloudTemplateError.serverError(let message) {
                errorMessage = message
                showError = true
            } catch {
                errorMessage = "加载模板失败"
                showError = true
            }
            
            isLoading = false
        }
    }
    
    func likeTemplate(uid: String) {
        Task {
            do {
                let isLiked = try await service.likeTemplate(uid: uid)
                // 这里可以更新模板的点赞状态
                print("Template \(uid) like status: \(isLiked)")
            } catch {
                errorMessage = "操作失败"
                showError = true
            }
        }
    }
    
    func collectTemplate(uid: String) {
        Task {
            do {
                let isCollected = try await service.collectTemplate(uid: uid)
                // 这里可以更新模板的收藏状态
                print("Template \(uid) collection status: \(isCollected)")
            } catch {
                errorMessage = "操作失败"
                showError = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    func getLanguageSectionName(uid: String) -> String {
        languageSections.first { $0.uid == uid }?.name ?? "未知语言"
    }
} 