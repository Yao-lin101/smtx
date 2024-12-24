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
                Text("更新于：\(template.metadata.updatedAt, style: .date)")
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
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        List {
            ForEach(templates, id: \.metadata.id) { template in
                NavigationLink(value: Route.templateDetail(template)) {
                    TemplateRow(template: template)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteTemplate(template)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    
                    Button {
                        router.navigate(to: .createTemplate(language, template))
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .id(refreshTrigger)
        .navigationTitle(language)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    router.navigate(to: .createTemplate(language, nil))
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadTemplates()
        }
        .onReceive(NotificationCenter.default.publisher(for: .templateDidUpdate)) { notification in
            if let updatedTemplate = notification.object as? TemplateFile,
               updatedTemplate.template.language == language {
                loadTemplates()
            }
        }
    }
    
    private func loadTemplates() {
        do {
            templates.removeAll()
            templates = try TemplateStorage.shared.listTemplates()
                .filter { $0.template.language == language }
                .sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
            refreshTrigger = UUID()
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