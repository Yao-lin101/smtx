import Foundation

enum APIVersion: String {
    case v1 = "v1"
}

struct APIConfig {
    static let shared = APIConfig()
    
    #if DEBUG
    private let baseHost = "http://192.168.1.102:8000"  // 使用服务器的局域网 IP
    #else
    private let baseHost = "https://api.example.com"  // 生产环境（待配置）
    #endif
    
    private let currentVersion: APIVersion = .v1
    
    var baseURL: String {
        return "\(baseHost)/api/\(currentVersion.rawValue)"
    }
    
    // Auth URLs
    var loginURL: String { return "\(baseURL)/auth/token/" }
    var refreshTokenURL: String { return "\(baseURL)/auth/token/refresh/" }
    
    // User URLs
    var registerURL: String { return "\(baseURL)/users/register_email/" }
    var verifyCodeURL: String { return "\(baseURL)/users/send_verify_code/" }
    var profileURL: String { return "\(baseURL)/users/profile/" }
    var changePasswordURL: String { return "\(baseURL)/users/change_password/" }
    var uploadAvatarURL: String { return "\(baseURL)/users/upload_avatar/" }
    func banUserURL(uid: String) -> String { return "\(baseURL)/users/\(uid)/ban/" }
    var usersURL: String { return "\(baseURL)/users/" }
    var userCountURL: String { return "\(baseURL)/users/count/" }
    
    // Template URLs
    var templatesURL: String { return "\(baseURL)/templates/" }
    func templateURL(uid: String) -> String { return "\(baseURL)/templates/\(uid)/" }
    func templateLikeURL(uid: String) -> String { return "\(baseURL)/templates/\(uid)/like/" }
    func templateCollectURL(uid: String) -> String { return "\(baseURL)/templates/\(uid)/collect/" }
    func templateUsageURL(uid: String) -> String { return "\(baseURL)/templates/\(uid)/increment_usage/" }
    
    // Template Upload URLs
    var uploadTemplatePackageURL: String { return "\(baseURL)/templates/upload-package/" }

    // Template Update URLs
    func updateTemplatePackageURL(uid: String) -> String {
    return "\(baseURL)/api/v1/templates/\(uid)/update-package"
    } 
    
    // Template Comments URLs
    func templateCommentsURL(templateUid: String) -> String { return "\(baseURL)/templates/\(templateUid)/comments/" }
    func templateCommentURL(templateUid: String, commentId: String) -> String { 
        return "\(baseURL)/templates/\(templateUid)/comments/\(commentId)/" 
    }
    
    // Template Recordings URLs
    func templateRecordingsURL(templateUid: String) -> String { return "\(baseURL)/templates/\(templateUid)/recordings/" }
    func templateRecordingURL(templateUid: String, recordingId: String) -> String { 
        return "\(baseURL)/templates/\(templateUid)/recordings/\(recordingId)/" 
    }
    
    // Language Section URLs
    var languageSectionsURL: String { return "\(baseURL)/language-sections/" }
    func languageSectionURL(uid: String) -> String { return "\(baseURL)/language-sections/\(uid)/" }
    func languageSectionSubscribeURL(uid: String) -> String { return "\(baseURL)/language-sections/\(uid)/subscribe/" }
    
    private init() {}
} 