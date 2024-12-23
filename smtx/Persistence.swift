//
//  Persistence.swift
//  smtx
//
//  Created by Enkidu ㅤ on 2024/12/23.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    // 预制语言分区
    static let defaultLanguages = ["英语", "日语", "韩语"]

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 为预览创建预制语言分区
        for language in defaultLanguages {
            let section = LanguageSection(context: viewContext)
            section.id = UUID()
            section.name = language
            section.createdAt = Date()
            
            // 为每个分区创建一个示例模板
            let template = Template(context: viewContext)
            template.id = UUID()
            template.title = "\(language)示例"
            template.createdAt = Date()
            template.languageSection = section
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "smtx")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // 如果是第一次启动，创建预制分区
        createDefaultLanguagesIfNeeded()
    }

    private func createDefaultLanguagesIfNeeded() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<LanguageSection> = LanguageSection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name IN %@", Self.defaultLanguages)
        
        do {
            let existingLanguages = try context.fetch(fetchRequest).compactMap { $0.name }
            let missingLanguages = Set(Self.defaultLanguages).subtracting(existingLanguages)
            
            for language in missingLanguages {
                let section = LanguageSection(context: context)
                section.id = UUID()
                section.name = language
                section.createdAt = Date()
            }
            
            if !missingLanguages.isEmpty {
                try context.save()
            }
        } catch {
            print("Error checking for default languages: \(error)")
        }
    }
}
