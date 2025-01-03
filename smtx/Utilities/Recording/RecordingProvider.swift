import Foundation
import CoreData

class LocalTimelineProvider: TimelineProvider {
    private let template: Template
    private var sortedItems: [TimelineItem] = []
    
    init(template: Template) {
        self.template = template
        if let items = template.timelineItems?.allObjects as? [TimelineItem] {
            self.sortedItems = items.sorted { $0.timestamp < $1.timestamp }
        }
    }
    
    var totalDuration: Double {
        template.totalDuration
    }
    
    var timelineItems: [TimelineDisplayData] {
        var lastImage: Data? = nil
        return sortedItems.map { item in
            if let image = item.image {
                lastImage = image
            }
            return TimelineDisplayData(
                script: item.script ?? "",
                imageData: item.image,
                lastImageData: lastImage,
                provider: self,
                timestamp: item.timestamp
            )
        }
    }
    
    func getItemAt(timestamp: Double) -> TimelineDisplayData? {
        guard let currentIndex = sortedItems.lastIndex(where: { $0.timestamp <= timestamp }) else {
            return nil
        }
        
        var lastImageIndex = currentIndex
        while lastImageIndex >= 0 {
            if sortedItems[lastImageIndex].image != nil {
                break
            }
            lastImageIndex -= 1
        }
        
        let lastImage = lastImageIndex >= 0 ? sortedItems[lastImageIndex].image : nil
        let currentItem = sortedItems[currentIndex]
        
        return TimelineDisplayData(
            script: currentItem.script ?? "",
            imageData: currentItem.image,
            lastImageData: lastImage,
            provider: self,
            timestamp: currentItem.timestamp
        )
    }
} 

class CloudTimelineProvider: TimelineProvider {
    private let timelineData: TimelineData
    private let timelineImages: [String: Data]
    private var items: [TimelineDisplayData] = []
    
    var totalDuration: Double {
        timelineData.duration
    }
    
    var timelineItems: [TimelineDisplayData] {
        items.sorted { $0.timestamp < $1.timestamp }
    }
    
    init(timelineData: TimelineData, timelineImages: [String: Data]) {
        self.timelineData = timelineData
        self.timelineImages = timelineImages
        
        // 构建时间轴项目
        var lastImage: Data? = nil
        self.items = timelineData.events.map { event in
            if let imageName = event.image,
               let imageData = timelineImages[imageName] {
                lastImage = imageData
            }
            return TimelineDisplayData(
                script: event.text ?? "",
                imageData: event.image.flatMap { timelineImages[$0] },
                lastImageData: lastImage,
                provider: self,
                timestamp: event.time
            )
        }
    }
    
    func getItemAt(timestamp: Double) -> TimelineDisplayData? {
        // 找到最后一个时间戳小于等于当前时间的项目
        guard let currentIndex = timelineData.events.lastIndex(where: { $0.time <= timestamp }) else {
            return nil
        }
        
        // 找到最近的一个有图片的项目
        var lastImageData: Data? = nil
        for i in (0...currentIndex).reversed() {
            if let imageName = timelineData.events[i].image,
               let imageData = timelineImages[imageName] {
                lastImageData = imageData
                break
            }
        }
        
        let event = timelineData.events[currentIndex]
        return TimelineDisplayData(
            script: event.text ?? "",
            imageData: event.image.flatMap { timelineImages[$0] },
            lastImageData: lastImageData,
            provider: self,
            timestamp: event.time
        )
    }
}