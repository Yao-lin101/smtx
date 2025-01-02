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