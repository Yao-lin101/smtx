import Foundation

class NetworkService {
    static let shared = NetworkService()
    private let session = URLSession.shared
    private let tokenManager = TokenManager.shared
    private let interceptorManager = NetworkInterceptorManager.shared
    
    private init() {}
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(_ url: String, decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        let request = try await createRequest(url: url, method: "GET", requiresAuth: requiresAuth)
        return try await performRequest(request, decoder: decoder)
    }
    
    func post<T: Decodable, B: Encodable>(_ url: String, body: B, decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        var request = try await createRequest(url: url, method: "POST", requiresAuth: requiresAuth)
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request, decoder: decoder)
    }
    
    func put<T: Decodable, B: Encodable>(_ url: String, body: B, decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        var request = try await createRequest(url: url, method: "PUT", requiresAuth: requiresAuth)
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request, decoder: decoder)
    }
    
    func patch<T: Decodable, B: Encodable>(_ url: String, body: B, decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        var request = try await createRequest(url: url, method: "PATCH", requiresAuth: requiresAuth)
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request, decoder: decoder)
    }
    
    func delete<T: Decodable>(_ url: String, decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        let request = try await createRequest(url: url, method: "DELETE", requiresAuth: requiresAuth)
        return try await performRequest(request, decoder: decoder)
    }
    
    func deleteNoContent(_ url: String, requiresAuth: Bool = true) async throws {
        let request = try await createRequest(url: url, method: "DELETE", requiresAuth: requiresAuth)
        try await performRequestNoContent(request)
    }
    
    // MARK: - Helper Methods
    
    private func createRequest(url: String, method: String, requiresAuth: Bool) async throws -> URLRequest {
        guard let url = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            request = try await interceptorManager.adaptRequest(request)
        }
        
        return request
    }
    
    private func performRequestNoContent(_ request: URLRequest) async throws {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            try await interceptorManager.processResponse(httpResponse, data: data)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    // MARK: - Dictionary Request Methods
    
    func putDictionary<T: Decodable>(_ url: String, body: [String: Any], decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        var request = try await createRequest(url: url, method: "PUT", requiresAuth: requiresAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, decoder: decoder)
    }
    
    func postDictionary<T: Decodable>(_ url: String, body: [String: Any], decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        var request = try await createRequest(url: url, method: "POST", requiresAuth: requiresAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, decoder: decoder)
    }
    
    func patchDictionary<T: Decodable>(_ url: String, body: [String: Any], decoder: JSONDecoder = JSONDecoder(), requiresAuth: Bool = true) async throws -> T {
        var request = try await createRequest(url: url, method: "PATCH", requiresAuth: requiresAuth)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, decoder: decoder)
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            try await interceptorManager.processResponse(httpResponse, data: data)
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
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
        mimeType: String,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try await createRequest(url: url, method: "POST", requiresAuth: true)
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
        
        return try await performRequest(request, decoder: decoder)
    }
    
    // 添加文件上传方法
    func upload<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.serverError(errorResponse?.message ?? "请求错误")
        case 500...599:
            throw NetworkError.serverError("服务器错误")
        default:
            throw NetworkError.unknown
        }
    }
    
    // 添加JSON数据发送方法
    func postJSON<T: Encodable, R: Decodable>(_ urlString: String, body: T, decoder: JSONDecoder? = nil) async throws -> R {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw NetworkError.encodingError(error)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = decoder ?? JSONDecoder()
                return try decoder.decode(R.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.serverError(errorResponse?.message ?? "请求错误")
        case 500...599:
            throw NetworkError.serverError("服务器错误")
        default:
            throw NetworkError.unknown
        }
    }
    
    /// 上传 MultipartFormData
    /// - Parameters:
    ///   - url: 请求URL
    ///   - formData: MultipartFormData 对象
    /// - Returns: 解码后的响应数据
    func uploadFormData<T: Decodable>(_ url: String, _ formData: MultipartFormData) async throws -> T {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
        
        // 添加认证头
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = formData.createBody()
        
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
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.message)
            }
            throw NetworkError.serverError("请求错误")
        case 500...599:
            throw NetworkError.serverError("服务器错误")
        default:
            throw NetworkError.unknown
        }
    }
} 
