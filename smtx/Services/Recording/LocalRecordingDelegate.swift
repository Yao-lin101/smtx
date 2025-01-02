import Foundation
import CoreData

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
    @Environment(\.dismiss) private var dismiss
    
    init(templateUid: String) {
        self.templateUid = templateUid
    }
    
    func saveRecording(audioData: Data, duration: Double) async throws -> String {
        // 保存到缓存
        let recordId = UUID().uuidString
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(recordId).m4a")
        try audioData.write(to: cacheURL)
        return recordId
    }
    
    func deleteRecording(id: String) async throws {
        // 从缓存中删除
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(id).m4a")
        try? FileManager.default.removeItem(at: cacheURL)
    }
    
    func loadRecording(id: String) async throws -> (Data, Double)? {
        // 从缓存中加载
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_recording_\(id).m4a")
        guard let audioData = try? Data(contentsOf: cacheURL) else { return nil }
        
        // 获取音频时长
        let player = try AVAudioPlayer(data: audioData)
        return (audioData, player.duration)
    }
}