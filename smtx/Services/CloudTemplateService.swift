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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            case .decodingError(let error):
                throw CloudTemplateError.decodingError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            case .decodingError(let error):
                throw CloudTemplateError.decodingError(error)
            default:
                throw CloudTemplateError.unknown
            }
        }
    }
    
    func deleteLanguageSection(uid: String) async throws {
        do {
            try await networkService.deleteNoContent(apiConfig.languageSectionURL(uid: uid))
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            case .decodingError(let error):
                throw CloudTemplateError.decodingError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            case .decodingError(let error):
                throw CloudTemplateError.decodingError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            default:
                throw CloudTemplateError.unknown
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
                throw CloudTemplateError.serverError(message)
            case .unauthorized:
                throw CloudTemplateError.unauthorized
            case .networkError(let error):
                throw CloudTemplateError.networkError(error)
            case .decodingError(let error):
                throw CloudTemplateError.decodingError(error)
            default:
                throw CloudTemplateError.unknown
            }
        }
    }
}