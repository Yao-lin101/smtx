import SwiftUI

struct MainTabView: View {
    @StateObject private var router = NavigationRouter()
    @State private var selectedTab = 1 // 默认选中本地模板页
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 云模板页（预留）
            PlaceholderView(title: "云模板", message: "即将推出")
                .tabItem {
                    Label("云模板", systemImage: "cloud")
                }
                .tag(0)
            
            // 本地模板页
            NavigationStack(path: $router.path) {
                LocalTemplatesView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .languageSection(let language):
                            LanguageSectionView(language: language)
                        case .templateDetail(let template):
                            TemplateDetailView(template: template)
                        case .createTemplate(let language):
                            CreateTemplateView(language: language)
                        case .recording(let template):
                            RecordingView(template: template)
                        case .recordDetail(let record):
                            RecordDetailView(record: record)
                        }
                    }
            }
            .tabItem {
                Label("本地", systemImage: "folder")
            }
            .tag(1)
            
            // 个人页面（预留）
            PlaceholderView(title: "个人中心", message: "即将推出")
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(2)
        }
        .environmentObject(router)
    }
}

// 预留功能的占位视图
struct PlaceholderView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle)
                .bold()
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}

// 本地模板主页面
struct LocalTemplatesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var router: NavigationRouter
    @State private var showingLanguageInput = false
    @State private var newLanguage = ""
    @State private var showingDeleteAlert = false
    @State private var languageToDelete: String?
    
    // 获取所有语言分区
    @FetchRequest(
        entity: LanguageSection.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \LanguageSection.name, ascending: true)],
        animation: .default)
    private var sections: FetchedResults<LanguageSection>
    
    var body: some View {
        List {
            ForEach(sections) { section in
                NavigationLink(value: Route.languageSection(section.name ?? "")) {
                    HStack {
                        Text(section.name ?? "")
                            .font(.title3)
                        Spacer()
                        Text("\((section.templates?.count ?? 0))")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        languageToDelete = section.name
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("本地模板")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingLanguageInput = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("添加语言分区", isPresented: $showingLanguageInput) {
            TextField("语言名称", text: $newLanguage)
            Button("取消", role: .cancel) {
                newLanguage = ""
            }
            Button("添加") {
                if !newLanguage.isEmpty {
                    addLanguageSection(newLanguage)
                    newLanguage = ""
                }
            }
        }
        .alert("删除语言分区", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let language = languageToDelete {
                    deleteLanguageSection(language)
                }
            }
        } message: {
            if let language = languageToDelete {
                Text("确定要删除「\(language)」分区吗？该分区下的所有模板都将被删除。")
            }
        }
    }
    
    private func addLanguageSection(_ name: String) {
        let section = LanguageSection(context: viewContext)
        section.id = UUID()
        section.name = name
        section.createdAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error adding language section: \(error)")
        }
    }
    
    private func deleteLanguageSection(_ name: String) {
        withAnimation {
            if let section = sections.first(where: { $0.name == name }) {
                viewContext.delete(section)
                try? viewContext.save()
            }
        }
    }
}

// 预览
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 