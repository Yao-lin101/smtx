import Foundation

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)  // 添加编码错误类型
    case serverError(String)
    case unauthorized
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解析错误：\(error.localizedDescription)"
        case .encodingError(let error):
            return "数据编码错误：\(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "未授权"
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case invalidCode
    case emailExists
    case loginFailed
    case networkError(String)
    case serverError(String)
    case unauthorized
    case usernameExists
    case decodingError
    case tokenExpired
    case refreshTokenExpired
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "邮箱格式不正确"
        case .invalidPassword:
            return "密码格式不正确"
        case .invalidCode:
            return "验证码不正确"
        case .emailExists:
            return "该邮箱已被注册"
        case .loginFailed:
            return "账号或密码错误"
        case .networkError(let message):
            return "网络错误：\(message)"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .unauthorized:
            return "未授权"
        case .usernameExists:
            return "该昵称已被使用"
        case .decodingError:
            return "数据解析失败"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        case .refreshTokenExpired:
            return "登录已过期，请重新登录"
        }
    }
}

// MARK: - Template Errors

enum TemplateError: LocalizedError {
    case invalidTemplate
    case templateNotFound
    case invalidLanguageSection
    case languageSectionNotFound
    case networkError(String)
    case serverError(String)
    case unauthorized
    case decodingError
    case operationFailed(String)
    case noChanges
    
    var errorDescription: String? {
        switch self {
        case .invalidTemplate:
            return "无效的模板"
        case .templateNotFound:
            return "模板不存在"
        case .invalidLanguageSection:
            return "无效的语言分区"
        case .languageSectionNotFound:
            return "语言分区不存在"
        case .networkError(let message):
            return "网络错误：\(message)"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .unauthorized:
            return "未授权"
        case .decodingError:
            return "数据解析失败"
        case .operationFailed(let message):
            return message
        case .noChanges:
            return "没有需要更新的内容"
        }
    }
}

// MARK: - Cache Errors

enum CacheError: LocalizedError {
    case invalidData
    case saveFailed
    case loadFailed
    case notFound
    case diskError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "无效的数据"
        case .saveFailed:
            return "保存失败"
        case .loadFailed:
            return "加载失败"
        case .notFound:
            return "数据不存在"
        case .diskError(let message):
            return "磁盘错误：\(message)"
        }
    }
} 