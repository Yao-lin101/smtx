import SwiftUI

struct PublishTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var selectedSection: LanguageSection?
    @State private var searchText = ""
    
    let template: Template
    
    private var filteredSections: [LanguageSection] {
        guard !searchText.isEmpty else { return viewModel.languageSections }
        return viewModel.languageSections.filter { section in
            section.name.localizedCaseInsensitiveContains(searchText) ||
            (!section.chineseName.isEmpty && section.chineseName.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private func sectionRow(_ section: LanguageSection) -> some View {
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
            
            if selectedSection?.uid == section.uid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSection = section
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSections) { section in
                    sectionRow(section)
                }
            }
            .searchable(text: $searchText, prompt: "搜索语言分区")
            .navigationTitle("发布模板")
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
        }
    }
}

#Preview {
    PublishTemplateView(template: Template())
} 