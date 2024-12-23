import SwiftUI

struct LanguageSectionView: View {
    let language: String
    @EnvironmentObject private var router: NavigationRouter
    @State private var templates: [TemplateFile] = []
    
    var body: some View {
        List {
            ForEach(templates, id: \.metadata.id) { template in
                NavigationLink(value: Route.templateDetail(template)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.template.title)
                            .font(.headline)
                        
                        HStack {
                            Text("时长：\(template.template.totalDuration, specifier: "%.1f")秒")
                            Spacer()
                            Text(template.metadata.createdAt, style: .date)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteTemplates)
        }
        .navigationTitle(language)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { router.navigate(to: .createTemplate(language)) }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadTemplates()
        }
    }
    
    private func loadTemplates() {
        do {
            let allTemplates = try TemplateStorage.shared.listTemplates()
            templates = allTemplates
                .filter { $0.template.language == language }
                .sorted { $0.metadata.createdAt > $1.metadata.createdAt }
        } catch {
            print("Error loading templates: \(error)")
        }
    }
    
    private func deleteTemplates(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let template = templates[index]
                do {
                    try TemplateStorage.shared.deleteTemplate(templateId: template.metadata.id)
                } catch {
                    print("Error deleting template: \(error)")
                }
            }
            loadTemplates()
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSectionView(language: "日语")
            .environmentObject(NavigationRouter())
    }
} 