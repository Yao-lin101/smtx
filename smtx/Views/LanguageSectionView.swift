import SwiftUI

// 时间轴项目行视图
struct TemplateRow: View {
    let template: TemplateFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.template.title)
                .font(.headline)
            
            HStack {
                Text(String(format: "时长：%.1f秒", template.template.totalDuration))
                Spacer()
                Text(template.metadata.createdAt, style: .date)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct LanguageSectionView: View {
    let language: String
    @EnvironmentObject private var router: NavigationRouter
    @State private var templates: [TemplateFile] = []
    
    var body: some View {
        List {
            ForEach(templates, id: \.metadata.id) { template in
                NavigationLink(value: Route.templateDetail(template)) {
                    TemplateRow(template: template)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        router.navigate(to: .createTemplate(language, template))
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.blue)
                    
                    Button(role: .destructive) {
                        deleteTemplate(template)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(language)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { router.navigate(to: .createTemplate(language)) }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadTemplates()
        }
    }
    
    private func loadTemplates() {
        do {
            let allTemplates = try TemplateStorage.shared.listTemplates()
            templates = allTemplates.filter { $0.template.language == language }
        } catch {
            print("Error loading templates: \(error)")
        }
    }
    
    private func deleteTemplate(_ template: TemplateFile) {
        do {
            try TemplateStorage.shared.deleteTemplate(templateId: template.metadata.id)
            loadTemplates()
        } catch {
            print("Error deleting template: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSectionView(language: "日语")
            .environmentObject(NavigationRouter())
    }
} 