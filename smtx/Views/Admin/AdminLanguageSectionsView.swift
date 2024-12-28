import SwiftUI

struct AdminLanguageSectionsView: View {
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var showingCreateSheet = false
    @State private var newSectionName = ""
    @State private var showingDeleteAlert = false
    @State private var sectionToDelete: LanguageSection?
    
    var body: some View {
        List {
            ForEach(viewModel.languageSections) { section in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.name)
                            .font(.headline)
                        Text("\(section.templatesCount) 个模板")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        sectionToDelete = section
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("语言分区管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
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
                                    await viewModel.createLanguageSection(name: newSectionName)
                                    newSectionName = ""
                                    showingCreateSheet = false
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
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let section = sectionToDelete {
                    Task {
                        await viewModel.deleteLanguageSection(uid: section.uid)
                    }
                    showingDeleteAlert = false
                }
            }
        } message: {
            if let section = sectionToDelete {
                Text("确定要删除语言分区\"\(section.name)\"吗？该操作不可恢复。")
            }
        }
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