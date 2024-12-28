import Foundation
import SwiftUI

@MainActor
class AdminViewModel: ObservableObject {
    private let service = CloudTemplateService.shared
    
    @Published var languageSections: [LanguageSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
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
            // 创建成功，不设置错误信息
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