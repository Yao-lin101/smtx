import Foundation

// MARK: - Protocols

protocol RequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

protocol ResponseInterceptor {
    func process(response: HTTPURLResponse, data: Data) async throws
}

// MARK: - Authentication Interceptor

class AuthenticationInterceptor: RequestInterceptor {
    private let tokenManager: TokenManager
    
    init(tokenManager: TokenManager) {
        self.tokenManager = tokenManager
    }
    
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

// MARK: - Error Interceptor

class ErrorInterceptor: ResponseInterceptor {
    func process(response: HTTPURLResponse, data: Data) async throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            if let errorResponse = try? JSONDecoder().decode([String: [String]].self, from: data),
               let firstError = errorResponse["error"]?.first {
                throw NetworkError.serverError(firstError)
            } else if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["detail"] ?? errorResponse["error"] {
                throw NetworkError.serverError(errorMessage)
            }
            
            throw NetworkError.serverError("Client error: \(response.statusCode)")
        case 500...599:
            throw NetworkError.serverError("Server error: \(response.statusCode)")
        default:
            throw NetworkError.unknown
        }
    }
}

// MARK: - Interceptor Manager

class NetworkInterceptorManager {
    static let shared = NetworkInterceptorManager()
    
    let requestInterceptors: [RequestInterceptor]
    let responseInterceptors: [ResponseInterceptor]
    
    private init() {
        let tokenManager = TokenManager.shared
        
        self.requestInterceptors = [
            AuthenticationInterceptor(tokenManager: tokenManager)
        ]
        
        self.responseInterceptors = [
            ErrorInterceptor()
        ]
    }
    
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
        var adaptedRequest = request
        for interceptor in requestInterceptors {
            adaptedRequest = try await interceptor.adapt(adaptedRequest)
        }
        return adaptedRequest
    }
    
    func processResponse(_ response: HTTPURLResponse, data: Data) async throws {
        for interceptor in responseInterceptors {
            try await interceptor.process(response: response, data: data)
        }
    }
} 