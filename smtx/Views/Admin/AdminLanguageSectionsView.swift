import SwiftUI

struct AdminLanguageSectionsView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var showingCreateSheet = false
    @State private var showingEditSheet = false
    @State private var newSectionName = ""
    @State private var newSectionChineseName = ""
    @State private var searchText = ""
    @State private var sectionToEdit: LanguageSection?
    @State private var showingDeleteAlert = false
    @State private var sectionToDelete: LanguageSection?
    
    var filteredSections: [LanguageSection] {
        if searchText.isEmpty {
            return viewModel.languageSections
        }
        return viewModel.languageSections.filter { section in
            section.name.localizedCaseInsensitiveContains(searchText) ||
            section.chineseName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredSections) { section in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
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
                }
                .swipeActions(edge: .trailing) {
                    Button{
                        sectionToDelete = section
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .tint(.red)
                    
                    Button {
                        sectionToEdit = section
                        newSectionName = section.name
                        newSectionChineseName = section.chineseName
                        showingEditSheet = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索语言分区")
        .navigationTitle("语言分区管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newSectionName = ""
                    newSectionChineseName = ""
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("分区名称", text: $newSectionName)
                        TextField("中文备注（可选）", text: $newSectionChineseName)
                    }
                }
                .navigationTitle("创建语言分区")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            showingCreateSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("创建") {
                            if !newSectionName.isEmpty {
                                Task {
                                    await viewModel.createLanguageSection(
                                        name: newSectionName,
                                        chineseName: newSectionChineseName
                                    )
                                    
                                    if !viewModel.showError {
                                        await viewModel.loadLanguageSections()
                                        newSectionName = ""
                                        newSectionChineseName = ""
                                        showingCreateSheet = false
                                        ToastManager.shared.show("创建成功")
                                    } else {
                                        ToastManager.shared.show(viewModel.errorMessage ?? "创建失败", type: .error)
                                    }
                                }
                            }
                        }
                        .disabled(newSectionName.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("分区名称", text: $newSectionName)
                        TextField("中文备注（可选）", text: $newSectionChineseName)
                    }
                }
                .navigationTitle("编辑语言分区")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            showingEditSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            if !newSectionName.isEmpty, let section = sectionToEdit {
                                Task {
                                    await viewModel.updateLanguageSection(
                                        uid: section.uid,
                                        name: newSectionName,
                                        chineseName: newSectionChineseName
                                    )
                                    
                                    if !viewModel.showError {
                                        await viewModel.loadLanguageSections()
                                        showingEditSheet = false
                                        ToastManager.shared.show("更新成功")
                                    } else {
                                        ToastManager.shared.show(viewModel.errorMessage ?? "更新失败", type: .error)
                                    }
                                }
                            }
                        }
                        .disabled(newSectionName.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let section = sectionToDelete {
                    Task {
                        await viewModel.deleteLanguageSection(uid: section.uid)
                        if !viewModel.showError {
                            await viewModel.loadLanguageSections()
                            ToastManager.shared.show("删除成功")
                        } else {
                            ToastManager.shared.show(viewModel.errorMessage ?? "删除失败", type: .error)
                        }
                    }
                }
            }
        } message: {
            if let section = sectionToDelete {
                Text("确定要删除语言分区「\(section.name)」吗？该操作不可恢复。")
            }
        }
        .toastManager()
        .onAppear {
            Task {
                await viewModel.loadLanguageSections()
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminLanguageSectionsView()
    }
} 