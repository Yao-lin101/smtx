import SwiftUI

struct AdminLanguageSectionsView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var showingCreateSheet = false
    @State private var newSectionName = ""
    @State private var newSectionChineseName = ""
    @State private var showingDeleteAlert = false
    @State private var sectionToDelete: LanguageSection?
    @State private var showingSuccessAlert = false
    
    var body: some View {
        List {
            ForEach(viewModel.languageSections) { section in
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
                                    print("📝 开始创建语言分区")
                                    await viewModel.createLanguageSection(
                                        name: newSectionName,
                                        chineseName: newSectionChineseName
                                    )
                                    
                                    print("🔍 检查创建结果: showError = \(viewModel.showError)")
                                    if !viewModel.showError {
                                        print("✅ 创建成功，刷新列表")
                                        await viewModel.loadLanguageSections()
                                        newSectionName = ""
                                        newSectionChineseName = ""
                                        showingCreateSheet = false
                                        showingSuccessAlert = true
                                    } else {
                                        print("❌ 创建失败: \(viewModel.errorMessage ?? "未知错误")")
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
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let section = sectionToDelete {
                    Task {
                        await viewModel.deleteLanguageSection(uid: section.uid)
                        if !viewModel.showError {
                            await viewModel.loadLanguageSections()
                            showingDeleteAlert = false
                        }
                    }
                }
            }
        } message: {
            if let section = sectionToDelete {
                Text("确定要删除语言分区\"\(section.name)\"吗？该操作不可恢复。")
            }
        }
        .alert("成功", isPresented: $showingSuccessAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("语言分区创建成功")
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
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