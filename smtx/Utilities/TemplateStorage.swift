import CoreData
import UIKit

// MARK: - Notification Names

extension Notification.Name {
    static let templateDidUpdate = Notification.Name("templateDidUpdate")
    static let recordingFinished = Notification.Name("recordingFinished")
}

// MARK: - Storage Service

class TemplateStorage {
    static let shared = TemplateStorage()
    
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let languagesKey = "LanguageSections"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading Core Data: \(error)")
            }
        }
        context = container.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Template Operations
    
    func createTemplate(title: String, language: String, coverImage: UIImage) throws -> String {
        let template = Template(context: context)
        let templateId = UUID().uuidString
        
        // Set metadata
        template.id = templateId
        template.creatorType = CreatorType.local.rawValue
        template.creatorId = nil
        template.createdAt = Date()
        template.updatedAt = Date()
        template.status = TemplateStatus.local.rawValue
        template.version = "1.0"
        
        // Set template data
        template.title = title
        template.language = language
        template.coverImage = coverImage.jpegData(compressionQuality: 0.8)
        template.totalDuration = 0
        template.tags = []
        
        try context.save()
        return templateId
    }
    
    func loadTemplate(templateId: String) throws -> Template {
        let request = Template.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", templateId)
        
        guard let template = try context.fetch(request).first,
              template.id != nil
        else {
            throw StorageError.templateNotFound
        }
        
        return template
    }
    
    func listTemplates() throws -> [Template] {
        let request = Template.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return try context.fetch(request)
    }
    
    func listTemplatesByLanguage() throws -> [String: [Template]] {
        let templates = try listTemplates()
        return Dictionary(grouping: templates) { $0.language ?? "" }
    }
    
    func saveTimelineItem(templateId: String, timestamp: Double, script: String, image: UIImage) throws -> String {
        let template = try loadTemplate(templateId: templateId)
        let item = TimelineItem(context: context)
        
        let itemId = UUID().uuidString
        item.id = itemId
        item.timestamp = timestamp
        item.script = script
        item.image = image.jpegData(compressionQuality: 0.8)
        item.template = template
        
        template.updatedAt = Date()
        try context.save()
        
        return itemId
    }
    
    func saveRecord(templateId: String, duration: Double, audioData: Data) throws -> String {
        let template = try loadTemplate(templateId: templateId)
        let record = Record(context: context)
        
        let recordId = UUID().uuidString
        record.id = recordId
        record.createdAt = Date()
        record.duration = duration
        record.audioData = audioData
        record.template = template
        
        try context.save()
        return recordId
    }
    
    func deleteTemplate(templateId: String) throws {
        let template = try loadTemplate(templateId: templateId)
        print("📝 Deleting template: \(templateId)")
        
        // 1. 删除所有时间轴项目
        if let timelineItems = template.timelineItems {
            for case let item as TimelineItem in timelineItems {
                context.delete(item)
                print("✅ Deleted timeline item: \(item.id ?? "")")
            }
        }
        
        // 2. 删除所有录音记录
        if let records = template.records {
            for case let record as Record in records {
                context.delete(record)
                print("✅ Deleted record: \(record.id ?? "")")
            }
        }
        
        // 3. 删除模板本身（会自动删除关联的封面图片数据、标签等）
        context.delete(template)
        
        // 4. 保存更改
        try context.save()
        print("✅ Template deleted successfully")
    }
    
    func saveTemplate(_ template: Template) throws {
        template.updatedAt = Date()
        try context.save()
    }
    
    // MARK: - Language Section Management
    
    func getLanguageSections() -> [String] {
        return userDefaults.stringArray(forKey: languagesKey) ?? []
    }
    
    func addLanguageSection(_ name: String) {
        var sections = getLanguageSections()
        if !sections.contains(name) {
            sections.append(name)
            userDefaults.set(sections, forKey: languagesKey)
        }
    }
    
    func deleteLanguageSection(_ name: String) {
        // 1. 先获取该语言下的所有模板
        let request = Template.fetchRequest()
        request.predicate = NSPredicate(format: "language == %@", name)
        
        do {
            let templates = try context.fetch(request)
            print("📝 Deleting language section: \(name) with \(templates.count) templates")
            
            // 2. 删除每个模板及其关联数据
            for template in templates {
                // 删除所有时间轴项目
                if let timelineItems = template.timelineItems {
                    for case let item as TimelineItem in timelineItems {
                        context.delete(item)
                    }
                }
                
                // 删除所有录音记录
                if let records = template.records {
                    for case let record as Record in records {
                        context.delete(record)
                    }
                }
                
                // 删除模板本身
                context.delete(template)
                print("✅ Deleted template: \(template.id ?? "")")
            }
            
            // 3. 从 UserDefaults 中移除语言分区
            var sections = getLanguageSections()
            sections.removeAll { $0 == name }
            userDefaults.set(sections, forKey: languagesKey)
            
            // 4. 保存更改
            try context.save()
            print("✅ Language section deleted successfully")
        } catch {
            print("❌ Failed to delete language section: \(error)")
        }
    }
    
    func deleteRecord(_ record: Record) throws {
        context.delete(record)
        try context.save()
    }
    
    func updateTemplate(templateId: String, title: String, coverImage: UIImage?, tags: [String], timelineItems: [TimelineItemData], totalDuration: Double) throws {
        let template = try loadTemplate(templateId: templateId)
        
        print("📝 Updating template: \(templateId)")
        print("- Title: \(title)")
        print("- Duration: \(totalDuration) seconds")
        print("- Tags: \(tags)")
        print("- Timeline items: \(timelineItems.count)")
        
        // 更新基本信息
        template.title = title
        template.updatedAt = Date()
        template.tags = tags
        template.totalDuration = totalDuration // 添加总时长更新
        
        // 更新封面图片
        if let coverImage = coverImage {
            template.coverImage = coverImage.jpegData(compressionQuality: 0.8)
        }
        
        // 更新时间轴项目
        // 先删除现有的时间轴项目
        if let existingItems = template.timelineItems {
            for case let item as TimelineItem in existingItems {
                context.delete(item)
            }
        }
        
        // 添加新的时间轴项目
        for itemData in timelineItems {
            let item = TimelineItem(context: context)
            item.id = itemData.id.uuidString
            item.timestamp = itemData.timestamp
            item.script = itemData.script
            item.image = itemData.imageData
            item.template = template
        }
        
        try context.save()
        print("✅ Template updated successfully")
    }
    
    func getTemplateTags(_ template: Template) -> [String] {
        return template.tags ?? []
    }
}

// MARK: - Errors

enum StorageError: Error {
    case directoryCreationFailed
    case templateNotFound
    case imageProcessingFailed
    case invalidData
    case fileNotFound
}

// MARK: - Helper Types

enum CreatorType: String {
    case local
    case user
}

enum TemplateStatus: String {
    case local
    case synced
    case modified
} 