import Foundation
import UIKit

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case invalidCode
    case emailExists
    case networkError(String)
    case serverError(String)
    case unauthorized
    case usernameExists
    case decodingError
    
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
        case .unauthorized:
            return "未授权"
        case .usernameExists:
            return "该昵称已被使用"
        case .decodingError:
            return "数据解析失败"
        }
    }
}

class AuthService {
    static let shared = AuthService()
    private let apiConfig = APIConfig.shared
    private let networkService = NetworkService.shared
    
    private init() {}
    
    func sendVerificationCode(email: String) async throws {
        do {
            let _: EmptyBody = try await networkService.post(
                apiConfig.verifyCodeURL,
                body: ["email": email]
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                if message.contains("已被注册") {
                    throw AuthError.emailExists
                }
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.unauthorized
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
    
    func register(email: String, password: String, code: String) async throws -> RegisterResponse {
        let body = RegisterRequest(
            email: email,
            password: password,
            verify_code: code
        )
        
        do {
            return try await networkService.post(
                apiConfig.registerURL,
                body: body,
                requiresAuth: false
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.unauthorized
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            case .decodingError(let error):
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, _):
                        throw AuthError.serverError("缺少字段：\(key.stringValue)")
                    case .typeMismatch(_, let context):
                        throw AuthError.serverError("字段类型不匹配：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(_, let context):
                        throw AuthError.serverError("字段为空：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        throw AuthError.serverError("数据格式错误：\(context.debugDescription)")
                    @unknown default:
                        throw AuthError.serverError("未知解码错误")
                    }
                }
                throw AuthError.serverError("数据解析失败：\(error.localizedDescription)")
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
    
    func login(email: String, password: String) async throws -> LoginResponse {
        let body = LoginRequest(
            email: email,
            password: password
        )
        
        do {
            return try await networkService.post(
                apiConfig.loginURL,
                body: body,
                requiresAuth: false
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                if message.contains("密码错误") {
                    throw AuthError.invalidPassword
                }
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.unauthorized
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            case .decodingError(let error):
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, _):
                        throw AuthError.serverError("缺少字段：\(key.stringValue)")
                    case .typeMismatch(_, let context):
                        throw AuthError.serverError("字段类型不匹配：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(_, let context):
                        throw AuthError.serverError("字段为空：\(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        throw AuthError.serverError("数据格式错误：\(context.debugDescription)")
                    @unknown default:
                        throw AuthError.serverError("未知解码错误")
                    }
                }
                throw AuthError.serverError("数据解析失败：\(error.localizedDescription)")
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
    
    func uploadAvatar(_ image: UIImage) async throws -> User {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AuthError.serverError("图片处理失败")
        }
        
        do {
            return try await networkService.uploadMultipartFormData(
                url: apiConfig.uploadAvatarURL,
                data: imageData,
                name: "avatar",
                filename: "avatar.jpg",
                mimeType: "image/jpeg"
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.serverError("请重新登录")
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
    
    func updateProfile(_ data: [String: Any]) async throws -> User {
        do {
            return try await networkService.putDictionary(
                apiConfig.profileURL,
                body: data
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.unauthorized
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - User Management
    
    func fetchUsers(search: String = "", page: Int = 1) async throws -> PaginatedResponse<User> {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "page", value: "\(page)")]
        if !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        let urlString = apiConfig.usersURL + "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        
        do {
            return try await networkService.get(urlString)
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.unauthorized
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            case .decodingError:
                throw AuthError.decodingError
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
    
    func toggleUserBan(uid: String) async throws -> String {
        do {
            let response: [String: String] = try await networkService.post(
                apiConfig.banUserURL(uid: uid),
                body: EmptyBody()
            )
            return response["message"] ?? "操作成功"
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.unauthorized
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
    
    func fetchUserCount() async throws -> Int {
        do {
            let response: [String: Int] = try await networkService.get(apiConfig.userCountURL)
            return response["total"] ?? 0
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw AuthError.serverError(message)
            case .unauthorized:
                throw AuthError.unauthorized
            case .networkError(let error):
                throw AuthError.networkError(error.localizedDescription)
            case .decodingError:
                throw AuthError.decodingError
            default:
                throw AuthError.serverError(error.localizedDescription)
            }
        }
    }
}
