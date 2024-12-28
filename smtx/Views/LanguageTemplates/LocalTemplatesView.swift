import SwiftUI
import CoreData

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
                        // 检查该语言分区是否有模板
                        if let templates = templatesByLanguage[language], !templates.isEmpty {
                            // 有模板时显示确认对话框
                            languageToDelete = language
                            showingDeleteAlert = true
                        } else {
                            // 没有模板时直接删除
                            deleteLanguageSection(language)
                        }
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
            }
            Button("取消", role: .cancel) {
                languageToDelete = nil
            }
        }
        .onAppear {
            loadLanguageSections()
        }
    }
    
    private func loadLanguageSections() {
        // 从 CoreData 加载语言分区和模板
        let storage = TemplateStorage.shared
        languageSections = storage.getLanguageSections()
        
        do {
            templatesByLanguage = try storage.listTemplatesByLanguage()
        } catch {
            print("Error loading templates: \(error)")
            templatesByLanguage = [:]
        }
    }
    
    private func addLanguageSection(_ language: String) {
        let storage = TemplateStorage.shared
        storage.addLanguageSection(language)
        loadLanguageSections()
    }
    
    private func deleteLanguageSection(_ language: String) {
        let storage = TemplateStorage.shared
        storage.deleteLanguageSection(language)
        loadLanguageSections()
        languageToDelete = nil
    }
}

#Preview {
    NavigationStack {
        LocalTemplatesView()
            .environmentObject(NavigationRouter())
    }
} 