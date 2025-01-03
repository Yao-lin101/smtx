import Foundation
import ObjectiveC

class NetworkService {
    static let shared = NetworkService()
    private let session = URLSession.shared
    private let uploadSession: URLSession
    private let tokenManager = TokenManager.shared
    private let interceptorManager = NetworkInterceptorManager.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        uploadSession = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
    }
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(_ urlString: String, decoder: JSONDecoder? = nil) async throws -> T {
        print("📡 GET 请求: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ 无效的 URL: \(urlString)")
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 添加认证令牌")
        }
        
        do {
            print("📥 开始网络请求")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 非 HTTP 响应")
                throw NetworkError.invalidResponse
            }
            
            print("📦 收到响应: HTTP \(httpResponse.statusCode)")
            
            // 打印响应数据用于调试
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 响应数据: \(jsonString)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    print("🔄 开始解码数据")
                    let decoder = decoder ?? DateDecoder.decoder
                    print("🔑 解码器配置:")
                    print("  - keyDecodingStrategy: \(String(describing: decoder.keyDecodingStrategy))")
                    print("  - dateDecodingStrategy: \(String(describing: decoder.dateDecodingStrategy))")
                    let decodedData = try decoder.decode(T.self, from: data)
                    print("✅ 数据解码成功")
                    print("📦 解码类型: \(T.self)")
                    return decodedData
                } catch let error {
                    print("❌ 解码错误: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("  - 缺失键: \(key)")
                            print("  - 上下文: \(context.debugDescription)")
                            print("  - 编码路径: \(context.codingPath.map { $0.stringValue })")
                        case .typeMismatch(let type, let context):
                            print("  - 类型不匹配: 期望 \(type)")
                            print("  - 上下文: \(context.debugDescription)")
                        default:
                            print("  - 其他解码错误: \(decodingError)")
                        }
                    }
                    throw NetworkError.decodingError(error)
                }
            case 401:
                print("🔒 未授权错误 (401)")
                throw NetworkError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    print("⚠️ 客户端错误: \(errorResponse.message)")
                    throw NetworkError.serverError(errorResponse.message)
                }
                print("⚠️ 未知客户端错误")
                throw NetworkError.serverError("请求失败")
            case 500...599:
                print("⚠️ 服务器错误")
                throw NetworkError.serverError("服务器错误")
            default:
                print("❓ 未知状态码: \(httpResponse.statusCode)")
                throw NetworkError.serverError("未知错误")
            }
        } catch {
            if let networkError = error as? NetworkError {
                throw networkError
            }
            print("🌐 网络请求错误: \(error.localizedDescription)")
            throw NetworkError.networkError(error)
        }
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
    func uploadFormData<T: Decodable>(_ url: String, _ formData: MultipartFormData, progressHandler: ((Double) -> Void)? = nil) async throws -> T {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
        
        // 添加认证头
        if let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = formData.createBody()
        
        if let progressHandler = progressHandler {
            return try await withCheckedThrowingContinuation { continuation in
                let delegate = UploadProgressDelegateContinuation(
                    progressHandler: progressHandler,
                    continuation: continuation
                )
                
                let config = URLSessionConfiguration.default
                let session = URLSession(configuration: config, delegate: delegate, delegateQueue: .main)
                let task = session.uploadTask(with: request, from: body)
                task.resume()
            }
        } else {
            request.httpBody = body
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
            case 409:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NSError(
                        domain: "NetworkError",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: errorResponse.message]
                    )
                }
                throw NSError(
                    domain: "NetworkError",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "您已经上传过录音"]
                )
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
    
    private func handleDecodingError(_ error: Error, data: Data) -> NetworkError {
        print("❌ 解码错误详情:")
        print("  - 错误: \(error)")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("  - 原始数据: \(jsonString)")
        }
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("  - 缺失键: \(key)")
                print("  - 上下文: \(context)")
            case .typeMismatch(let type, let context):
                print("  - 类型不匹配: 期望 \(type)")
                print("  - 上下文: \(context)")
            default:
                print("  - 其他解码错误: \(decodingError)")
            }
        }
        return NetworkError.decodingError(error)
    }
}

class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let progressHandler: (Double) -> Void
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progressHandler(progress)
    }
}

class UploadProgressDelegateContinuation<T: Decodable>: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    private let continuation: CheckedContinuation<T, Error>
    private let progressHandler: (Double) -> Void
    private var receivedData = Data()
    
    init(progressHandler: @escaping (Double) -> Void, continuation: CheckedContinuation<T, Error>) {
        self.progressHandler = progressHandler
        self.continuation = continuation
        super.init()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.progressHandler(progress)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation.resume(throwing: NetworkError.networkError(error))
            return
        }
        
        guard let httpResponse = task.response as? HTTPURLResponse else {
            continuation.resume(throwing: NetworkError.invalidResponse)
            return
        }
        
        // 打印响应数据用于调试
        print("📦 收到响应: HTTP \(httpResponse.statusCode)")
        if let jsonString = String(data: receivedData, encoding: .utf8) {
            print("📄 响应数据: \(jsonString)")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                print("🔄 开始解码数据")
                print("📝 解码类型: \(T.self)")
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decoded = try decoder.decode(T.self, from: receivedData)
                print("✅ 数据解码成功")
                continuation.resume(returning: decoded)
            } catch {
                print("❌ 解码错误: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("  - 缺失键: \(key)")
                        print("  - 上下文: \(context.debugDescription)")
                        print("  - 编码路径: \(context.codingPath.map { $0.stringValue })")
                    case .typeMismatch(let type, let context):
                        print("  - 类型不匹配: 期望 \(type)")
                        print("  - 上下文: \(context.debugDescription)")
                    default:
                        print("  - 其他解码错误: \(decodingError)")
                    }
                }
                continuation.resume(throwing: NetworkError.decodingError(error))
            }
        case 401:
            continuation.resume(throwing: NetworkError.unauthorized)
        case 409:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: receivedData) {
                continuation.resume(throwing: NSError(
                    domain: "NetworkError",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: errorResponse.message]
                ))
            } else {
                continuation.resume(throwing: NSError(
                    domain: "NetworkError",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "您已经上传过录音"]
                ))
            }
        case 400...499:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: receivedData) {
                continuation.resume(throwing: NetworkError.serverError(errorResponse.message))
            } else {
                continuation.resume(throwing: NetworkError.serverError("请求错误"))
            }
        case 500...599:
            continuation.resume(throwing: NetworkError.serverError("服务器错误"))
        default:
            continuation.resume(throwing: NetworkError.unknown)
        }
    }
} 
