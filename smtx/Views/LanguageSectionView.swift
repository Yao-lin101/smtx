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
                        .id("\(template.metadata.id)_\(template.metadata.updatedAt.timeIntervalSince1970)")
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
                // 从磁盘加载最新的模板数据
                do {
                    let latestTemplate = try TemplateStorage.shared.loadTemplate(templateId: updatedTemplate.metadata.id)
                    // 先移除旧的模板
                    templates.removeAll { $0.metadata.id == latestTemplate.metadata.id }
                    // 添加新的模板
                    templates.append(latestTemplate)
                    // 重新排序
                    templates.sort { $0.metadata.updatedAt > $1.metadata.updatedAt }
                    // 强制刷新视图
                    refreshTrigger = UUID()
                } catch {
                    print("Error loading updated template: \(error)")
                }
            }
        }
    }
    
    private func loadTemplates() {
        do {
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
            templates.removeAll { $0.metadata.id == template.metadata.id }
            refreshTrigger = UUID()
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