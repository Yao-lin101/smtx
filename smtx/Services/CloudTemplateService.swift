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
    
    enum ImageUploadType {
        case cover
        case timeline
        
        var url: String {
            switch self {
            case .cover:
                return APIConfig.shared.uploadCoverURL
            case .timeline:
                return APIConfig.shared.uploadTimelineImageURL
            }
        }
    }
    
    // 上传图片并获取URL
    func uploadImage(_ imageData: Data, type: ImageUploadType) async throws -> String {
        do {
            let response: [String: String] = try await networkService.uploadMultipartFormData(
                url: type.url,
                data: imageData,
                name: "image",
                filename: "image.jpg",
                mimeType: "image/jpeg"
            )
            guard let imageUrl = response["url"] else {
                throw TemplateError.operationFailed("上传图片失败")
            }
            return imageUrl
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw TemplateError.serverError(message)
            case .unauthorized:
                throw TemplateError.unauthorized
            case .networkError(let error):
                throw TemplateError.networkError(error.localizedDescription)
            default:
                throw TemplateError.operationFailed("上传图片失败")
            }
        }
    }
    
    // 上传模板
    func uploadTemplate(_ template: Template, to languageSection: LanguageSection) async throws -> CloudTemplateUploadResponse {
        guard let userUid = await UserStore.shared.currentUser?.uid else {
            throw TemplateError.unauthorized
        }
        
        // 1. 准备所需数据
        guard let coverImage = template.coverImage else {
            throw TemplateError.invalidTemplate
        }
        
        // 生成缩略图
        let coverThumbnail: Data
        if let uiImage = UIImage(data: coverImage) {
            // 计算缩放比例，确保最大边不超过 300 像素
            let maxSize: CGFloat = 300
            let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height, 1.0)  // 添加 1.0 确保只缩小不放大
            let newSize = CGSize(
                width: min(round(uiImage.size.width * scale), maxSize),  // 确保不超过 300
                height: min(round(uiImage.size.height * scale), maxSize)  // 确保不超过 300
            )
            
            print("DEBUG - Original size: \(uiImage.size), New size: \(newSize), Scale: \(scale)")
            
            // 创建缩略图
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0  // 使用 1.0 scale 避免 Retina 分辨率
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            let thumbnailImage = renderer.image { context in
                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
            }
            
            // 转换为 JPEG 数据
            if let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                coverThumbnail = thumbnailData
                print("DEBUG - Thumbnail size: \(thumbnailImage.size), Data size: \(thumbnailData.count) bytes")
            } else {
                throw TemplateError.operationFailed("生成缩略图失败")
            }
        } else {
            throw TemplateError.operationFailed("无效的封面图片数据")
        }
        
        // 生成时间轴数据
        var timelineData = Data()
        var timelineImages: [String: Data] = [:]
        
        if let items = template.timelineItems {
            var timelineJson: [String: Any] = [:]
            var images: [String] = []
            var events: [[String: Any]] = []
            
            for case let item as TimelineItem in items {
                if let imageData = item.image {
                    let imageName = UUID().uuidString + ".jpg"
                    timelineImages[imageName] = imageData
                    images.append(imageName)
                    
                    // 添加事件
                    events.append([
                        "time": item.timestamp,
                        "image": imageName
                    ])
                }
            }
            
            timelineJson["duration"] = template.totalDuration
            timelineJson["images"] = images
            timelineJson["events"] = events
            timelineData = try JSONSerialization.data(withJSONObject: timelineJson)
        }
        
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
                formData
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
}
