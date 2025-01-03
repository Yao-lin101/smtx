import SwiftUI

struct PublishTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = LanguageSectionStore.shared
    @StateObject private var viewModel = PublishTemplateViewModel()
    let template: Template
    @State private var searchText = ""
    @State private var selectedSection: LanguageSection?
    
    private var filteredSections: [LanguageSection] {
        if searchText.isEmpty {
            return store.sections
        }
        return store.sections.filter { section in
            section.name.localizedCaseInsensitiveContains(searchText) ||
            section.chineseName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSections) { section in
                    Button {
                        selectedSection = selectedSection == section ? nil : section
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(section.name)
                                    .font(.headline)
                                if !section.chineseName.isEmpty {
                                    Text(section.chineseName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(section.templatesCount) 个模板")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedSection == section {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .searchable(text: $searchText, prompt: "搜索语言分区")
            .navigationTitle("选择发布分区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发布") {
                        if let selectedSection = selectedSection {
                            Task {
                                await viewModel.publishTemplate(template, to: selectedSection.uid)
                            }
                        }
                    }
                    .disabled(selectedSection == nil || viewModel.isPublishing)
                }
            }
            .task {
                await store.loadSections()
            }
            .overlay {
                if viewModel.isPublishing {
                    PublishProgressView(progress: viewModel.publishProgress)
                }
            }
            .alert("错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
            .onChange(of: viewModel.showSuccess) { success in
                if success {
                    dismiss()
                }
            }
            .toastManager()
        }
    }
}

struct PublishProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView("正在发布...", value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding()
        }
    }
}

@MainActor
class PublishTemplateViewModel: ObservableObject {
    private let service = CloudTemplateService.shared
    private let storage = TemplateStorage.shared
    private let toast = ToastManager.shared
    
    @Published private(set) var isPublishing = false
    @Published private(set) var publishProgress = 0.0
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    
    func publishTemplate(_ template: Template, to sectionUid: String) async {
        isPublishing = true
        publishProgress = 0.0
        showError = false
        errorMessage = nil
        
        do {
            // 1. 上传模板
            let response = try await service.uploadTemplate(template, to: sectionUid) { progress in
                Task { @MainActor in
                    self.publishProgress = progress
                }
            }
            
            // 2. 更新本地模板状态
            try storage.updateCloudStatus(
                templateId: template.id ?? "",
                cloudUid: response.uid,
                cloudVersion: template.version ?? "1.0"
            )
            
            // 3. 发送模板更新通知
            DispatchQueue.main.async {
                print("📣 Publishing templateDidUpdate notification")
                NotificationCenter.default.post(name: .templateDidUpdate, object: nil)
            }
            
            // 4. 显示成功提示
            toast.show("发布成功", type: .success)
            showSuccess = true
        } catch {
            if let templateError = error as? TemplateError {
                errorMessage = templateError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
        
        // 确保在最后设置进度和状态
        publishProgress = 1.0
        isPublishing = false
    }
    
    func updateTemplate(_ template: Template) async {
        isPublishing = true
        publishProgress = 0.0
        showError = false
        errorMessage = nil
        
        do {
            // 1. 更新模板
            let response = try await service.updateTemplate(template) { progress in
                Task { @MainActor in
                    self.publishProgress = progress
                }
            }
            
            // 2. 更新本地模板状态
            try storage.updateCloudStatus(
                templateId: template.id ?? "",
                cloudUid: response.uid,
                cloudVersion: template.version ?? "1.0"
            )
            
            // 3. 发送模板更新通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .templateDidUpdate, object: nil)
            }
            
            // 4. 显示成功提示
            toast.show("更新成功", type: .success)
            showSuccess = true
        } catch {
            if let templateError = error as? TemplateError {
                errorMessage = templateError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            toast.show("更新失败：\(errorMessage ?? "未知错误")", type: .error)
            showError = true
        }
        
        // 确保在最后设置进度和状态
        publishProgress = 1.0
        isPublishing = false
    }
} 
