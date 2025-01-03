import Foundation
import ZIPFoundation

enum TemplatePackageError: Error {
    case fileNotFound
    case compressionFailed
    case invalidData
    case createArchiveFailed
    case addEntryFailed
    case readArchiveFailed
}

class TemplatePackageService {
    
    private static func getVersionedFileName(baseName: String, version: String) -> String {
        // 移除文件扩展名
        let components = baseName.split(separator: ".")
        let nameWithoutExt = components[0]
        let ext = components[1]
        // 添加版本信息并重新组合
        return "\(nameWithoutExt)_v\(version).\(ext)"
    }
    
    /// 创建模板包
    /// - Parameters:
    ///   - coverImage: 原始封面图片数据
    ///   - coverThumbnail: 封面缩略图数据
    ///   - timeline: 时间轴数据
    ///   - timelineImages: 时间轴图片数据字典，key为图片名称
    ///   - version: 版本号
    /// - Returns: 打包后的数据
    static func createPackage(
        coverImage: Data,
        coverThumbnail: Data,
        timeline: Data,
        timelineImages: [String: Data],
        version: String
    ) throws -> Data {
        // 创建临时文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        
        // 创建 ZIP 文件
        let archive: Archive
        do {
            archive = try Archive(url: tempURL, accessMode: .create)
        } catch {
            throw TemplatePackageError.createArchiveFailed
        }
        
        do {
            // 使用版本化的文件名
            let coverOriginalName = getVersionedFileName(baseName: "covers_original.jpg", version: version)
            let coverThumbnailName = getVersionedFileName(baseName: "covers_thumbnails.jpg", version: version)
            let timelineName = getVersionedFileName(baseName: "timelines.json", version: version)
            
            // 添加封面图片
            try archive.addEntry(
                with: coverOriginalName,
                type: .file,
                uncompressedSize: Int64(coverImage.count),
                bufferSize: Int(4096),
                provider: { (position: Int64, size: Int) -> Data in
                    let start = Int(position)
                    let end = min(start + size, coverImage.count)
                    return coverImage.subdata(in: start..<end)
                }
            )
            
            // 添加封面缩略图
            try archive.addEntry(
                with: coverThumbnailName,
                type: .file,
                uncompressedSize: Int64(coverThumbnail.count),
                bufferSize: Int(4096),
                provider: { (position: Int64, size: Int) -> Data in
                    let start = Int(position)
                    let end = min(start + size, coverThumbnail.count)
                    return coverThumbnail.subdata(in: start..<end)
                }
            )
            
            // 添加时间轴数据
            try archive.addEntry(
                with: timelineName,
                type: .file,
                uncompressedSize: Int64(timeline.count),
                bufferSize: Int(4096),
                provider: { (position: Int64, size: Int) -> Data in
                    let start = Int(position)
                    let end = min(start + size, timeline.count)
                    return timeline.subdata(in: start..<end)
                }
            )
            
            // 添加时间轴图片
            for (name, data) in timelineImages {
                try archive.addEntry(
                    with: "images/\(name)",
                    type: .file,
                    uncompressedSize: Int64(data.count),
                    bufferSize: Int(4096),
                    provider: { (position: Int64, size: Int) -> Data in
                        let start = Int(position)
                        let end = min(start + size, data.count)
                        return data.subdata(in: start..<end)
                    }
                )
            }
        } catch {
            throw TemplatePackageError.addEntryFailed
        }
        
        // 读取 ZIP 文件数据
        do {
            let fileHandle = try FileHandle(forReadingFrom: tempURL)
            defer {
                try? fileHandle.close()
                try? FileManager.default.removeItem(at: tempURL)
            }
            guard let data = try fileHandle.readToEnd() else {
                throw TemplatePackageError.readArchiveFailed
            }
            return data
        } catch {
            throw TemplatePackageError.readArchiveFailed
        }
    }
    
    /// 验证时间轴数据
    /// - Parameter timeline: 时间轴JSON数据
    /// - Returns: 时间轴中引用的图片名称列表
    static func validateTimeline(_ timeline: Data) throws -> [String] {
        guard let json = try JSONSerialization.jsonObject(with: timeline) as? [String: Any],
              let images = json["images"] as? [String] else {
            throw TemplatePackageError.invalidData
        }
        return images
    }
    
    /// 创建元数据
    /// - Parameters:
    ///   - userUid: 用户ID
    ///   - title: 模板标题
    ///   - languageSection: 语言分区
    ///   - version: 版本号
    ///   - duration: 时长（秒）
    ///   - tags: 标签列表
    /// - Returns: 元数据JSON字符串
    static func createMetadata(
        userUid: String,
        title: String,
        languageSection: String,
        version: String,
        duration: Int,
        tags: [String]
    ) throws -> String {
        let metadata: [String: Any] = [
            "user_uid": userUid,
            "title": title,
            "language_section_uid": languageSection,
            "version": version,
            "duration": duration,
            "tags": tags
        ]
        
        let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        return String(data: data, encoding: .utf8)!
    }
    
    static func createIncrementalPackage(
        coverImage: Data?,
        coverThumbnail: Data?,
        timeline: Data?,
        timelineImages: [String: Data]?,
        version: String
    ) throws -> Data {
        // 创建临时文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        
        // 创建 ZIP 文件
        let archive: Archive
        do {
            archive = try Archive(url: tempURL, accessMode: .create)
        } catch {
            throw TemplatePackageError.createArchiveFailed
        }
        
        do {
            // 使用版本化的文件名
            let coverOriginalName = getVersionedFileName(baseName: "covers_original.jpg", version: version)
            let coverThumbnailName = getVersionedFileName(baseName: "covers_thumbnails.jpg", version: version)
            let timelineName = getVersionedFileName(baseName: "timelines.json", version: version)
            
            // 添加封面图片
            if let coverImage = coverImage {
                try archive.addEntry(
                    with: coverOriginalName,
                    type: .file,
                    uncompressedSize: Int64(coverImage.count),
                    bufferSize: Int(4096),
                    provider: { position, size in
                        let rangeStart = Int(position)
                        let rangeEnd = min(rangeStart + size, coverImage.count)
                        return coverImage[rangeStart..<rangeEnd]
                    }
                )
            }
            
            // 添加封面缩略图
            if let coverThumbnail = coverThumbnail {
                try archive.addEntry(
                    with: coverThumbnailName,
                    type: .file,
                    uncompressedSize: Int64(coverThumbnail.count),
                    bufferSize: Int(4096),
                    provider: { position, size in
                        let rangeStart = Int(position)
                        let rangeEnd = min(rangeStart + size, coverThumbnail.count)
                        return coverThumbnail[rangeStart..<rangeEnd]
                    }
                )
            }
            
            // 添加时间轴数据
            if let timeline = timeline {
                try archive.addEntry(
                    with: timelineName,
                    type: .file,
                    uncompressedSize: Int64(timeline.count),
                    bufferSize: Int(4096),
                    provider: { position, size in
                        let rangeStart = Int(position)
                        let rangeEnd = min(rangeStart + size, timeline.count)
                        return timeline[rangeStart..<rangeEnd]
                    }
                )
            }
            
            // 时间轴图片保持原有命名方式
            if let timelineImages = timelineImages {
                for (imageName, imageData) in timelineImages {
                    try archive.addEntry(
                        with: "images/\(imageName)",
                        type: .file,
                        uncompressedSize: Int64(imageData.count),
                        bufferSize: Int(4096),
                        provider: { position, size in
                            let rangeStart = Int(position)
                            let rangeEnd = min(rangeStart + size, imageData.count)
                            return imageData[rangeStart..<rangeEnd]
                        }
                    )
                }
            }
        } catch {
            throw TemplatePackageError.addEntryFailed
        }
        
        // 读取 ZIP 文件数据
        do {
            let fileHandle = try FileHandle(forReadingFrom: tempURL)
            defer {
                try? fileHandle.close()
                try? FileManager.default.removeItem(at: tempURL)
            }
            guard let data = try fileHandle.readToEnd() else {
                throw TemplatePackageError.readArchiveFailed
            }
            return data
        } catch {
            throw TemplatePackageError.readArchiveFailed
        }
    }
} 
