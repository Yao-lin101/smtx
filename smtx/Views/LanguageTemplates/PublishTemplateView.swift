import SwiftUI

struct PublishTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PublishTemplateViewModel()
    let template: Template
    @State private var searchText = ""
    @State private var selectedSection: LanguageSection?
    
    private var filteredSections: [LanguageSection] {
        if searchText.isEmpty {
            return viewModel.languageSections
        }
        return viewModel.languageSections.filter { section in
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
                        // TODO: 实现发布逻辑
                        dismiss()
                    }
                    .disabled(selectedSection == nil)
                }
            }
            .task {
                await viewModel.loadLanguageSections()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .alert("错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
        }
    }
}

@MainActor
class PublishTemplateViewModel: ObservableObject {
    @Published private(set) var languageSections: [LanguageSection] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let service = CloudTemplateService.shared
    
    func loadLanguageSections() async {
        isLoading = true
        errorMessage = nil
        
        do {
            languageSections = try await service.fetchLanguageSections()
        } catch {
            errorMessage = "加载语言分区失败"
            showError = true
        }
        
        isLoading = false
    }
} 