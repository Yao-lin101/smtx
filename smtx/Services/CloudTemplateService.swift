import Foundation
import UIKit

class CloudTemplateService {
    static let shared = CloudTemplateService()
    private let tokenManager = TokenManager.shared
    private let apiConfig = APIConfig.shared
    private let networkService = NetworkService.shared
    
    private init() {}
    
    // MARK: - Language Sections
    
    func fetchLanguageSections() async throws -> [LanguageSection] {
        do {
            let response: PaginatedResponse<LanguageSection> = try await networkService.get(
                apiConfig.languageSectionsURL,
                decoder: DateDecoder.decoder
            )
            return response.results
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            case .decodingError:
                throw TemplateError.decodingError
            default:
                throw TemplateError.operationFailed("获取语言分区失败")
            }
        }
    }
    
    func createLanguageSection(name: String, chineseName: String = "") async throws -> LanguageSection {
        let body = [
            "name": name,
            "chinese_name": chineseName
        ]
        
        do {
            return try await networkService.postDictionary(
                apiConfig.languageSectionsURL,
                body: body,
                decoder: DateDecoder.decoder
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            case .decodingError:
                throw TemplateError.decodingError
            default:
                throw TemplateError.operationFailed("创建语言分区失败")
            }
        }
    }
    
    func deleteLanguageSection(uid: String) async throws {
        do {
            try await networkService.deleteNoContent(apiConfig.languageSectionURL(uid: uid))
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            default:
                throw TemplateError.operationFailed("删除语言分区失败")
            }
        }
    }
    
    func updateLanguageSection(uid: String, name: String, chineseName: String = "") async throws -> LanguageSection {
        let body = [
            "name": name,
            "chinese_name": chineseName
        ]
        
        do {
            return try await networkService.patchDictionary(
                apiConfig.languageSectionURL(uid: uid),
                body: body,
                decoder: DateDecoder.decoder
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            case .decodingError:
                throw TemplateError.decodingError
            default:
                throw TemplateError.operationFailed("更新语言分区失败")
            }
        }
    }
    
    // MARK: - Language Section Subscription
    
    func subscribeLanguageSection(uid: String) async throws -> Bool {
        do {
            let response: [String: String] = try await networkService.post(
                apiConfig.languageSectionSubscribeURL(uid: uid),
                body: EmptyBody()
            )
            return response["status"] == "subscribed"
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            default:
                throw TemplateError.operationFailed("订阅语言分区失败")
            }
        }
    }
    
    // MARK: - Cloud Templates
    
    func fetchTemplate(uid: String) async throws -> CloudTemplate {
        do {
            return try await networkService.get(
                apiConfig.templateURL(uid: uid),
                decoder: DateDecoder.decoder
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            case .decodingError:
                throw TemplateError.decodingError
            default:
                throw TemplateError.templateNotFound
            }
        }
    }
    
    func fetchTemplates(languageSection: String? = nil, search: String? = nil, page: Int = 1) async throws -> [CloudTemplate] {
        var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
        if let languageSection = languageSection {
            queryItems.append(URLQueryItem(name: "language_section", value: languageSection))
        }
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        let urlString = apiConfig.templatesURL + "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        
        do {
            let response: PaginatedResponse<CloudTemplate> = try await networkService.get(
                urlString,
                decoder: DateDecoder.decoder
            )
            return response.results
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            case .decodingError:
                throw TemplateError.decodingError
            default:
                throw TemplateError.operationFailed("获取模板列表失败")
            }
        }
    }
    
    func likeTemplate(uid: String) async throws -> Bool {
        do {
            let response: [String: String] = try await networkService.post(
                apiConfig.templateLikeURL(uid: uid),
                body: EmptyBody()
            )
            return response["status"] == "liked"
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            default:
                throw TemplateError.operationFailed("点赞失败")
            }
        }
    }
    
    func collectTemplate(uid: String) async throws -> Bool {
        do {
            let response: [String: String] = try await networkService.post(
                apiConfig.templateCollectURL(uid: uid),
                body: EmptyBody()
            )
            return response["status"] == "collected"
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            default:
                throw TemplateError.operationFailed("收藏失败")
            }
        }
    }
    
    func incrementTemplateUsage(uid: String) async throws {
        do {
            let _: EmptyBody = try await networkService.post(
                apiConfig.templateUsageURL(uid: uid),
                body: EmptyBody()
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            default:
                throw TemplateError.operationFailed("更新使用次数失败")
            }
        }
    }
    
    // MARK: - Template Upload
    
    // 上传模板
    func uploadTemplate(_ template: Template, to languageSection: LanguageSection, progressHandler: ((Double) -> Void)? = nil) async throws -> CloudTemplateUploadResponse {
        guard let userUid = await UserStore.shared.currentUser?.uid else {
            throw TemplateError.unauthorized
        }
        
        // 1. 准备所需数据
        guard let coverImage = template.coverImage else {
            throw TemplateError.invalidTemplate
        }
        
        // 生成缩略图
        let coverThumbnail = try ImageUtils.generateThumbnail(from: coverImage)
        
        // 生成时间轴数据
        let timelineItems = template.timelineItems?.compactMap { $0 as? TimelineItem } ?? []
        let (timelineData, timelineImages) = try TimelineUtils.generateTimelineData(
            from: timelineItems,
            duration: template.totalDuration
        )
        
        // 2. 创建模板包
        let packageData = try TemplatePackageService.createPackage(
            coverImage: coverImage,
            coverThumbnail: coverThumbnail,
            timeline: timelineData,
            timelineImages: timelineImages
        )
        
        // 3. 创建元数据
        let metadataDict: [String: Any] = [
            "user_uid": userUid,
            "title": template.title ?? "",
            "language_section": languageSection.uid,
            "version": template.version ?? "1.0",
            "duration": Int(template.totalDuration),
            "tags": template.tags as? [String] ?? []
        ]
        
        // 打印元数据以便调试
        print("Metadata: \(metadataDict)")
        
        // 4. 准备上传数据
        let formData = MultipartFormData()
        
        // 添加元数据，作为 JSON 字符串
        let metadataData = try JSONSerialization.data(withJSONObject: metadataDict)
        formData.append(
            metadataData,
            withName: "metadata",
            mimeType: "application/json"
        )
        
        // 添加模板包
        formData.append(
            packageData,
            withName: "media_package",
            fileName: "template.zip",
            mimeType: "application/zip"
        )
        
        // 打印请求体长度以便调试
        print("Request body size: \(formData.createBody().count) bytes")
        
        // 打印完整的请求头和请求体
        let body = formData.createBody()
        print("Content-Type: \(formData.contentType)")
        if let bodyString = String(data: body.prefix(1000), encoding: .utf8) {
            print("Request body preview: \(bodyString)")
        }
        
        // 打印元数据以便调试
        if let metadataString = String(data: metadataData, encoding: .utf8) {
            print("Raw metadata: \(metadataString)")
        }
        
        // 5. 发送请求
        do {
            let response: CloudTemplateUploadResponse = try await networkService.uploadFormData(
                apiConfig.uploadTemplatePackageURL,
                formData,
                progressHandler: progressHandler
            )
            return response
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                print("Server error: \(message)")
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                print("Network error: \(error.localizedDescription)")
                throw TemplateError.networkError(error.localizedDescription)
            default:
                throw TemplateError.operationFailed("上传模板失败")
            }
        }
    }
    
    // MARK: - Template Update
    
    func updateTemplate(_ template: Template, progressHandler: ((Double) -> Void)? = nil) async throws -> CloudTemplateUploadResponse {
        guard let cloudUid = template.cloudUid,
              let lastSyncedAt = template.lastSyncedAt else {
            print("❌ Invalid template: missing cloudUid or lastSyncedAt")
            throw TemplateError.invalidTemplate
        }
        
        // 1. 准备所需数据
        guard let coverImage = template.coverImage else {
            print("❌ Invalid template: missing coverImage")
            throw TemplateError.invalidTemplate
        }
        
        // 2. 检查各部分是否有更新
        let timelineItems = template.timelineItems?.compactMap { $0 as? TimelineItem } ?? []
        
        // 获取现有的图片名称映射（使用imageUpdatedAt时间戳）
        var existingImageNames: [Double: String] = [:]
        
        // 为所有有图片的项目生成图片名称
        for item in timelineItems {
            if item.image != nil {  // 如果有图片数据
                if let imageDate = item.imageUpdatedAt ?? item.createdAt {  // 如果都没有时间戳，跳过
                    let timestamp = Int64(imageDate.timeIntervalSince1970 * 1000)
                    existingImageNames[item.timestamp] = "img_\(timestamp).jpg"
                }
            }
        }
        
        print("📝 Existing image names: \(existingImageNames)")
        
        // 检查时间轴项目的更新
        var hasTimelineChanges = false
        var updatedImageItems: [TimelineItem] = []
        
        // 检查每个时间点的更新
        for item in timelineItems {
            // 检查脚本更新
            if let itemUpdatedAt = item.updatedAt,
               itemUpdatedAt > lastSyncedAt {
                hasTimelineChanges = true
            }
            
            // 检查图片更新
            if let imageDate = item.imageUpdatedAt,
               imageDate > lastSyncedAt {
                updatedImageItems.append(item)
            }
        }
        
        // 检查封面更新
        var hasCoverChanges = false
        if let coverUpdatedAt = template.coverUpdatedAt,
           coverUpdatedAt > lastSyncedAt {
            hasCoverChanges = true
        }
        
        // 检查元数据更新
        var hasMetadataChanges = false
        if let updatedAt = template.updatedAt,
           updatedAt > lastSyncedAt {
            hasMetadataChanges = true
        }
        
        print("📦 Update check:")
        print("  - Has timeline changes: \(hasTimelineChanges)")
        print("  - Has image updates: \(updatedImageItems.count)")
        print("  - Has cover changes: \(hasCoverChanges)")
        print("  - Has metadata changes: \(hasMetadataChanges)")
        print("  - Last synced at: \(lastSyncedAt)")
        print("  - Existing image names: \(existingImageNames)")
        
        // 3. 如果没有任何更新，直接返回错误
        if !hasTimelineChanges && !hasCoverChanges && !hasMetadataChanges && updatedImageItems.isEmpty {
            throw TemplateError.operationFailed("模板没有任何更新")
        }
        
        // 4. 准备封面缩略图（如果需要）
        var coverThumbnail: Data? = nil
        if hasCoverChanges {
            coverThumbnail = try ImageUtils.generateThumbnail(from: coverImage)
        }
        
        // 5. 准备时间轴数据（如果需要）
        var timelineData: Data? = nil
        var timelineImages: [String: Data]? = nil
        
        if hasTimelineChanges {
            // 如果有脚本更新，生成完整的时间轴 JSON，使用现有的图片名称
            let (data, _) = try TimelineUtils.generateTimelineData(
                from: timelineItems,
                duration: template.totalDuration,
                imageNames: existingImageNames,
                includeImages: false  // 只生成 JSON，不包含图片数据
            )
            timelineData = data
            print("📝 Timeline JSON generated with \(existingImageNames.count) image references")
        }
        
        if !updatedImageItems.isEmpty {
            // 只为有图片更新的项目生成图片数据，使用对应的图片名称
            var images: [String: Data] = [:]
            for item in updatedImageItems {
                if let imageName = existingImageNames[item.timestamp],
                   let imageData = item.image {
                    images[imageName] = imageData
                }
            }
            timelineImages = images
            print("📝 Timeline data prepared:")
            print("  - Updated images count: \(images.count)")
            print("  - Image names: \(images.keys.sorted())")
        }
        
        // 创建增量更新包
        let packageData = try TemplatePackageService.createIncrementalPackage(
            coverImage: hasCoverChanges ? coverImage : nil,
            coverThumbnail: coverThumbnail,
            timeline: timelineData,
            timelineImages: timelineImages
        )
        print("📦 Created update package: \(packageData.count) bytes")
        
        // 6. 创建元数据
        let metadataDict: [String: Any] = [
            "cloud_uid": cloudUid,
            "title": template.title ?? "",
            "version": template.version ?? "1.0",
            "duration": Int(template.totalDuration),
            "tags": template.tags as? [String] ?? []
        ]
        print("📋 Update metadata: \(metadataDict)")
        
        // 7. 准备上传数据
        let formData = MultipartFormData()
        
        // 添加元数据
        let metadataData = try JSONSerialization.data(withJSONObject: metadataDict)
        formData.append(
            metadataData,
            withName: "metadata",
            mimeType: "application/json"
        )
        
        // 添加模板包
        formData.append(
            packageData,
            withName: "media_package",
            fileName: "template.zip",
            mimeType: "application/zip"
        )
        
        print("📤 Sending update request to: \(apiConfig.updateTemplatePackageURL(uid: cloudUid))")
        
        // 8. 发送请求
        return try await networkService.uploadFormData(
            apiConfig.updateTemplatePackageURL(uid: cloudUid),
            formData,
            progressHandler: progressHandler
        )
    }
}
