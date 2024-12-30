import Foundation

class MultipartFormData {
    private var boundary: String
    private var bodyParts: [BodyPart] = []
    
    struct BodyPart {
        let data: Data
        let name: String
        let fileName: String?
        let mimeType: String?
    }
    
    init() {
        self.boundary = "Boundary-\(UUID().uuidString)"
    }
    
    func append(_ data: Data, withName name: String, fileName: String? = nil, mimeType: String? = nil) {
        let bodyPart = BodyPart(data: data, name: name, fileName: fileName, mimeType: mimeType)
        bodyParts.append(bodyPart)
    }
    
    func createBody() -> Data {
        var body = Data()
        
        for part in bodyParts {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let fileName = part.fileName {
                disposition += "; filename=\"\(fileName)\""
            }
            body.append("\(disposition)\r\n".data(using: .utf8)!)
            
            if let mimeType = part.mimeType {
                body.append("Content-Type: \(mimeType)\r\n".data(using: .utf8)!)
            }
            
            body.append("\r\n".data(using: .utf8)!)
            body.append(part.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
    
    var contentType: String {
        return "multipart/form-data; boundary=\(boundary)"
    }
} 