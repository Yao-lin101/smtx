import SwiftUI
import CoreData

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
                        case .templateDetail(let templateId):
                            TemplateDetailView(templateId: templateId)
                        case .createTemplate(let language, let templateId):
                            CreateTemplateView(language: language, existingTemplateId: templateId)
                        case .recording(let templateId):
                            if let template = try? TemplateStorage.shared.loadTemplate(templateId: templateId) {
                                RecordingView(template: template)
                            }
                        case .recordDetail(let templateId, let recordId):
                            if let template = try? TemplateStorage.shared.loadTemplate(templateId: templateId),
                               let records = template.records?.allObjects as? [Record],
                               let record = records.first(where: { $0.id == recordId }) {
                                RecordDetailView(record: record, template: template)
                            }
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
    @EnvironmentObject private var router: NavigationRouter
    @State private var showingLanguageInput = false
    @State private var newLanguage = ""
    @State private var showingDeleteAlert = false
    @State private var languageToDelete: String?
    @State private var templatesByLanguage: [String: [Template]] = [:]
    @State private var languageSections: [String] = []
    
    var body: some View {
        List {
            ForEach(languageSections, id: \.self) { language in
                NavigationLink(value: Route.languageSection(language)) {
                    HStack {
                        Text(language)
                            .font(.title3)
                        Spacer()
                        Text("\(templatesByLanguage[language]?.count ?? 0)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        languageToDelete = language
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .tint(.red)
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
        .confirmationDialog("所有模板和录音记录都将删除。", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("删除分区", role: .destructive) {
                if let language = languageToDelete {
                    deleteLanguageSection(language)
                }
                languageToDelete = nil
            }
            Button("取消", role: .cancel) {
                languageToDelete = nil
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        // 加载语言分区
        languageSections = TemplateStorage.shared.getLanguageSections()
        
        // 加载模板
        do {
            templatesByLanguage = try TemplateStorage.shared.listTemplatesByLanguage()
        } catch {
            print("Error loading templates: \(error)")
        }
    }
    
    private func addLanguageSection(_ name: String) {
        TemplateStorage.shared.addLanguageSection(name)
        loadData()
    }
    
    private func deleteLanguageSection(_ language: String) {
        TemplateStorage.shared.deleteLanguageSection(language)
        loadData()
    }
}

#Preview {
    MainTabView()
} 
