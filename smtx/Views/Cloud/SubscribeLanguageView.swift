import SwiftUI

struct SubscribeLanguageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CloudTemplateViewModel
    @Binding var searchText: String
    @State private var sectionToUnsubscribe: LanguageSection?
    @State private var showingUnsubscribeAlert = false
    
    private var filteredSubscribedSections: [LanguageSection] {
        let sections = viewModel.languageSections.filter { $0.isSubscribed }
        guard !searchText.isEmpty else { return sections }
        return sections.filter { section in
            section.name.localizedCaseInsensitiveContains(searchText) ||
            (!section.chineseName.isEmpty && section.chineseName.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private var filteredUnsubscribedSections: [LanguageSection] {
        let sections = viewModel.languageSections.filter { !$0.isSubscribed }
        guard !searchText.isEmpty else { return sections }
        return sections.filter { section in
            section.name.localizedCaseInsensitiveContains(searchText) ||
            (!section.chineseName.isEmpty && section.chineseName.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private func sectionRow(_ section: LanguageSection) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(section.name)
                    .font(.headline)
                Text("\(section.templatesCount) 个模板")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                if section.isSubscribed {
                    sectionToUnsubscribe = section
                    showingUnsubscribeAlert = true
                } else {
                    Task {
                        await viewModel.toggleSubscription(for: section)
                    }
                }
            } label: {
                Image(systemName: section.isSubscribed ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(section.isSubscribed ? .green : .blue)
                    .font(.title2)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !filteredSubscribedSections.isEmpty {
                    Section("已订阅") {
                        ForEach(filteredSubscribedSections) { section in
                            sectionRow(section)
                        }
                    }
                }
                
                if !filteredUnsubscribedSections.isEmpty {
                    Section("未订阅") {
                        ForEach(filteredUnsubscribedSections) { section in
                            sectionRow(section)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索语言分区")
            .navigationTitle("订阅语言分区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadLanguageSections()
            }
            .alert("确认取消订阅", isPresented: $showingUnsubscribeAlert) {
                Button("取消", role: .cancel) { }
                Button("确定", role: .destructive) {
                    if let section = sectionToUnsubscribe {
                        Task {
                            await viewModel.toggleSubscription(for: section)
                        }
                    }
                }
            } message: {
                if let section = sectionToUnsubscribe {
                    Text("确定要取消订阅「\(section.name)」吗？")
                }
            }
        }
    }
}

#Preview {
    SubscribeLanguageView(
        viewModel: CloudTemplateViewModel(),
        searchText: .constant("")
    )
} 