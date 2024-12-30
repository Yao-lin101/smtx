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
            
            // 使用计数器来生成图片名称
            var imageCounter = 1
            
            for item in items {
                var event: [String: Any] = [
                    "time": item.timestamp
                ]
                
                // 添加文本内容
                if let script = item.script, !script.isEmpty {
                    event["text"] = script
                }
                
                // 如果有图片，使用简单的数字序号命名
                if let imageData = item.image {
                    let imageName = String(format: "%03d.jpg", imageCounter)
                    timelineImages[imageName] = imageData
                    images.append(imageName)
                    event["image"] = imageName
                    imageCounter += 1
                }
                
                // 无论是否有图片，都添加事件
                events.append(event)
            }
            
            timelineJson["duration"] = duration
            timelineJson["images"] = images
            timelineJson["events"] = events
            timelineData = try JSONSerialization.data(withJSONObject: timelineJson)
        }
        
        return (timelineData, timelineImages)
    }
} 