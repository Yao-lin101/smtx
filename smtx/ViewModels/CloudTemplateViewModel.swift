import Foundation
import SwiftUI

@MainActor
class CloudTemplateViewModel: ObservableObject {
    private let service = CloudTemplateService.shared
    
    // MARK: - Published Properties
    
    @Published var languageSections: [LanguageSection] = []
    @Published var templates: [CloudTemplate] = []
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
        languageSections.filter { $0.isSubscribed }
    }
    
    var unsubscribedSections: [LanguageSection] {
        languageSections.filter { !$0.isSubscribed }
    }
    
    // MARK: - Local Storage
    
    private func saveLocalSubscribedSections() {
        let sections = subscribedSections
        if let data = try? JSONEncoder().encode(sections) {
            subscribedSectionsData = data
        }
    }
    
    private func loadLocalSubscribedSections() -> [LanguageSection] {
        if let sections = try? JSONDecoder().decode([LanguageSection].self, from: subscribedSectionsData) {
            return sections
        }
        return []
    }
    
    // MARK: - Initial Loading
    
    func loadLocalData() {
        // 从本地加载订阅数据
        languageSections = loadLocalSubscribedSections()
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
                await loadTemplates(languageSection: section.name)
            } else {
                // 如果找不到保存的分区或未订阅，加载所有模板
                await loadTemplates()
            }
        } else {
            // 如果没有选中的分区，加载所有模板
            await loadTemplates()
        }
    }
    
    func loadTemplates(languageSection: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            templates = try await service.fetchTemplates(
                languageSection: languageSection
            )
        } catch TemplateError.unauthorized {
            errorMessage = "请先登录"
            showError = true
        } catch TemplateError.serverError(let message) {
            errorMessage = message
            showError = true
        } catch {
            errorMessage = "加载模板失败"
            showError = true
        }
        
        isLoading = false
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
                let template = try await service.fetchTemplate(uid: uid)
                templates = [template]
            } catch TemplateError.unauthorized {
                errorMessage = "请先登录"
                showError = true
            } catch TemplateError.serverError(let message) {
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