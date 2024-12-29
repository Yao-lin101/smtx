import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case unknown
}

class NetworkService {
    static let shared = NetworkService()
    private let session = URLSession.shared
    private let tokenManager = TokenManager.shared
    
    private init() {}
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(_ url: String, requiresAuth: Bool = true) async throws -> T {
        let request = try createRequest(url: url, method: "GET", requiresAuth: requiresAuth)
        return try await performRequest(request)
    }
    
    func post<T: Decodable, B: Encodable>(_ url: String, body: B, requiresAuth: Bool = true) async throws -> T {
        var request = try createRequest(url: url, method: "POST", requiresAuth: requiresAuth)
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request)
    }
    
    func put<T: Decodable, B: Encodable>(_ url: String, body: B, requiresAuth: Bool = true) async throws -> T {
        var request = try createRequest(url: url, method: "PUT", requiresAuth: requiresAuth)
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request)
    }
    
    func patch<T: Decodable, B: Encodable>(_ url: String, body: B, requiresAuth: Bool = true) async throws -> T {
        var request = try createRequest(url: url, method: "PATCH", requiresAuth: requiresAuth)
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request)
    }
    
    func delete<T: Decodable>(_ url: String, requiresAuth: Bool = true) async throws -> T {
        let request = try createRequest(url: url, method: "DELETE", requiresAuth: requiresAuth)
        return try await performRequest(request)
    }
    
    // MARK: - Helper Methods
    
    private func createRequest(url: String, method: String, requiresAuth: Bool) throws -> URLRequest {
        guard let url = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            guard let token = tokenManager.accessToken else {
                throw NetworkError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    // MARK: - Dictionary Request Methods
    
    func putDictionary<T: Decodable>(_ url: String, body: [String: Any], requiresAuth: Bool = true) async throws -> T {
        var request = try createRequest(url: url, method: "PUT", requiresAuth: requiresAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request)
    }
    
    func postDictionary<T: Decodable>(_ url: String, body: [String: Any], requiresAuth: Bool = true) async throws -> T {
        var request = try createRequest(url: url, method: "POST", requiresAuth: requiresAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request)
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw NetworkError.decodingError(error)
                }
            case 401:
                throw NetworkError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorResponse["error"] {
                    throw NetworkError.serverError(errorMessage)
                }
                throw NetworkError.serverError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw NetworkError.unknown
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    // MARK: - Multipart Form Data
    
    func uploadMultipartFormData<T: Decodable>(
        url: String,
        data: Data,
        name: String,
        filename: String,
        mimeType: String
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try createRequest(url: url, method: "POST", requiresAuth: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // End marker
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await performRequest(request)
    }
} 