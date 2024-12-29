import Foundation
import UIKit

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
                if message.contains("验证码错误") {
                    throw AuthError.invalidCode
                } else if message.contains("邮箱格式") {
                    throw AuthError.invalidEmail
                } else if message.contains("密码格式") {
                    throw AuthError.invalidPassword
                }
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
                switch message {
                case let msg where msg.contains("账号或密码错误"):
                    throw AuthError.loginFailed
                case let msg where msg.contains("密码格式"):
                    throw AuthError.invalidPassword
                case let msg where msg.contains("邮箱格式"):
                    throw AuthError.invalidEmail
                default:
                    throw AuthError.serverError(message)
                }
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
    
    func updateProfile(_ data: [String: Any]) async throws -> User {
        do {
            return try await networkService.putDictionary(
                apiConfig.profileURL,
                body: data
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                if message.contains("昵称已被使用") {
                    throw AuthError.usernameExists
                }
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
