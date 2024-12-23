import SwiftUI
import CoreData

struct LanguageSectionView: View {
    let language: String
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var router: NavigationRouter
    
    @FetchRequest private var templates: FetchedResults<Template>
    
    init(language: String) {
        self.language = language
        _templates = FetchRequest(
            entity: Template.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Template.createdAt, ascending: false)],
            predicate: NSPredicate(format: "languageSection.name == %@", language)
        )
    }
    
    var body: some View {
        List {
            ForEach(templates) { template in
                NavigationLink(value: Route.templateDetail(template)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.title ?? "未命名模板")
                            .font(.headline)
                        
                        HStack {
                            Text("时长：\(template.totalDuration, specifier: "%.1f")秒")
                            Spacer()
                            Text(template.createdAt ?? Date(), style: .date)
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
    }
    
    private func deleteTemplates(offsets: IndexSet) {
        withAnimation {
            offsets.map { templates[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSectionView(language: "日语")
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(NavigationRouter())
    }
} 