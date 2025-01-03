import Foundation
import CoreData
import AVFoundation

enum RecordingError: LocalizedError {
    case invalidTemplate
    case recordNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidTemplate:
            return "无效的模板"
        case .recordNotFound:
            return "找不到录音记录"
        }
    }
} 

class LocalRecordingDelegate: RecordingDelegate {
    private let template: Template
    private let storage = TemplateStorage.shared
    
    init(template: Template) {
        self.template = template
    }
    
    func saveRecording(audioData: Data, duration: Double) async throws -> String {
        guard let templateId = template.id else {
            throw RecordingError.invalidTemplate
        }
        
        let recordId = try storage.saveRecord(
            templateId: templateId,
            duration: duration,
            audioData: audioData
        )
        
        // 在主线程发送录音完成通知
        await MainActor.run {
            NotificationCenter.default.post(
                name: .recordingFinished,
                object: nil,
                userInfo: ["templateId": templateId]
            )
        }
        
        return recordId
    }
    
    func deleteRecording(id: String) async throws {
        guard let records = template.records?.allObjects as? [Record],
              let record = records.first(where: { $0.id == id }) else {
            throw RecordingError.recordNotFound
        }
        
        try storage.deleteRecord(record)
        
        // 在主线程发送录音更新通知
        if let templateId = template.id {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .recordingFinished,
                    object: nil,
                    userInfo: ["templateId": templateId]
                )
            }
        }
    }
    
    func loadRecording(id: String) async throws -> (Data, Double)? {
        guard let records = template.records?.allObjects as? [Record],
              let record = records.first(where: { $0.id == id }),
              let audioData = record.audioData else {
            return nil
        }
        
        return (audioData, record.duration)
    }
}

class CloudRecordingDelegate: RecordingDelegate {
    private let templateUid: String
    private var _recordingData: (audioData: Data, duration: Double)?
    private let cloudTemplateService: CloudTemplateService
    private let cacheManager = RecordingCacheManager.shared
    private let recordingUrl: String?
    
    var recordingData: (Data, Double)? {
        _recordingData
    }
    
    init(templateUid: String, recordingUrl: String? = nil, cloudTemplateService: CloudTemplateService = .shared) {
        self.templateUid = templateUid
        self.recordingUrl = recordingUrl
        self.cloudTemplateService = cloudTemplateService
    }
    
    func setRecordingData(audioData: Data, duration: Double) {
        _recordingData = (audioData, duration)
    }
    
    func saveRecording(audioData: Data, duration: Double) async throws -> String {
        // 保存到缓存
        let recordId = UUID().uuidString
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(recordId).m4a")
        try audioData.write(to: cacheURL)
        // 保存录音数据以供上传使用
        _recordingData = (audioData, duration)
        return recordId
    }
    
    func deleteRecording(id: String) async throws {
        // 从缓存中删除
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(id).m4a")
        try? FileManager.default.removeItem(at: cacheURL)
        _recordingData = nil
    }
    
    func loadRecording(id: String) async throws -> (Data, Double)? {
        // 如果已经有缓存的数据，直接返回
        if let recordingData = _recordingData {
            return recordingData
        }
        
        // 否则尝试从 URL 加载
        if let recordingUrl = recordingUrl,
           let url = URL(string: recordingUrl) {
            return try await cacheManager.loadRecording(from: url)
        }
        
        return nil
    }
    
    func uploadRecording(forceOverride: Bool = false) async throws -> String {
        guard let (audioData, duration) = _recordingData else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有可上传的录音"])
        }
        
        do {
            return try await cloudTemplateService.uploadRecording(
                templateUid: templateUid,
                audioData: audioData,
                duration: duration,
                forceOverride: forceOverride
            )
        } catch let error as NetworkError {
            switch error {
            case .serverError(let message):
                if message.contains("409") || message.contains("已存在录音") {
                    throw NSError(
                        domain: "NetworkError",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "您已经上传过录音"]
                    )
                }
                throw error
            default:
                throw error
            }
        }
    }
    
    func uploadRecording() async throws -> String {
        return try await uploadRecording(forceOverride: false)
    }
}
