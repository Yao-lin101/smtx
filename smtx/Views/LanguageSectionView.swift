import SwiftUI

// 展示模式枚举
enum TemplateListDisplayMode: String {
    case list
    case gallery
}

// 时间轴项目行视图
struct TemplateRow: View {
    let template: TemplateFile
    @State private var coverImage: UIImage?
    let displayMode: TemplateListDisplayMode
    
    var body: some View {
        Group {
            switch displayMode {
            case .list:
                listLayout
            case .gallery:
                galleryLayout
            }
        }
        .onAppear {
            loadCoverImage()
        }
    }
    
    private var listLayout: some View {
        HStack(spacing: 12) {
            // 封面缩略图
            coverImageView(size: 60)
            
            // 标题和时长
            VStack(alignment: .leading, spacing: 4) {
                Text(template.template.title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(height: 48, alignment: .topLeading)
                Text(String(format: "%.1f秒", template.template.totalDuration))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(height: 76)
        .padding(.vertical, 4)
    }
    
    private var galleryLayout: some View {
        VStack(spacing: 8) {
            // 封面缩略图
            coverImageView(size: 120)
            
            // 标题和时长
            VStack(alignment: .leading, spacing: 4) {
                Text(template.template.title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(height: 48, alignment: .topLeading)
                Text(String(format: "%.1f秒", template.template.totalDuration))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(height: 200)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func coverImageView(size: CGFloat) -> some View {
        Group {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 4/3, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size * 4/3, height: size)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }
        }
    }
    
    private func loadCoverImage() {
        guard let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id),
              let imageData = try? Data(contentsOf: baseURL.appendingPathComponent(template.template.coverImage)),
              let image = UIImage(data: imageData) else {
            return
        }
        coverImage = image
    }
}

struct LanguageSectionView: View {
    let language: String
    @EnvironmentObject private var router: NavigationRouter
    @State private var templates: [TemplateFile] = []
    @State private var refreshTrigger = UUID()
    @AppStorage("templateListDisplayMode") private var displayMode: TemplateListDisplayMode = .list
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        Group {
            switch displayMode {
            case .list:
                listView
            case .gallery:
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(templates, id: \.metadata.id) { template in
                            NavigationLink(value: Route.templateDetail(template)) {
                                TemplateRow(template: template, displayMode: .gallery)
                                    .id("\(template.metadata.id)_\(template.metadata.updatedAt.timeIntervalSince1970)")
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                templateContextMenu(for: template)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .id(refreshTrigger)
        .navigationTitle(language)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: toggleDisplayMode) {
                        Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                    }
                    
                    Button(action: {
                        router.navigate(to: .createTemplate(language, nil))
                    }) {
                        Image(systemName: "plus")
                    }
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
    
    private var listView: some View {
        List {
            ForEach(templates, id: \.metadata.id) { template in
                NavigationLink(value: Route.templateDetail(template)) {
                    TemplateRow(template: template, displayMode: .list)
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
    }
    
    private func templateContextMenu(for template: TemplateFile) -> some View {
        Group {
            Button {
                router.navigate(to: .createTemplate(language, template))
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                deleteTemplate(template)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private func toggleDisplayMode() {
        withAnimation {
            displayMode = displayMode == .list ? .gallery : .list
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