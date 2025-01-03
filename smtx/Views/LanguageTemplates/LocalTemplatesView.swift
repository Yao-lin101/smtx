import SwiftUI
import CoreData

struct LocalTemplatesView: View {
    @EnvironmentObject private var router: NavigationRouter
    @State private var showingLanguageInput = false
    @State private var showingEditSheet = false
    @State private var newLanguage = ""
    @State private var showingDeleteAlert = false
    @State private var languageToDelete: String?
    @State private var templatesByLanguage: [String: [Template]] = [:]
    @State private var languageSections: [LocalLanguageSection] = []
    @StateObject private var cloudStore = LanguageSectionStore.shared
    @State private var selectedCloudSection: LanguageSection?
    @State private var searchText = ""
    @State private var sectionToEdit: LocalLanguageSection?
    
    private var filteredCloudSections: [LanguageSection] {
        let sections = searchText.isEmpty ? cloudStore.sections : cloudStore.sections.filter { section in
            section.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // 将已绑定的分区排在前面
        return sections.sorted { section1, section2 in
            // 如果正在编辑分区
            if let editingSection = sectionToEdit {
                let section1IsBound = section1.uid.replacingOccurrences(of: "-", with: "") == editingSection.cloudSectionId
                let section2IsBound = section2.uid.replacingOccurrences(of: "-", with: "") == editingSection.cloudSectionId
                
                if section1IsBound != section2IsBound {
                    return section1IsBound // 已绑定的排在前面
                }
            }
            
            // 如果绑定状态相同或没有正在编辑的分区，按名称排序
            return section1.name < section2.name
        }
    }
    
    var body: some View {
        List {
            ForEach(languageSections, id: \.id) { section in
                languageSectionRow(section)
            }
        }
        .navigationTitle("本地模板")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // 重置所有状态
                    newLanguage = ""
                    selectedCloudSection = nil
                    sectionToEdit = nil  // 重置编辑状态
                    showingLanguageInput = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingLanguageInput) {
            addLanguageSectionSheet
        }
        .sheet(isPresented: $showingEditSheet) {
            editLanguageSectionSheet
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
    
    private var addLanguageSectionSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("语言名称", text: $newLanguage)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                
                List {
                    Section("绑定云端分区（可选）") {
                        ForEach(filteredCloudSections) { section in
                            Button {
                                selectedCloudSection = selectedCloudSection == section ? nil : section
                                if selectedCloudSection == section {
                                    newLanguage = section.name
                                }
                            } label: {
                                cloudSectionRow(section)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "搜索云端分区")
            }
            .navigationTitle("添加语言分区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        newLanguage = ""
                        selectedCloudSection = nil
                        showingLanguageInput = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        if !newLanguage.isEmpty {
                            addLanguageSection(newLanguage, cloudSectionId: selectedCloudSection?.uid)
                            newLanguage = ""
                            selectedCloudSection = nil
                            showingLanguageInput = false
                        }
                    }
                    .disabled(newLanguage.isEmpty)
                }
            }
            .task {
                await cloudStore.loadSections()
            }
        }
    }
    
    private var editLanguageSectionSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("语言名称", text: $newLanguage)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                
                List {
                    Section("绑定云端分区（可选）") {
                        ForEach(filteredCloudSections) { section in
                            Button {
                                selectedCloudSection = selectedCloudSection == section ? nil : section
                                if selectedCloudSection == section {
                                    newLanguage = section.name
                                }
                            } label: {
                                cloudSectionRow(section)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "搜索云端分区")
            }
            .navigationTitle("编辑语言分区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        newLanguage = ""
                        selectedCloudSection = nil
                        sectionToEdit = nil
                        showingEditSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if !newLanguage.isEmpty, let section = sectionToEdit {
                            updateLanguageSection(section, newName: newLanguage, cloudSectionId: selectedCloudSection?.uid)
                            newLanguage = ""
                            selectedCloudSection = nil
                            sectionToEdit = nil
                            showingEditSheet = false
                        }
                    }
                    .disabled(newLanguage.isEmpty)
                }
            }
            .task {
                await cloudStore.loadSections()
            }
            .onAppear {
                if let section = sectionToEdit {
                    newLanguage = section.name ?? ""
                    if let cloudSectionId = section.cloudSectionId {
                        selectedCloudSection = cloudStore.sections.first { $0.uid == cloudSectionId }
                    }
                }
            }
        }
    }
    
    private func cloudSectionRow(_ section: LanguageSection) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(section.name)
                    .font(.headline)
                if !section.chineseName.isEmpty {
                    Text(section.chineseName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("\(section.templatesCount) 个模板")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let editingSection = sectionToEdit,
               section.uid.replacingOccurrences(of: "-", with: "") == editingSection.cloudSectionId {
                Text("已绑定")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if selectedCloudSection == section {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
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
            
            Button {
                sectionToEdit = section
                showingEditSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
    
    private func updateLanguageSection(_ section: LocalLanguageSection, newName: String, cloudSectionId: String?) {
        do {
            let formattedCloudId = cloudSectionId?.replacingOccurrences(of: "-", with: "")
            try TemplateStorage.shared.updateLanguageSection(
                id: section.id ?? "", 
                name: newName, 
                cloudSectionId: formattedCloudId
            )
            loadLanguageSections()
        } catch {
            print("Error updating language section: \(error)")
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
    
    private func addLanguageSection(_ name: String, cloudSectionId: String?) {
        do {
            let formattedCloudId = cloudSectionId?.replacingOccurrences(of: "-", with: "")
            _ = try TemplateStorage.shared.createLanguageSection(name: name, cloudSectionId: formattedCloudId)
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