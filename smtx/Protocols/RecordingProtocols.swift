import Foundation
import SwiftUI

protocol TimelineProvider {
    var totalDuration: Double { get }
    var timelineItems: [TimelineItemData] { get }
    func getItemAt(timestamp: Double) -> TimelineItemData?
}

protocol RecordingDelegate {
    func saveRecording(audioData: Data, duration: Double) async throws -> String
    func deleteRecording(id: String) async throws
    func loadRecording(id: String) async throws -> (Data, Double)?
} 

// 时间轴项目数据模型
struct TimelineItemData: Identifiable, Equatable, Hashable {
    let id = UUID()
    var script: String
    var imageData: Data?
    var timestamp: Double
    var createdAt: Date
    var updatedAt: Date
    var imageUpdatedAt: Date?
    
    // 实现 Equatable 协议
    static func == (lhs: TimelineItemData, rhs: TimelineItemData) -> Bool {
        return lhs.script == rhs.script &&
               lhs.imageData == rhs.imageData &&
               lhs.timestamp == rhs.timestamp &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.imageUpdatedAt == rhs.imageUpdatedAt
    }
    
    // 实现 Hashable 协议
    func hash(into hasher: inout Hasher) {
        hasher.combine(script)
        hasher.combine(imageData)
        hasher.combine(timestamp)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(imageUpdatedAt)
    }
}
