import Foundation

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
    private let baseURL = "http://192.168.1.101:8000/api"  // 使用服务器的局域网 IP
    #else
    private let baseURL = "https://api.example.com/api"  // 生产环境（待配置）
    #endif
    
    private init() {}
    
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
        
        #if DEBUG
        print("[\(method)] \(url)")
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body, options: []) {
            print("Request Body:", json)
        }
        #endif
        
        return request
    }
    
    func sendVerificationCode(email: String) async throws {
        let request = makeRequest(
            "users/send_code/",
            method: "POST",
            body: ["email": email]
        )
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30    // 请求超时时间
        configuration.timeoutIntervalForResource = 300  // 资源超时时间
        configuration.waitsForConnectivity = true      // 等待网络连接
        
        let session = URLSession(configuration: configuration)
        
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
            throw AuthError.emailExists
        }
        
        if httpResponse.statusCode != 200 {
            throw AuthError.serverError("状态码：\(httpResponse.statusCode)")
        }
    }
    
    func register(email: String, password: String, code: String) async throws -> RegisterResponse {
        // 生成随机用户名（使用邮箱前缀加随机数）
        let username = "user_\(Int.random(in: 10000...99999))"
        let nickname = "用户\(Int.random(in: 10000...99999))"
        
        let body = RegisterRequest(
            email: email,
            password: password,
            password2: password,
            code: code,
            username: username,
            nickname: nickname
        )
        
        let request = makeRequest(
            "users/register/",
            method: "POST",
            body: body
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
            throw AuthError.serverError("注册失败")
        }
        
        if httpResponse.statusCode != 200 {
            throw AuthError.serverError("状态码：\(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RegisterResponse.self, from: data)
    }
}

// 请求模型
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let password2: String
    let code: String
    let username: String
    let nickname: String
}

// 响应模型
struct User: Codable {
    let id: String
    let username: String
    let nickname: String
    let email: String
    let avatar: String?
    let userType: String
    let isEmailVerified: Bool
    let isWechatVerified: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, username, nickname, email, avatar
        case userType = "user_type"
        case isEmailVerified = "is_email_verified"
        case isWechatVerified = "is_wechat_verified"
    }
}

struct RegisterResponse: Codable {
    let refresh: String
    let access: String
    let user: User
} 