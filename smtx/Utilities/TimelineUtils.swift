import Foundation

enum TimelineError: Error {
    case invalidTimelineItems
}

class TimelineUtils {
    /// 生成时间轴数据
    /// - Parameters:
    ///   - items: 时间轴项目列表
    ///   - duration: 总时长
    ///   - imageNames: 时间戳到图片名称的映射（可选）
    ///   - includeImages: 是否在返回值中包含图片数据
    /// - Returns: 时间轴数据和图片字典
    static func generateTimelineData(
        from items: [TimelineItem]?,
        duration: TimeInterval,
        imageNames: [Double: String]? = nil,
        includeImages: Bool = true
    ) throws -> (timelineData: Data, images: [String: Data]) {
        var timelineData = Data()
        var timelineImages: [String: Data] = [:]
        
        if let items = items {
            var timelineJson: [String: Any] = [:]
            var images: [String] = []
            var events: [[String: Any]] = []
            
            for item in items {
                var event: [String: Any] = [
                    "time": item.timestamp
                ]
                
                // 添加文本内容
                if let script = item.script, !script.isEmpty {
                    event["text"] = script
                }
                
                // 处理图片
                if let imageData = item.image {
                    // 如果提供了图片名称映射，使用映射的名称
                    let imageName: String
                    if let providedName = imageNames?[item.timestamp] {
                        // 使用提供的名称（基于imageUpdatedAt的时间戳）
                        imageName = providedName
                        print("📝 Using image name for timestamp \(item.timestamp): \(imageName)")
                    } else if let imageDate = item.imageUpdatedAt {
                        // 使用imageUpdatedAt时间戳生成名称
                        let timestamp = Int64(imageDate.timeIntervalSince1970 * 1000)
                        imageName = "img_\(timestamp).jpg"
                        print("📝 Generated image name from imageUpdatedAt for timestamp \(item.timestamp): \(imageName)")
                    } else {
                        // 这种情况不应该发生，因为有图片就应该有imageUpdatedAt
                        print("⚠️ Warning: Image exists but no imageUpdatedAt timestamp for timestamp \(item.timestamp)")
                        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
                        imageName = "img_\(timestamp).jpg"
                        print("📝 Generated fallback image name for timestamp \(item.timestamp): \(imageName)")
                    }
                    
                    // 只有在需要包含图片时才添加到返回值中
                    if includeImages {
                        timelineImages[imageName] = imageData
                        print("📝 Added image data for \(imageName)")
                    }
                    images.append(imageName)
                    event["image"] = imageName
                }
                
                // 无论是否有图片，都添加事件
                events.append(event)
            }
            
            timelineJson["duration"] = duration
            timelineJson["images"] = images
            timelineJson["events"] = events
            timelineData = try JSONSerialization.data(withJSONObject: timelineJson)
            
            // 打印生成的 JSON 数据
            if let jsonString = String(data: timelineData, encoding: .utf8) {
                print("📝 Generated timeline JSON: \(jsonString)")
            }
        }
        
        return (timelineData, timelineImages)
    }
} 