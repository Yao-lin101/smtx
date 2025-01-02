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
    private var recordingData: (audioData: Data, duration: Double)?
    private let cloudTemplateService: CloudTemplateService
    
    init(templateUid: String, cloudTemplateService: CloudTemplateService = .shared) {
        self.templateUid = templateUid
        self.cloudTemplateService = cloudTemplateService
    }
    
    func saveRecording(audioData: Data, duration: Double) async throws -> String {
        // 保存到缓存
        let recordId = UUID().uuidString
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(recordId).m4a")
        try audioData.write(to: cacheURL)
        // 保存录音数据以供上传使用
        recordingData = (audioData, duration)
        return recordId
    }
    
    func deleteRecording(id: String) async throws {
        // 从缓存中删除
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(id).m4a")
        try? FileManager.default.removeItem(at: cacheURL)
        recordingData = nil
    }
    
    func loadRecording(id: String) async throws -> (Data, Double)? {
        // 从缓存中加载
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(id).m4a")
        guard let audioData = try? Data(contentsOf: cacheURL) else { return nil }
        
        // 获取音频时长
        let player = try AVAudioPlayer(data: audioData)
        return (audioData, player.duration)
    }
    
    func uploadRecording() async throws -> String {
        guard let (audioData, duration) = recordingData else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有可上传的录音"])
        }
        
        return try await cloudTemplateService.uploadRecording(templateUid: templateUid, audioData: audioData, duration: duration)
    }
}
