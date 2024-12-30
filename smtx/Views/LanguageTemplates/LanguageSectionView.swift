import SwiftUI

// 展示模式枚举
enum TemplateListDisplayMode: String {
    case list
    case gallery
}

struct LanguageSectionView: View {
    let language: String
    @EnvironmentObject private var router: NavigationRouter
    @State private var templates: [Template] = []
    @State private var refreshTrigger = UUID()
    @AppStorage("templateListDisplayMode") private var displayMode: TemplateListDisplayMode = .list
    @State private var showingDeleteAlert = false
    @State private var templateToDelete: Template?
    @State private var searchText = ""
    @Environment(\.userStore) private var userStore
    @State private var templateToPublish: Template?
    @State private var showingPublishSheet = false
    @State private var lastUpdateTime = Date()
    private let debounceInterval: TimeInterval = 0.5
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 16)
    ]
    
    private var filteredTemplates: [Template] {
        if searchText.isEmpty {
            return templates
        }
        
        return templates.filter { template in
            if let title = template.title?.lowercased(),
               title.contains(searchText.lowercased()) {
                return true
            }
            
            let tags = TemplateStorage.shared.getTemplateTags(template)
            return tags.contains { tag in
                tag.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                searchBar
                
                switch displayMode {
                case .list:
                    listView
                case .gallery:
                    galleryView
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
                    
                    Button {
                        router.navigate(to: .createTemplate(language, nil))
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .confirmationDialog("所有模板和录音记录都将删除。", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("删除模板", role: .destructive) {
                if let template = templateToDelete,
                   let templateId = template.id {
                    deleteTemplate(templateId)
                }
                templateToDelete = nil
            }
            Button("取消", role: .cancel) {
                templateToDelete = nil
            }
        }
        .onAppear {
            loadTemplates()
        }
        .onReceive(NotificationCenter.default.publisher(for: .templateDidUpdate)) { _ in
            let now = Date()
            if now.timeIntervalSince(lastUpdateTime) >= debounceInterval {
                loadTemplates()
                lastUpdateTime = now
            }
        }
        .sheet(item: $templateToPublish) { template in
            PublishTemplateView(template: template)
        }
    }
    
    private var galleryView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredTemplates, id: \.id) { template in
                    NavigationLink(value: Route.templateDetail(template.id ?? "")) {
                        GalleryTemplateRow(template: template)
                            .id("\(template.id ?? "")_\(template.updatedAt?.timeIntervalSince1970 ?? 0)")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        templateContextMenu(for: template)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var listView: some View {
        List {
            ForEach(filteredTemplates, id: \.id) { template in
                NavigationLink(value: Route.templateDetail(template.id ?? "")) {
                    TemplateRow(template: template)
                        .id("\(template.id ?? "")_\(template.updatedAt?.timeIntervalSince1970 ?? 0)")
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        templateToDelete = template
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .tint(.red)
                    
                    Button {
                        router.navigate(to: .createTemplate(language, template.id))
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.blue)
                    
                    if userStore.isAuthenticated {
                        if template.cloudUid == nil {
                            Button {
                                templateToPublish = template
                                showingPublishSheet = true
                            } label: {
                                Label("发布", systemImage: "square.and.arrow.up")
                            }
                            .tint(.orange)
                        } else if let localVersion = template.version,
                                  let cloudVersion = template.cloudVersion,
                                  localVersion > cloudVersion {
                            Button {
                                templateToPublish = template
                                showingPublishSheet = true
                            } label: {
                                Label("发布更新", systemImage: "square.and.arrow.up")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
    
    private func templateContextMenu(for template: Template) -> some View {
        Group {
            if userStore.isAuthenticated {
                if template.cloudUid == nil {
                    Button {
                        templateToPublish = template
                        showingPublishSheet = true
                    } label: {
                        Label("发布", systemImage: "square.and.arrow.up")
                    }
                } else if let localVersion = template.version,
                          let cloudVersion = template.cloudVersion,
                          localVersion > cloudVersion {
                    Button {
                        templateToPublish = template
                        showingPublishSheet = true
                    } label: {
                        Label("发布更新", systemImage: "square.and.arrow.up")
                    }
                }
            }
            
            Button {
                router.navigate(to: .createTemplate(language, template.id))
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                templateToDelete = template
                showingDeleteAlert = true
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
            let allTemplates = try TemplateStorage.shared.listTemplatesByLanguage()
            let newTemplates = allTemplates[language] ?? []
            if templates != newTemplates {
                templates = newTemplates
                refreshTrigger = UUID()
                print("✅ Loaded \(templates.count) templates for language: \(language)")
            }
        } catch {
            print("❌ Failed to load templates: \(error)")
        }
    }
    
    private func deleteTemplate(_ templateId: String) {
        do {
            try TemplateStorage.shared.deleteTemplate(templateId: templateId)
            loadTemplates() // 删除后重新加载整个列表
            print("✅ Template deleted and list reloaded: \(templateId)")
        } catch {
            print("❌ Failed to delete template: \(error)")
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索标题或标签", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Helper Views
struct TemplateRow: View {
    let template: Template
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面图片
            if let imageData = template.coverImage,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                Text(template.title ?? "")
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(alignment: .center, spacing: 8) {
                    // 时长
                    Text(formatDuration(template.totalDuration))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 分隔点
                    if let tags = template.tags as? [String], !tags.isEmpty {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                    }
                    
                    // 标签
                    if let tags = template.tags as? [String] {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct GalleryTemplateRow: View {
    let template: Template
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面图片
            if let imageData = template.coverImage,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 120)
            }
            
            // 标题区域 - 固定两行高度
            Text(template.title ?? "")
                .font(.headline)
                .lineLimit(2)
                .frame(height: 44, alignment: .topLeading) // 固定两行高度
            
            // 时长和标签区域 - 固定两行高度
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：时长和第一个标签
                HStack(spacing: 6) {
                    Text(formatDuration(template.totalDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let tags = template.tags as? [String], !tags.isEmpty {
                        // 分隔点
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                        
                        // 第一个标签
                        Text(tags[0])
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                }
                
                // 第二行：剩余标签的滚动视图
                if let tags = template.tags as? [String], tags.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(tags.dropFirst()), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(height: 20) // 固定第二行高度
                }
            }
            .frame(height: 44, alignment: .topLeading) // 固定总高度
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        LanguageSectionView(language: "日语")
            .environmentObject(NavigationRouter())
    }
} 