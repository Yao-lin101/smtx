import Foundation
import SwiftUI

@MainActor
class CloudTemplateViewModel: ObservableObject {
    private let service = CloudTemplateService.shared
    private let store = LanguageSectionStore.shared
    private var hasInitialized = false
    private var hasLoadedTemplates = false
    private var currentLoadTask: Task<Void, Never>?
    
    // MARK: - Published Properties
    
    @Published var languageSections: [LanguageSection] = []
    @Published var templates: [CloudTemplateListItem] = []
    @Published var selectedTemplate: CloudTemplate?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @AppStorage("subscribedSections") private var subscribedSectionsData: Data = Data()
    
    // MARK: - Language Section Management
    
    func loadLanguageSections() async {
        print("🔄 Start loading language sections")
        isLoading = true
        errorMessage = nil
        
        do {
            // 先从本地加载订阅数据
            let localSubscribedSections = loadLocalSubscribedSections()
            
            // 从服务器获取最新数据
            var sections = try await service.fetchLanguageSections()
            
            // 使用本地数据更新订阅状态
            sections = sections.map { section in
                var updatedSection = section
                updatedSection.isSubscribed = localSubscribedSections.contains { $0.uid == section.uid }
                return updatedSection
            }
            
            languageSections = sections
            print("✅ Loaded \(languageSections.count) language sections")
        } catch TemplateError.unauthorized {
            print("❌ Unauthorized error")
            errorMessage = "请先登录"
            showError = true
        } catch TemplateError.serverError(let message) {
            print("❌ Server error: \(message)")
            errorMessage = message
            showError = true
        } catch {
            print("❌ Loading error: \(error)")
            errorMessage = "加载语言分区失败"
            showError = true
        }
        
        isLoading = false
        print("🏁 Finished loading language sections")
    }
    
    var subscribedSections: [LanguageSection] {
        store.sections.filter { $0.isSubscribed }
    }
    
    var unsubscribedSections: [LanguageSection] {
        languageSections.filter { !$0.isSubscribed }
    }
    
    // MARK: - Local Storage
    
    private func saveLocalSubscribedSections() {
        print("📝 保存订阅分区到本地，数量: \(subscribedSections.count)")
        let sections = subscribedSections
        if let data = try? JSONEncoder().encode(sections) {
            subscribedSectionsData = data
        }
    }
    
    private func loadLocalSubscribedSections() -> [LanguageSection] {
        if let sections = try? JSONDecoder().decode([LanguageSection].self, from: subscribedSectionsData) {
            print("📖 从本地加载订阅分区，数量: \(sections.count)")
            return sections
        }
        print("⚠️ 本地没有订阅分区数据")
        return []
    }
    
    // MARK: - Initial Loading
    
    func loadLocalData() {
        print("🔄 开始加载本地数据")
        // 从本地加载订阅数据
        languageSections = loadLocalSubscribedSections()
        print("✅ 完成本地数据加载，分区数量: \(languageSections.count)")
        
        // 如果是首次初始化，从服务器获取数据
        if !hasInitialized {
            Task {
                await fetchSubscribedSections()
            }
            hasInitialized = true
        }
    }
    
    func loadInitialData(selectedLanguageUid: String) async {
        // 1. 先从本地加载订阅数据
        let localSubscribedSections = loadLocalSubscribedSections()
        
        // 2. 加载语言分区
        await loadLanguageSections()
        
        // 3. 根据选中的分区加载模板
        if !selectedLanguageUid.isEmpty {
            // 检查选中的分区是否在已订阅列表中
            if let section = languageSections.first(where: { $0.uid == selectedLanguageUid }),
               localSubscribedSections.contains(where: { $0.uid == selectedLanguageUid }) {
                // 如果找到了保存的分区且已订阅，加载该分区的模板
                await loadTemplates(languageSectionUid: section.uid.replacingOccurrences(of: "-", with: ""))
            } else {
                // 如果找不到保存的分区或未订阅，加载所有模板
                await loadTemplates()
            }
        } else {
            // 如果没有选中的分区，加载所有模板
            await loadTemplates()
        }
    }
    
    // MARK: - Template Loading
    
    /// 加载模板列表
    /// - Parameter languageSectionUid: 可选的语言分区 UID
    func loadTemplates(languageSectionUid: String? = nil) async {
        currentLoadTask?.cancel()
        
        currentLoadTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                if let uid = languageSectionUid {
                    templates = try await service.fetchTemplates(languageSectionUid: uid)
                } else {
                    templates = try await service.fetchTemplates()
                }
            } catch {
                if !Task.isCancelled {
                    if let templateError = error as? TemplateError {
                        errorMessage = templateError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
            
            isLoading = false
        }
        
        await currentLoadTask?.value
    }
    
    /// 加载多个语言分区的模板
    /// - Parameter languageSectionUids: 语言分区 UID 数组
    func loadTemplates(languageSectionUids: [String]) async {
        currentLoadTask?.cancel()
        
        currentLoadTask = Task {
            isLoading = true
            do {
                templates = try await service.listTemplates(languageSectionUids: languageSectionUids)
            } catch {
                if !Task.isCancelled {
                    if let templateError = error as? TemplateError {
                        errorMessage = templateError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
            isLoading = false
        }
        
        await currentLoadTask?.value
    }
    
    func toggleSubscription(for section: LanguageSection) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let isSubscribed = try await service.subscribeLanguageSection(uid: section.uid)
                // 更新本地数据
                if let index = languageSections.firstIndex(where: { $0.uid == section.uid }) {
                    var updatedSection = section
                    updatedSection.isSubscribed = isSubscribed
                    languageSections[index] = updatedSection
                    // 保存到本地存储
                    saveLocalSubscribedSections()
                }
            } catch TemplateError.unauthorized {
                errorMessage = "请先登录"
                showError = true
            } catch TemplateError.serverError(let message) {
                errorMessage = message
                showError = true
            } catch {
                errorMessage = "操作失败"
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
                print("🔄 开始加载模板详情: \(uid)")
                selectedTemplate = try await service.fetchTemplate(uid: uid)
                print("✅ 模板加载成功:")
                print("- 标题: \(selectedTemplate?.title ?? "")")
                print("- 作者: \(selectedTemplate?.authorName ?? "未知")")
                print("- 头像: \(selectedTemplate?.authorAvatar ?? "无")")
            } catch TemplateError.unauthorized {
                errorMessage = "请先登录"
                showError = true
            } catch TemplateError.serverError(let message) {
                errorMessage = message
                showError = true
            } catch {
                print("❌ 加载模板失败: \(error)")
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
    
    // MARK: - Filtering
    
    func filteredTemplates(searchText: String) -> [CloudTemplateListItem] {
        guard !searchText.isEmpty else {
            return templates
        }
        return templates.filter { template in
            template.title.localizedCaseInsensitiveContains(searchText) ||
            template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func filteredSections(searchText: String) -> [LanguageSection] {
        guard !searchText.isEmpty else {
            return languageSections
        }
        return languageSections.filter { section in
            section.name.localizedCaseInsensitiveContains(searchText) ||
            (!section.chineseName.isEmpty && section.chineseName.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    func selectedLanguage(uid: String) -> LanguageSection? {
        store.sections.first { $0.uid == uid }
    }
    
    func fetchSubscribedSections() async {
        do {
            // 从云端获取订阅的语言分区
            let sections = try await CloudTemplateService.shared.fetchLanguageSections()
            // 更新 store 的数据，不需要 await
            store.updateSections(sections)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // 添加新方法
    func loadInitialTemplates(selectedLanguageUid: String) async {
        guard !hasLoadedTemplates else { return }
        
        if !selectedLanguageUid.isEmpty {
            let formattedUid = selectedLanguageUid.replacingOccurrences(of: "-", with: "")
            await loadTemplates(languageSectionUid: formattedUid)
        } else {
            let subscribedUids = subscribedSections.map { $0.uid.replacingOccurrences(of: "-", with: "") }
            if !subscribedUids.isEmpty {
                await loadTemplates(languageSectionUids: subscribedUids)
            } else {
                await loadTemplates()
            }
        }
        
        hasLoadedTemplates = true
    }
} 