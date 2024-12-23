import Foundation
import UIKit

// MARK: - Models

struct TemplateMetadata: Codable, Hashable {
    let id: String
    let creator: Creator
    var createdAt: Date
    var updatedAt: Date
    var status: TemplateStatus
    
    struct Creator: Codable, Hashable {
        let type: CreatorType
        let id: String?
    }
}

struct TemplateData: Codable, Hashable {
    var title: String
    let language: String
    var coverImage: String
    var totalDuration: Double
    var timelineItems: [TimelineItem]
    
    struct TimelineItem: Codable, Identifiable, Hashable {
        let id: String
        let timestamp: Double
        let script: String
        let image: String
    }
}

struct RecordData: Codable, Identifiable, Hashable {
    let id: String
    let createdAt: Date
    let duration: Double
    let audioFile: String
}

struct TemplateFile: Codable, Hashable {
    var version: String
    var metadata: TemplateMetadata
    var template: TemplateData
    var records: [RecordData]
    
    static func == (lhs: TemplateFile, rhs: TemplateFile) -> Bool {
        return lhs.metadata.id == rhs.metadata.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(metadata.id)
    }
}

enum CreatorType: String, Codable, Hashable {
    case local
    case user
}

enum TemplateStatus: String, Codable, Hashable {
    case local
    case synced
    case modified
}

// MARK: - Storage Service

class TemplateStorage {
    static let shared = TemplateStorage()
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let languagesKey = "LanguageSections"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        // 设置日期编码格式为ISO8601
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // 创建模板根目录
        createTemplatesDirectoryIfNeeded()
    }
    
    // MARK: - Directory Management
    
    private var templatesDirectoryURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Templates")
    }
    
    private func createTemplatesDirectoryIfNeeded() {
        guard let directoryURL = templatesDirectoryURL else { return }
        
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                print("Error creating templates directory: \(error)")
            }
        }
    }
    
    func getTemplateDirectoryURL(templateId: String, userId: String? = nil) -> URL? {
        guard let baseURL = templatesDirectoryURL else { return nil }
        let prefix = userId != nil ? userId! : "local"
        return baseURL.appendingPathComponent("\(prefix)_\(templateId)")
    }
    
    // MARK: - Template Listing
    
    func listTemplates(userId: String? = nil) throws -> [TemplateFile] {
        guard let baseURL = templatesDirectoryURL else {
            throw StorageError.directoryCreationFailed
        }
        
        let prefix = userId != nil ? userId! : "local"
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil
            )
            
            return try contents
                .filter { $0.lastPathComponent.hasPrefix(prefix) }
                .compactMap { directoryURL -> TemplateFile? in
                    let jsonURL = directoryURL.appendingPathComponent("template.json")
                    guard fileManager.fileExists(atPath: jsonURL.path) else { return nil }
                    let jsonData = try Data(contentsOf: jsonURL)
                    return try decoder.decode(TemplateFile.self, from: jsonData)
                }
                .sorted { $0.metadata.createdAt > $1.metadata.createdAt }
        } catch {
            throw StorageError.invalidData
        }
    }
    
    func listTemplatesByLanguage() throws -> [String: [TemplateFile]] {
        let templates = try listTemplates()
        return Dictionary(grouping: templates) { $0.template.language }
    }
    
    // MARK: - Template Operations
    
    func createTemplate(title: String, language: String, coverImage: UIImage) throws -> String {
        let templateId = UUID().uuidString
        
        // 创建模板目录结构
        guard let templateDir = getTemplateDirectoryURL(templateId: templateId) else {
            throw StorageError.directoryCreationFailed
        }
        
        try fileManager.createDirectory(at: templateDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: templateDir.appendingPathComponent("images"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: templateDir.appendingPathComponent("records"), withIntermediateDirectories: true)
        
        // 保存封面图片
        guard let coverImageData = coverImage.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageProcessingFailed
        }
        try coverImageData.write(to: templateDir.appendingPathComponent("cover.jpg"))
        
        // 创建模板数据
        let template = TemplateFile(
            version: "1.0",
            metadata: TemplateMetadata(
                id: templateId,
                creator: TemplateMetadata.Creator(type: .local, id: nil),
                createdAt: Date(),
                updatedAt: Date(),
                status: .local
            ),
            template: TemplateData(
                title: title,
                language: language,
                coverImage: "cover.jpg",
                totalDuration: 0,
                timelineItems: []
            ),
            records: []
        )
        
        // 保存模板数据
        let jsonData = try encoder.encode(template)
        try jsonData.write(to: templateDir.appendingPathComponent("template.json"))
        
        return templateId
    }
    
    func loadTemplate(templateId: String, userId: String? = nil) throws -> TemplateFile {
        guard let templateDir = getTemplateDirectoryURL(templateId: templateId, userId: userId) else {
            throw StorageError.templateNotFound
        }
        
        let jsonURL = templateDir.appendingPathComponent("template.json")
        let jsonData = try Data(contentsOf: jsonURL)
        return try decoder.decode(TemplateFile.self, from: jsonData)
    }
    
    func saveTimelineItem(templateId: String, timestamp: Double, script: String, image: UIImage) throws -> String {
        guard let templateDir = getTemplateDirectoryURL(templateId: templateId) else {
            throw StorageError.templateNotFound
        }
        
        // 生成唯一标识符
        let itemId = UUID().uuidString
        let timestamp = Int(timestamp * 1000) // 转换为毫���
        let filename = "\(timestamp)_\(itemId).jpg"
        
        // 保存图片
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageProcessingFailed
        }
        let imageURL = templateDir.appendingPathComponent("images").appendingPathComponent(filename)
        try imageData.write(to: imageURL)
        
        // 更新模板数据
        var template = try loadTemplate(templateId: templateId)
        template.template.timelineItems.append(
            TemplateData.TimelineItem(
                id: itemId,
                timestamp: Double(timestamp) / 1000,
                script: script,
                image: "images/\(filename)"
            )
        )
        template.metadata.updatedAt = Date()
        
        // 保存更新后的模板数据
        let jsonData = try encoder.encode(template)
        try jsonData.write(to: templateDir.appendingPathComponent("template.json"))
        
        return itemId
    }
    
    func saveRecord(templateId: String, duration: Double, audioData: Data) throws -> String {
        guard let templateDir = getTemplateDirectoryURL(templateId: templateId) else {
            throw StorageError.templateNotFound
        }
        
        // 生成唯一标识符
        let recordId = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "\(timestamp)_\(recordId).m4a"
        
        // 保存音频文件
        let audioURL = templateDir.appendingPathComponent("records").appendingPathComponent(filename)
        try audioData.write(to: audioURL)
        
        // 更新模板数据
        var template = try loadTemplate(templateId: templateId)
        template.records.append(
            RecordData(
                id: recordId,
                createdAt: Date(),
                duration: duration,
                audioFile: "records/\(filename)"
            )
        )
        template.metadata.updatedAt = Date()
        
        // 保存更新后的模板数据
        let jsonData = try encoder.encode(template)
        try jsonData.write(to: templateDir.appendingPathComponent("template.json"))
        
        return recordId
    }
    
    func deleteTemplate(templateId: String, userId: String? = nil) throws {
        guard let templateDir = getTemplateDirectoryURL(templateId: templateId, userId: userId) else {
            throw StorageError.templateNotFound
        }
        
        try fileManager.removeItem(at: templateDir)
    }
    
    func saveTemplate(_ template: TemplateFile) throws {
        guard let templateDir = getTemplateDirectoryURL(templateId: template.metadata.id) else {
            throw StorageError.directoryCreationFailed
        }
        
        // 保存模板数据
        let jsonData = try encoder.encode(template)
        try jsonData.write(to: templateDir.appendingPathComponent("template.json"))
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
        var sections = getLanguageSections()
        sections.removeAll { $0 == name }
        userDefaults.set(sections, forKey: languagesKey)
        
        // 删除该语言下的所有模板
        do {
            let templates = try listTemplates()
            for template in templates where template.template.language == name {
                try deleteTemplate(templateId: template.metadata.id)
            }
        } catch {
            print("Error deleting templates for language section: \(error)")
        }
    }
}

// MARK: - Errors

enum StorageError: Error {
    case directoryCreationFailed
    case templateNotFound
    case imageProcessingFailed
    case invalidData
} 