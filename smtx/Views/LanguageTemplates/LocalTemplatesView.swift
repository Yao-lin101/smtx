import SwiftUI
import CoreData

struct LocalTemplatesView: View {
    @EnvironmentObject private var router: NavigationRouter
    @State private var showingLanguageInput = false
    @State private var newLanguage = ""
    @State private var showingDeleteAlert = false
    @State private var languageToDelete: String?
    @State private var templatesByLanguage: [String: [Template]] = [:]
    @State private var languageSections: [LocalLanguageSection] = []
    
    var body: some View {
        List {
            ForEach(languageSections, id: \.id) { section in
                languageSectionRow(section)
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
                if let language = languageToDelete,
                   let section = languageSections.first(where: { $0.name == language }) {
                    deleteLanguageSection(section)
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
    
    private func languageSectionRow(_ section: LocalLanguageSection) -> some View {
        NavigationLink(value: Route.languageSection(section.name ?? "")) {
            HStack {
                Text(section.name ?? "")
                    .font(.title3)
                Spacer()
                Text("\(section.templates?.count ?? 0)")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                // 检查该语言分区是否有模板
                if let templates = section.templates,
                   templates.count > 0 {
                    // 有模板时显示确认对话框
                    languageToDelete = section.name
                    showingDeleteAlert = true
                } else {
                    // 没有模板时直接删除
                    deleteLanguageSection(section)
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(.red)
        }
    }
    
    private func loadLanguageSections() {
        do {
            languageSections = try TemplateStorage.shared.listLanguageSections()
        } catch {
            print("Error loading language sections: \(error)")
            languageSections = []
        }
    }
    
    private func addLanguageSection(_ name: String) {
        do {
            _ = try TemplateStorage.shared.createLanguageSection(name: name)
            loadLanguageSections()
        } catch {
            print("Error adding language section: \(error)")
        }
    }
    
    private func deleteLanguageSection(_ section: LocalLanguageSection) {
        do {
            try TemplateStorage.shared.deleteLanguageSection(section)
            loadLanguageSections()
            languageToDelete = nil
        } catch {
            print("Error deleting language section: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        LocalTemplatesView()
            .environmentObject(NavigationRouter())
    }
} 