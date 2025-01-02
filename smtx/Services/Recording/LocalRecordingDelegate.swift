import Foundation
import CoreData

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