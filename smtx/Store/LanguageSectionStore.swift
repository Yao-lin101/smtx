import Foundation
import SwiftUI

extension Notification.Name {
    static let languageSectionSubscriptionDidChange = Notification.Name("languageSectionSubscriptionDidChange")
}

@MainActor
class LanguageSectionStore: ObservableObject {
    static let shared = LanguageSectionStore()
    
    private let service = CloudTemplateService.shared
    
    @Published private(set) var sections: [LanguageSection] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    @AppStorage("subscribedSections") private var subscribedSectionsData: Data = Data()
    
    private var lastRefreshTime: Date?
    private let cacheTimeout: TimeInterval = 300 // 5分钟缓存
    
    private init() {}
    
    // MARK: - 基础数据加载
    
    func loadSections() async {
        // 如果有缓存且未超时，直接返回
        if !sections.isEmpty,
           let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < cacheTimeout {
            return
        }
        
        await refresh()
    }
    
    func refresh() async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            sections = try await service.fetchLanguageSections()
            lastRefreshTime = Date()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - 订阅管理
    
    private func notifySubscriptionChange() {
        NotificationCenter.default.post(
            name: .languageSectionSubscriptionDidChange,
            object: nil,
            userInfo: ["subscribedSections": sections.filter { $0.isSubscribed }]
        )
    }
    
    func toggleSubscription(for section: LanguageSection) {
        Task {
            isLoading = true
            errorMessage = nil
            showError = false
            
            do {
                let isSubscribed = try await service.subscribeLanguageSection(uid: section.uid)
                if let index = sections.firstIndex(where: { $0.uid == section.uid }) {
                    sections[index].isSubscribed = isSubscribed
                    saveLocalSubscribedSections()
                    notifySubscriptionChange()
                }
            } catch {
                handleError(error)
            }
            
            isLoading = false
        }
    }
    
    // MARK: - 管理员操作
    
    func createLanguageSection(name: String, chineseName: String = "") async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            _ = try await service.createLanguageSection(name: name, chineseName: chineseName)
            await refresh() // 创建成功后刷新列表
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func updateLanguageSection(uid: String, name: String, chineseName: String = "") async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            _ = try await service.updateLanguageSection(uid: uid, name: name, chineseName: chineseName)
            await refresh() // 更新成功后刷新列表
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func deleteLanguageSection(uid: String) async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await service.deleteLanguageSection(uid: uid)
            await refresh() // 删除成功后刷新列表
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Local Storage
    
    private func saveLocalSubscribedSections() {
        let subscribedSections = sections.filter { $0.isSubscribed }
        if let data = try? JSONEncoder().encode(subscribedSections) {
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
        sections = loadLocalSubscribedSections()
    }
    
    func loadInitialData() async {
        // 1. 先从本地加载订阅数据
        let localSubscribedSections = loadLocalSubscribedSections()
        
        // 2. 从服务器获取最新数据
        await refresh()
        
        // 3. 使用本地数据更新订阅状态
        sections = sections.map { section in
            var updatedSection = section
            updatedSection.isSubscribed = localSubscribedSections.contains { $0.uid == section.uid }
            return updatedSection
        }
    }
    
    private func handleError(_ error: Error) {
        if let templateError = error as? TemplateError {
            switch templateError {
            case .unauthorized:
                errorMessage = "请先登录"
            case .serverError(let message):
                errorMessage = message
            case .networkError(let message):
                errorMessage = "网络错误：\(message)"
            case .decodingError:
                errorMessage = "数据解析错误"
            case .operationFailed(let message):
                errorMessage = message
            case .invalidTemplate:
                errorMessage = "无效的模板"
            case .templateNotFound:
                errorMessage = "模板不存在"
            case .invalidLanguageSection:
                errorMessage = "无效的语言分区"
            case .languageSectionNotFound:
                errorMessage = "语言分区不存在"
            case .noChanges:
                errorMessage = "没有需要更新的内容"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
    
    func cleanup() {
        sections = []
        lastRefreshTime = nil
        subscribedSectionsData = Data()
    }
} 