import Foundation

enum TimelineError: Error {
    case invalidTimelineItems
}

class TimelineUtils {
    /// 生成时间轴数据
    /// - Parameters:
    ///   - items: 时间轴项目列表
    ///   - duration: 总时长
    /// - Returns: 时间轴数据和图片字典
    static func generateTimelineData(
        from items: [TimelineItem]?,
        duration: TimeInterval
    ) throws -> (timelineData: Data, images: [String: Data]) {
        var timelineData = Data()
        var timelineImages: [String: Data] = [:]
        
        if let items = items {
            var timelineJson: [String: Any] = [:]
            var images: [String] = []
            var events: [[String: Any]] = []
            
            for item in items {
                if let imageData = item.image {
                    let imageName = UUID().uuidString + ".jpg"
                    timelineImages[imageName] = imageData
                    images.append(imageName)
                    
                    // 添加事件
                    events.append([
                        "time": item.timestamp,
                        "image": imageName
                    ])
                }
            }
            
            timelineJson["duration"] = duration
            timelineJson["images"] = images
            timelineJson["events"] = events
            timelineData = try JSONSerialization.data(withJSONObject: timelineJson)
        }
        
        return (timelineData, timelineImages)
    }
} 