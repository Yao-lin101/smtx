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

struct CloudTemplate: Codable, Identifiable {
    let uid: String
    let title: String
    let description: String?
    let authorUid: String
    let authorName: String
    let languageSection: String
    let tags: [String]
    let duration: Int
    let version: String
    let usageCount: Int
    let likesCount: Int
    let collectionsCount: Int
    let recordingsCount: Int
    let commentsCount: Int
    let isLiked: Bool
    let isCollected: Bool
    let timelineFile: String
    let coverOriginal: String
    let coverThumbnail: String
    let createdAt: Date
    let updatedAt: Date
    
    var id: String { uid }
} 