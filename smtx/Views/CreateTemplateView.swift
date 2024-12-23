import SwiftUI
import CoreData

struct CreateTemplateView: View {
    let language: String
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("模板标题", text: $title)
            }
            .navigationTitle("新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createTemplate()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createTemplate() {
        // 先获取或创建对应的语言分区
        let fetchRequest: NSFetchRequest<LanguageSection> = LanguageSection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", language)
        
        do {
            let section: LanguageSection
            if let existingSection = try viewContext.fetch(fetchRequest).first {
                section = existingSection
            } else {
                section = LanguageSection(context: viewContext)
                section.id = UUID()
                section.name = language
                section.createdAt = Date()
            }
            
            // 创建新模板
            let template = Template(context: viewContext)
            template.id = UUID()
            template.title = title
            template.createdAt = Date()
            template.languageSection = section
            
            try viewContext.save()
            dismiss()
        } catch {
            print("Error creating template: \(error)")
        }
    }
} 