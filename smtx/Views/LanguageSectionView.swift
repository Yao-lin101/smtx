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
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
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
            loadTemplates()
        }
    }
    
    private var galleryView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredTemplates, id: \.id) { template in
                    NavigationLink(value: Route.templateDetail(template.id ?? "")) {
                        TemplateRow(template: template, displayMode: .gallery)
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
                    TemplateRow(template: template, displayMode: .list)
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
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
    
    private func templateContextMenu(for template: Template) -> some View {
        Group {
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
            templates = allTemplates[language] ?? []
            refreshTrigger = UUID()
            print("✅ Loaded \(templates.count) templates for language: \(language)")
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
    }
    
    private var listLayout: some View {
        HStack(spacing: 12) {
            // 封面缩略图
            coverImageView(size: 60)
            
            // 标题和时长
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title ?? "")
                    .font(.headline)
                    .lineLimit(2)
                    .frame(height: 48, alignment: .topLeading)
                Text(formatDuration(template.totalDuration))
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
                Text(template.title ?? "")
                    .font(.headline)
                    .lineLimit(2)
                    .frame(height: 48, alignment: .topLeading)
                Text(formatDuration(template.totalDuration))
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
            if let imageData = template.coverImage,
               let image = UIImage(data: imageData) {
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
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)分\(String(format: "%02d", seconds))秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSectionView(language: "日语")
            .environmentObject(NavigationRouter())
    }
} 