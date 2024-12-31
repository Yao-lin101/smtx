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
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showingSubscribeSheet) {
            SubscribeLanguageView(searchText: $searchText)
        }
        .onAppear {
            viewModel.loadLocalData()
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
                listView
            case .gallery:
                galleryView
            }
        }
    }
    
    private var listView: some View {
        List {
            ForEach(viewModel.filteredTemplates(searchText: searchText)) { template in
                NavigationLink(value: Route.cloudTemplateDetail(template.uid)) {
                    CloudTemplateRow(template: template)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            Task {
                await viewModel.loadInitialData(selectedLanguageUid: selectedLanguageUid)
            }
        }
    }
    
    private var galleryView: some View {
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
        .refreshable {
            Task {
                await viewModel.loadInitialData(selectedLanguageUid: selectedLanguageUid)
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
