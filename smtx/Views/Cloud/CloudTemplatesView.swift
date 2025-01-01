import SwiftUI

struct CloudTemplatesView: View {
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = CloudTemplateViewModel()
    @AppStorage("selectedLanguageUid") private var selectedLanguageUid: String = ""
    @AppStorage("cloudTemplateDisplayMode") private var displayMode: TemplateListDisplayMode = .list
    @State private var showingSubscribeSheet = false
    @State private var searchText = ""
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                // 顶部工具栏
                toolbarView
                
                // 搜索栏
                searchBarView
                
                // 内容视图
                contentView
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showingSubscribeSheet) {
            viewModel.loadLocalData()
        } content: {
            SubscribeLanguageView(searchText: $searchText)
        }
        .task {
            // 1. 加载分区数据
            viewModel.loadLocalData()
            
            // 2. 只在第一次加载模板
            await viewModel.loadInitialTemplates(selectedLanguageUid: selectedLanguageUid)
        }
        .onChange(of: viewModel.subscribedSections) { sections in
            handleSubscriptionChange(sections)
        }
    }
    
    // MARK: - Subviews
    
    private var toolbarView: some View {
        HStack {
            languageSelectorMenu
            Spacer()
            toolbarButtons
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var languageSelectorMenu: some View {
        Menu {
            languageSelectorContent
        } label: {
            HStack {
                Text(viewModel.selectedLanguage(uid: selectedLanguageUid)?.name ?? "全部")
                    .font(.headline)
                Image(systemName: "chevron.down")
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    
    private var languageSelectorContent: some View {
        Group {
            if viewModel.subscribedSections.isEmpty {
                Text("无")
            } else {
                Button {
                    selectLanguage("")
                } label: {
                    HStack {
                        Text("全部")
                        if selectedLanguageUid.isEmpty {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                ForEach(viewModel.subscribedSections) { section in
                    Button {
                        selectLanguage(section.uid)
                    } label: {
                        HStack {
                            Text(section.name)
                            if selectedLanguageUid == section.uid {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var toolbarButtons: some View {
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
    
    private var searchBarView: some View {
        SearchBar(text: $searchText)
            .padding(.horizontal)
            .padding(.bottom)
    }
    
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredTemplates(searchText: searchText).isEmpty {
                emptyStateView
            } else {
                templateListView
            }
        }
        .refreshable {
            // 只刷新当前分区的模板
            if !selectedLanguageUid.isEmpty {
                let formattedUid = selectedLanguageUid.replacingOccurrences(of: "-", with: "")
                await viewModel.loadTemplates(languageSectionUid: formattedUid)
            } else {
                let subscribedUids = viewModel.subscribedSections.map { $0.uid.replacingOccurrences(of: "-", with: "") }
                if !subscribedUids.isEmpty {
                    await viewModel.loadTemplates(languageSectionUids: subscribedUids)
                } else {
                    await viewModel.loadTemplates()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func selectLanguage(_ uid: String) {
        selectedLanguageUid = uid
        Task {
            if uid.isEmpty {
                // 加载所有订阅分区的模板
                let sectionUids = viewModel.subscribedSections.map { $0.uid.replacingOccurrences(of: "-", with: "") }
                await viewModel.loadTemplates(languageSectionUids: sectionUids)
            } else {
                // 加载特定分区的模板，使用 UID
                await viewModel.loadTemplates(languageSectionUid: uid.replacingOccurrences(of: "-", with: ""))
            }
        }
    }
    
    private func handleSubscriptionChange(_ sections: [LanguageSection]) {
        if !selectedLanguageUid.isEmpty && !sections.contains(where: { $0.uid == selectedLanguageUid }) {
            selectedLanguageUid = ""
            Task {
                await viewModel.loadTemplates()
            }
        }
    }
    
    private func toggleDisplayMode() {
        withAnimation {
            displayMode = displayMode == .list ? .gallery : .list
        }
    }
    
    // 添加SearchBar组件
    private struct SearchBar: View {
        @Binding var text: String
        
        var body: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索标题或标签", text: $text)
                    .textFieldStyle(.plain)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    
    // 添加空状态视图
    private var emptyStateView: some View {
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
    }
    
    // 添加模板列表视图
    private var templateListView: some View {
        Group {
            switch displayMode {
            case .list:
                List {
                    ForEach(viewModel.filteredTemplates(searchText: searchText)) { template in
                        NavigationLink(value: Route.cloudTemplateDetail(template.uid)) {
                            CloudTemplateRow(template: template)
                        }
                    }
                }
                .listStyle(.plain)
            case .gallery:
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.filteredTemplates(searchText: searchText)) { template in
                            NavigationLink(value: Route.cloudTemplateDetail(template.uid)) {
                                CloudTemplateCard(template: template)
                            }
                        }
                    }
                    .padding(16)
                }
            }
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
    let template: CloudTemplateListItem
    @State private var coverImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面图片
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 120, height: 90)
                }
            }
            .task {
                let url = URL(string: template.fullCoverThumbnail)!
                do {
                    coverImage = try await ImageCacheManager.shared.loadImage(from: url)
                } catch {
                    print("Error loading image: \(error)")
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                Text(template.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(alignment: .center, spacing: 8) {
                    // 时长
                    Text(formatDuration(template.duration))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !template.tags.isEmpty {
                        // 分隔点
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                        
                        // 第一个标签
                        Text(template.tags[0])
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                }
                
                // 剩余标签
                if template.tags.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(template.tags.dropFirst()), id: \.self) { tag in
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
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct CloudTemplateCard: View {
    let template: CloudTemplateListItem
    @State private var coverImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面图片
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 120)
                }
            }
            .task {
                let url = URL(string: template.fullCoverThumbnail)!
                do {
                    coverImage = try await ImageCacheManager.shared.loadImage(from: url)
                } catch {
                    print("Error loading image: \(error)")
                }
            }
            
            // 标题区域 - 固定两行高度
            Text(template.title)
                .font(.headline)
                .lineLimit(2)
                .frame(height: 44, alignment: .topLeading)
            
            // 时长和标签区域 - 固定两行高度
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：时长和第一个标签
                HStack(spacing: 6) {
                    Text(formatDuration(template.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !template.tags.isEmpty {
                        // 分隔点
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                        
                        // 第一个标签
                        Text(template.tags[0])
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
                if template.tags.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(template.tags.dropFirst()), id: \.self) { tag in
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
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
