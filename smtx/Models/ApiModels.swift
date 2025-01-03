import Foundation

struct PaginatedResponse<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
} 

// 请求模型
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let verify_code: String
}

// 响应模型
struct User: Codable, Identifiable {
    var id: String { uid }
    let uid: String
    let username: String
    let email: String
    let avatar: String?
    let bio: String?
    let isEmailVerified: Bool
    let isWechatVerified: Bool
    let wechatId: String?
    let createdAt: String
    let isSuperuser: Bool
    var isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case uid
        case username
        case email
        case avatar
        case bio
        case isEmailVerified = "is_email_verified"
        case isWechatVerified = "is_wechat_verified"
        case wechatId = "wechat_id"
        case createdAt = "created_at"
        case isSuperuser = "is_superuser"
        case isActive = "is_active"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        uid = try container.decode(String.self, forKey: .uid)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        
        // 强制解码 is_active，如果字段缺失会抛出错误
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        isEmailVerified = try container.decode(Bool.self, forKey: .isEmailVerified)
        isWechatVerified = try container.decode(Bool.self, forKey: .isWechatVerified)
        wechatId = try container.decodeIfPresent(String.self, forKey: .wechatId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        isSuperuser = try container.decode(Bool.self, forKey: .isSuperuser)
    }
}

struct RegisterResponse: Codable {
    let refresh: String
    let access: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case refresh
        case access
        case user
    }
}

// 请求模型
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// 响应模型
struct LoginResponse: Codable {
    let refresh: String
    let access: String
    let user: User
}

// 空请求体结构体
struct EmptyBody: Codable {} 

struct LanguageSection: Codable, Identifiable, Equatable {
    let uid: String
    let name: String
    let chineseName: String
    let templatesCount: Int
    var isSubscribed: Bool
    let createdAt: Date
    let updatedAt: Date
    
    var id: String { uid }
    
    static func == (lhs: LanguageSection, rhs: LanguageSection) -> Bool {
        lhs.uid == rhs.uid &&
        lhs.name == rhs.name &&
        lhs.chineseName == rhs.chineseName &&
        lhs.templatesCount == rhs.templatesCount &&
        lhs.isSubscribed == rhs.isSubscribed &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }
}

struct CloudTemplateListItem: Codable, Identifiable {
    let uid: String
    let title: String
    let tags: [String]
    let duration: Int
    let coverThumbnail: String
    let createdAt: Date
    let status: String
    
    var id: String { uid }
    
    var fullCoverThumbnail: String {
        APIConfig.shared.mediaURL(coverThumbnail)
    }
}

struct CloudTemplateListResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [CloudTemplateListItem]
}

struct TemplateComment: Codable, Equatable {
    let id: Int
    let userUid: String
    let content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userUid = "user_uid"
        case content
        case createdAt = "created_at"
    }
}

struct TemplateRecording: Codable, Equatable {
    let uid: String
    let userUid: String
    let audioFile: String
    let duration: Int
    let createdAt: Date
    
    var fullAudioFile: String {
        APIConfig.shared.mediaURL(audioFile)
    }
}

struct CloudTemplate: Codable, Identifiable, Equatable {
    let uid: String
    let title: String
    let authorUid: String?
    let authorName: String?
    let authorAvatar: String?
    let duration: Int
    let usageCount: Int?
    let timelineFile: String
    let coverOriginal: String
    let likesCount: Int
    let collectionsCount: Int
    let commentsCount: Int
    let recordingsCount: Int
    let status: TemplateStatus
    let comments: [TemplateComment]
    let recordings: [TemplateRecording]
    let isLiked: Bool
    let isCollected: Bool
    let updatedAt: Date
    
    var id: String { uid }
    
    var fullAuthorAvatar: String? {
        if let avatar = authorAvatar {
            return APIConfig.shared.mediaURL(avatar)
        }
        return nil
    }
    
    var fullTimelineFile: String {
        APIConfig.shared.mediaURL(timelineFile)
    }
    
    var fullCoverOriginal: String {
        APIConfig.shared.mediaURL(coverOriginal)
    }
    
    enum TemplateStatus: String, Codable {
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
    }
    
    static func == (lhs: CloudTemplate, rhs: CloudTemplate) -> Bool {
        lhs.uid == rhs.uid &&
        lhs.title == rhs.title &&
        lhs.authorUid == rhs.authorUid &&
        lhs.authorName == rhs.authorName &&
        lhs.authorAvatar == rhs.authorAvatar &&
        lhs.duration == rhs.duration &&
        lhs.usageCount == rhs.usageCount &&
        lhs.timelineFile == rhs.timelineFile &&
        lhs.coverOriginal == rhs.coverOriginal &&
        lhs.likesCount == rhs.likesCount &&
        lhs.collectionsCount == rhs.collectionsCount &&
        lhs.commentsCount == rhs.commentsCount &&
        lhs.recordingsCount == rhs.recordingsCount &&
        lhs.status == rhs.status &&
        lhs.isLiked == rhs.isLiked &&
        lhs.isCollected == rhs.isCollected &&
        lhs.updatedAt == rhs.updatedAt
    }
}

struct CloudTemplateUpload: Codable {
    let userUid: String
    let title: String
    let version: String
    let tags: [String]
    let duration: Int
    let languageSectionUid: String
    let coverUrl: String
    let timelineItems: [TimelineItem]
    let cloudUid: String?
    
    struct TimelineItem: Codable {
        let timestamp: Double
        let script: String
        let imageUrl: String
        
        enum CodingKeys: String, CodingKey {
            case timestamp
            case script
            case imageUrl = "image_url"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case userUid = "user_uid"
        case title
        case version
        case tags
        case duration
        case languageSectionUid = "language_section_uid"
        case coverUrl = "cover_url"
        case timelineItems = "timeline_items"
        case cloudUid = "cloud_uid"
    }
}

struct CloudTemplateUploadResponse: Codable {
    let uid: String
    let status: CloudTemplate.TemplateStatus
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case uid
        case status
        case errorMessage = "error_message"
    }
}

struct ErrorResponse: Codable {
    let message: String
    let code: String?
    
    private enum CodingKeys: String, CodingKey {
        case message
        case code
    }
}

struct TimelineData: Codable {
    let duration: Double
    let images: [String]
    let events: [TimelineEvent]
}

struct TimelineEvent: Codable, Identifiable {
    let time: Double
    let text: String?
    let image: String?
    
    var id: Double { time }
}

struct RecordingUploadResponse: Codable {
    let message: String
} 