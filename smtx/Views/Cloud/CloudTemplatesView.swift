import SwiftUI

struct CloudTemplatesView: View {
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var selectedLanguage: LanguageSection?
    @State private var showingLanguageSelector = false
    @State private var showingSubscribeSheet = false
    @AppStorage("cloudTemplateDisplayMode") private var displayMode: TemplateListDisplayMode = .list
    @State private var searchText = ""
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 16)
    ]
    
    private var filteredTemplates: [CloudTemplate] {
        if searchText.isEmpty {
            return viewModel.templates
        }
        
        return viewModel.templates.filter { template in
            template.title.localizedCaseInsensitiveContains(searchText) ||
            template.tags.contains { tag in
                tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    // 语言选择器
                    Menu {
                        ForEach(viewModel.languageSections) { section in
                            Button(section.name) {
                                selectedLanguage = section
                                viewModel.loadTemplates(languageSection: section.name)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedLanguage?.name ?? "选择语言")
                                .font(.headline)
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // 显示模式切换和添加订阅按钮
                    HStack(spacing: 16) {
                        Button(action: toggleDisplayMode) {
                            Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
                        
                        Button {
                            showingSubscribeSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // 搜索栏
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
                .padding(.bottom)
                
                // 模板列表/网格视图
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTemplates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("暂无模板")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text("当前语言分区还没有模板")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Group {
                        switch displayMode {
                        case .list:
                            listView
                        case .gallery:
                            galleryView
                        }
                    }
                }
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showingSubscribeSheet) {
            SubscribeLanguageView()
        }
        .onAppear {
            viewModel.loadLanguageSections()
        }
    }
    
    private var listView: some View {
        List {
            ForEach(filteredTemplates) { template in
                NavigationLink(value: Route.cloudTemplateDetail(template.uid)) {
                    CloudTemplateRow(template: template)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            if let section = selectedLanguage {
                viewModel.loadTemplates(languageSection: section.name)
            }
        }
    }
    
    private var galleryView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredTemplates) { template in
                    NavigationLink(value: Route.cloudTemplateDetail(template.uid)) {
                        CloudTemplateCard(template: template)
                    }
                }
            }
            .padding(16)
        }
        .refreshable {
            if let section = selectedLanguage {
                viewModel.loadTemplates(languageSection: section.name)
            }
        }
    }
    
    private func toggleDisplayMode() {
        withAnimation {
            displayMode = displayMode == .list ? .gallery : .list
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CloudTemplatesView()
            .environmentObject(NavigationRouter())
    }
}

// MARK: - Supporting Views

struct CloudTemplateRow: View {
    let template: CloudTemplate
    
    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            AsyncImage(url: URL(string: template.coverThumbnail)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(.secondary)
                    Text(template.tags.joined(separator: ", "))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .font(.caption)
            }
            
            Spacer()
            
            // 使用次数
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(template.usageCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("使用")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CloudTemplateCard: View {
    let template: CloudTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面图
            AsyncImage(url: URL(string: template.coverThumbnail)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 标题
            Text(template.title)
                .font(.headline)
                .lineLimit(2)
            
            // 标签
            if !template.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(template.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            // 使用次数
            HStack {
                Spacer()
                Text("\(template.usageCount) 次使用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct SubscribeLanguageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var searchText = ""
    
    var filteredSections: [LanguageSection] {
        if searchText.isEmpty {
            return viewModel.languageSections
        }
        return viewModel.languageSections.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredSections) { section in
                    HStack {
                        Text(section.name)
                        Spacer()
                        Text("\(section.templatesCount) 个模板")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索语言分区")
            .navigationTitle("订阅语言分区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadLanguageSections()
        }
    }
} 