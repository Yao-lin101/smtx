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
    
    func createTemplate(title: String, sectionId: String, coverImage: UIImage) throws -> String {
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
        
        // Set cloud sync status
        template.cloudUid = nil
        template.cloudVersion = nil
        template.cloudStatus = CloudStatus.local.rawValue
        template.lastSyncedAt = nil
        
        // Set template data
        template.title = title
        template.coverImage = coverImage.jpegData(compressionQuality: 0.8)
        template.totalDuration = 0
        template.tags = []
        
        // Associate with section
        let section = try loadLanguageSection(id: sectionId)
        template.section = section
        
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
        let sections = try listLanguageSections()
        var templatesByLanguage: [String: [Template]] = [:]
        
        for section in sections {
            if let templates = section.templates?.allObjects as? [Template] {
                templatesByLanguage[section.name ?? ""] = templates.sorted { 
                    ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast)
                }
            }
        }
        
        return templatesByLanguage
    }
    
    func saveTimelineItem(templateId: String, timestamp: Double, script: String, image: UIImage) throws -> String {
        let template = try loadTemplate(templateId: templateId)
        let item = TimelineItem(context: context)
        
        let itemId = UUID().uuidString
        item.id = itemId
        item.timestamp = timestamp
        item.script = script
        item.image = image.jpegData(compressionQuality: 0.8)
        item.createdAt = Date()
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
    
    func updateTemplate(
        templateId: String,
        title: String,
        coverImage: UIImage?,
        tags: [String],
        timelineItems: [TimelineItemData],
        totalDuration: Double,
        onlyScriptChanges: Bool = false
    ) throws {
        let template = try loadTemplate(templateId: templateId)
        
        print("📝 Updating template: \(templateId)")
        print("- Title: \(title)")
        print("- Duration: \(totalDuration) seconds")
        print("- Tags: \(tags)")
        print("- Timeline items: \(timelineItems.count)")
        print("- Only script changes: \(onlyScriptChanges)")
        
        // 更新版本号
        if let currentVersion = template.version {
            let versionComponents = currentVersion.split(separator: ".")
            if versionComponents.count == 2,
               let major = Int(versionComponents[0]),
               let minor = Int(versionComponents[1]) {
                // 增加次版本号，如果超过99则增加主版本号
                if minor >= 99 {
                    template.version = "\(major + 1).0"
                } else {
                    template.version = "\(major).\(minor + 1)"
                }
            } else {
                // 如果版本号格式不正确，重置为1.0
                template.version = "1.0"
            }
        } else {
            // 如果没有版本号，设置为1.0
            template.version = "1.0"
        }
        
        // 更新基本信息
        template.title = title
        template.updatedAt = Date()
        template.tags = tags as NSArray
        template.totalDuration = totalDuration
        
        // 更新封面图片（如果提供）
        if let coverImage = coverImage {
            template.coverImage = coverImage.jpegData(compressionQuality: 0.8)
        }
        
        // 更新时间轴项目
        let existingItems = template.timelineItems?.allObjects as? [TimelineItem] ?? []
        let existingItemsDict = Dictionary(grouping: existingItems) { $0.timestamp }
        
        // 添加或更新时间轴项目
        for itemData in timelineItems {
            let existingItem = existingItemsDict[itemData.timestamp]?.first
            let item = existingItem ?? TimelineItem(context: context)
            
            // 更新基本属性
            item.id = itemData.id.uuidString
            item.timestamp = itemData.timestamp
            item.script = itemData.script
            item.createdAt = itemData.createdAt
            
            // 更新图片相关属性
            if !onlyScriptChanges {
                let currentImageHash = item.image?.sha256()
                let newImageHash = itemData.imageData?.sha256()
                
                if currentImageHash != newImageHash {
                    item.image = itemData.imageData
                    item.imageUpdatedAt = Date()
                }
            }
            
            // 更新脚本时间戳
            if item.script != itemData.script {
                item.updatedAt = Date()
            }
            
            item.template = template
        }
        
        // 删除不再使用的项目
        let timestampsToKeep = Set(timelineItems.map { $0.timestamp })
        for item in existingItems {
            if !timestampsToKeep.contains(item.timestamp) {
                context.delete(item)
            }
        }
        
        // 如果模板已发布到云端，标记为已修改
        if template.cloudStatus == CloudStatus.published.rawValue {
            template.cloudStatus = CloudStatus.modified.rawValue
        }
        
        try context.save()
        print("✅ Template updated successfully")
        print("- New version: \(template.version ?? "1.0")")
        print("- Cloud status: \(template.cloudStatus ?? CloudStatus.local.rawValue)")
        
        NotificationCenter.default.post(name: .templateDidUpdate, object: nil)
    }
    
    func getTemplateTags(_ template: Template) -> [String] {
        return (template.tags as? [String]) ?? []
    }
    
    // 添加云端同步相关方法
    func updateCloudStatus(templateId: String, cloudUid: String, cloudVersion: String) throws {
        let template = try loadTemplate(templateId: templateId)
        
        template.cloudUid = cloudUid
        template.cloudVersion = cloudVersion
        template.cloudStatus = CloudStatus.published.rawValue
        template.lastSyncedAt = Date()
        
        try context.save()
        print("✅ Template cloud status updated")
        print("- Cloud UID: \(cloudUid)")
        print("- Cloud version: \(cloudVersion)")
    }
    
    // MARK: - Language Section Operations
    
    func createLanguageSection(name: String, cloudSectionId: String? = nil) throws -> LocalLanguageSection {
        let section = LocalLanguageSection(context: context)
        section.id = UUID().uuidString
        section.name = name
        section.cloudSectionId = cloudSectionId
        section.createdAt = Date()
        section.updatedAt = Date()
        
        try context.save()
        return section
    }
    
    func loadLanguageSection(id: String) throws -> LocalLanguageSection {
        let request = LocalLanguageSection.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        guard let section = try context.fetch(request).first else {
            throw StorageError.sectionNotFound
        }
        
        return section
    }
    
    func listLanguageSections() throws -> [LocalLanguageSection] {
        let request = LocalLanguageSection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try context.fetch(request)
    }
    
    func updateLanguageSection(id: String, name: String, cloudSectionId: String?) throws {
        let section = try loadLanguageSection(id: id)
        section.name = name
        section.cloudSectionId = cloudSectionId
        section.updatedAt = Date()
        
        try context.save()
    }
    
    func deleteLanguageSection(_ section: LocalLanguageSection) throws {
        // 由于设置了级联删除，删除分区时会自动删除关联的模板
        context.delete(section)
        try context.save()
    }
    
    func assignTemplateToSection(templateId: String, sectionId: String) throws {
        let template = try loadTemplate(templateId: templateId)
        let section = try loadLanguageSection(id: sectionId)
        
        template.section = section
        try context.save()
    }
    
    // MARK: - Error Types
    
    enum StorageError: Error {
        case templateNotFound
        case sectionNotFound
        
        var localizedDescription: String {
            switch self {
            case .templateNotFound:
                return "Template not found"
            case .sectionNotFound:
                return "Language section not found"
            }
        }
    }
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

enum CloudStatus: String {
    case local      // 未发布到云端
    case published  // 已发布到云端
    case modified   // 已发布但本地有修改
} 