import Foundation

enum CloudTemplateError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case serverError(String)
    case unauthorized
    case unknown
}

class CloudTemplateService {
    static let shared = CloudTemplateService()
    private let baseURL = "http://localhost:8000/api"
    private let tokenManager = TokenManager.shared
    
    private init() {}
    
    // MARK: - Language Sections
    
    func fetchLanguageSections() async throws -> [LanguageSection] {
        guard let url = URL(string: "\(baseURL)/language-sections/") else {
            throw CloudTemplateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTemplateError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let result = try decoder.decode(PaginatedResponse<LanguageSection>.self, from: data)
                return result.results
            case 401:
                throw CloudTemplateError.unauthorized
            case 400...499:
                throw CloudTemplateError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw CloudTemplateError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw CloudTemplateError.unknown
            }
        } catch let error as CloudTemplateError {
            throw error
        } catch {
            throw CloudTemplateError.networkError(error)
        }
    }
    
    func createLanguageSection(name: String) async throws -> LanguageSection {
        guard let url = URL(string: "\(baseURL)/language-sections/") else {
            throw CloudTemplateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 准备请求体
        let body = ["name": name]
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTemplateError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 201:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(LanguageSection.self, from: data)
            case 401:
                throw CloudTemplateError.unauthorized
            case 400...499:
                throw CloudTemplateError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw CloudTemplateError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw CloudTemplateError.unknown
            }
        } catch let error as CloudTemplateError {
            throw error
        } catch {
            throw CloudTemplateError.networkError(error)
        }
    }
    
    func deleteLanguageSection(uid: String) async throws {
        guard let url = URL(string: "\(baseURL)/language-sections/\(uid)/") else {
            throw CloudTemplateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // 添加认证token
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTemplateError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 204:
                return
            case 401:
                throw CloudTemplateError.unauthorized
            case 400...499:
                throw CloudTemplateError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw CloudTemplateError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw CloudTemplateError.unknown
            }
        } catch let error as CloudTemplateError {
            throw error
        } catch {
            throw CloudTemplateError.networkError(error)
        }
    }
    
    // MARK: - Cloud Templates
    
    func fetchTemplate(uid: String) async throws -> CloudTemplate {
        guard let url = URL(string: "\(baseURL)/templates/\(uid)/") else {
            throw CloudTemplateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTemplateError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(CloudTemplate.self, from: data)
            case 401:
                throw CloudTemplateError.unauthorized
            case 400...499:
                throw CloudTemplateError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw CloudTemplateError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw CloudTemplateError.unknown
            }
        } catch let error as CloudTemplateError {
            throw error
        } catch {
            throw CloudTemplateError.networkError(error)
        }
    }
    
    func fetchTemplates(languageSection: String? = nil, tag: String? = nil, authorUid: String? = nil) async throws -> [CloudTemplate] {
        var urlComponents = URLComponents(string: "\(baseURL)/templates/")
        var queryItems: [URLQueryItem] = []
        
        if let languageSection = languageSection {
            queryItems.append(URLQueryItem(name: "language_section", value: languageSection))
        }
        if let tag = tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if let authorUid = authorUid {
            queryItems.append(URLQueryItem(name: "author_uid", value: authorUid))
        }
        
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }
        
        guard let url = urlComponents?.url else {
            throw CloudTemplateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTemplateError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let result = try decoder.decode(PaginatedResponse<CloudTemplate>.self, from: data)
                return result.results
            case 401:
                throw CloudTemplateError.unauthorized
            case 400...499:
                throw CloudTemplateError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw CloudTemplateError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw CloudTemplateError.unknown
            }
        } catch let error as CloudTemplateError {
            throw error
        } catch {
            throw CloudTemplateError.networkError(error)
        }
    }
    
    func likeTemplate(uid: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/templates/\(uid)/like/") else {
            throw CloudTemplateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTemplateError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let result = try decoder.decode([String: String].self, from: data)
                return result["status"] == "liked"
            case 401:
                throw CloudTemplateError.unauthorized
            case 400...499:
                throw CloudTemplateError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw CloudTemplateError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw CloudTemplateError.unknown
            }
        } catch let error as CloudTemplateError {
            throw error
        } catch {
            throw CloudTemplateError.networkError(error)
        }
    }
    
    func collectTemplate(uid: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/templates/\(uid)/collect/") else {
            throw CloudTemplateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudTemplateError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let result = try decoder.decode([String: String].self, from: data)
                return result["status"] == "collected"
            case 401:
                throw CloudTemplateError.unauthorized
            case 400...499:
                throw CloudTemplateError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw CloudTemplateError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw CloudTemplateError.unknown
            }
        } catch let error as CloudTemplateError {
            throw error
        } catch {
            throw CloudTemplateError.networkError(error)
        }
    }
}

// MARK: - Response Models

struct PaginatedResponse<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}

struct LanguageSection: Codable, Identifiable {
    let uid: String
    let name: String
    let templatesCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    var id: String { uid }
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