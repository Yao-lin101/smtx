import Foundation
import UIKit

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case invalidCode
    case emailExists
    case networkError(String)
    case serverError(String)
    
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
        case .networkError(let message):
            return "网络错误：\(message)"
        case .serverError(let message):
            return "服务器错误：\(message)"
        }
    }
}

class AuthService {
    static let shared = AuthService()
    
    #if DEBUG
    let baseURL = "http://192.168.1.102:8000/api"  // 使用服务器的局域网 IP
    #else
    let baseURL = "https://api.example.com/api"  // 生产环境（待配置）
    #endif
    
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30    // 请求超时时间
        configuration.timeoutIntervalForResource = 300  // 资源超时时间
        configuration.waitsForConnectivity = true      // 等待网络连接
        
        self.session = URLSession(configuration: configuration)
    }
    
    private func makeRequest<T: Encodable>(_ endpoint: String, method: String, body: T) -> URLRequest {
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 增加超时时间到30秒
        request.timeoutInterval = 30
        
        // 配置缓存策略
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let encoder = JSONEncoder()
        request.httpBody = try? encoder.encode(body)
        
        return request
    }
    
    func sendVerificationCode(email: String) async throws {
        let request = makeRequest(
            "users/send_verify_code/",
            method: "POST",
            body: ["email": email]
        )
        
        let (data, response) = try await session.data(for: request)
        
        #if DEBUG
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            print("Response:", json)
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("无效的响应")
        }
        
        if httpResponse.statusCode == 400 {
            if let errorResponse = try? JSONDecoder().decode([String: [String]].self, from: data),
               let firstError = errorResponse.first?.value.first {
                throw AuthError.serverError(firstError)
            }
            
            // 尝试解析简单的错误消息
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                if errorMessage.contains("已被注册") {
                    throw AuthError.emailExists
                }
                throw AuthError.serverError(errorMessage)
            }
            
            throw AuthError.serverError("发送验证码失败")
        }
        
        if httpResponse.statusCode != 200 {
            throw AuthError.serverError("状态码：\(httpResponse.statusCode)")
        }
    }
    
    func register(email: String, password: String, code: String) async throws -> RegisterResponse {
        let body = RegisterRequest(
            email: email,
            password: password,
            verify_code: code
        )
        
        let request = makeRequest(
            "users/register_email/",
            method: "POST",
            body: body
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("无效的响应")
        }
        
        if httpResponse.statusCode == 400 {
            if let errorResponse = try? JSONDecoder().decode([String: [String]].self, from: data),
               let firstError = errorResponse.first?.value.first {
                throw AuthError.serverError(firstError)
            }
            
            // 尝试解析简单的错误消息
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw AuthError.serverError(errorMessage)
            }
            
            throw AuthError.serverError("注册失败")
        }
        
        if httpResponse.statusCode != 201 {
            throw AuthError.serverError("状态码：\(httpResponse.statusCode)")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(RegisterResponse.self, from: data)
        } catch {
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    throw AuthError.serverError("缺少字段：\(key.stringValue)")
                case .typeMismatch(let type, let context):
                    throw AuthError.serverError("字段类型不匹配：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    throw AuthError.serverError("字段为空：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    throw AuthError.serverError("数据格式错误：\(context.debugDescription)")
                @unknown default:
                    throw AuthError.serverError("未知解码错误")
                }
            }
            throw AuthError.serverError("数据解析失败：\(error.localizedDescription)")
        }
    }
    
    func login(email: String, password: String) async throws -> LoginResponse {
        let body = LoginRequest(
            email: email,
            password: password
        )
        
        let request = makeRequest(
            "users/token/",
            method: "POST",
            body: body
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("无效的响应")
        }
        
        if httpResponse.statusCode == 400 {
            if let errorResponse = try? JSONDecoder().decode([String: [String]].self, from: data),
               let firstError = errorResponse.first?.value.first {
                throw AuthError.serverError(firstError)
            }
            
            // 尝试解析简单的错误消息
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                if errorMessage.contains("密码错误") {
                    throw AuthError.invalidPassword
                }
                throw AuthError.serverError(errorMessage)
            }
            
            throw AuthError.serverError("登录失败")
        }
        
        if httpResponse.statusCode != 200 {
            throw AuthError.serverError("状态码：\(httpResponse.statusCode)")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(LoginResponse.self, from: data)
        } catch {
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    throw AuthError.serverError("缺少字段：\(key.stringValue)")
                case .typeMismatch(let type, let context):
                    throw AuthError.serverError("字段类型不匹配：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    throw AuthError.serverError("字段为空：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    throw AuthError.serverError("数据格式错误：\(context.debugDescription)")
                @unknown default:
                    throw AuthError.serverError("未知解码错误")
                }
            }
            throw AuthError.serverError("数据解析失败：\(error.localizedDescription)")
        }
    }
    
    func uploadAvatar(_ image: UIImage) async throws -> User {
        // 将图片转换为 JPEG 数据
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AuthError.serverError("图片处理失败")
        }
        
        // 创建 multipart/form-data 请求
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "\(baseURL)/users/upload_avatar/")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 添加认证头
        if let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 构建请求体
        var body = Data()
        
        // 添加文件数据
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 结束标记
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("无效的响应")
        }
        
        if httpResponse.statusCode == 401 {
            throw AuthError.serverError("请重新登录")
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw AuthError.serverError(errorMessage)
            }
            throw AuthError.serverError("上传失败：\(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(User.self, from: data)
    }
}

// 请求模型
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let verify_code: String
}

// 响应模型
struct User: Codable {
    let uid: String
    let username: String
    let email: String
    let avatar: String?
    let isEmailVerified: Bool
    let isWechatVerified: Bool
    let wechatId: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case uid
        case username
        case email
        case avatar
        case isEmailVerified = "is_email_verified"
        case isWechatVerified = "is_wechat_verified"
        case wechatId = "wechat_id"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        uid = try container.decode(String.self, forKey: .uid)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        
        // 处理布尔值，持数字和布尔类型
        if let boolValue = try? container.decode(Bool.self, forKey: .isEmailVerified) {
            isEmailVerified = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isEmailVerified) {
            isEmailVerified = intValue != 0
        } else {
            isEmailVerified = false
        }
        
        if let boolValue = try? container.decode(Bool.self, forKey: .isWechatVerified) {
            isWechatVerified = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isWechatVerified) {
            isWechatVerified = intValue != 0
        } else {
            isWechatVerified = false
        }
        
        wechatId = try container.decodeIfPresent(String.self, forKey: .wechatId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
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
    
    enum CodingKeys: String, CodingKey {
        case refresh
        case access
        case user
    }
} 