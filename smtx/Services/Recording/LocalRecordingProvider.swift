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
    
    var timelineItems: [TimelineItemData] {
        sortedItems.map { item in
            TimelineItemData(
                script: item.script ?? "",
                imageData: item.image,
                timestamp: item.timestamp,
                createdAt: item.createdAt ?? Date(),
                updatedAt: item.updatedAt ?? Date(),
                imageUpdatedAt: item.imageUpdatedAt
            )
        }
    }
    
    func getItemAt(timestamp: Double) -> TimelineItemData? {
        guard let item = sortedItems.first(where: { Int($0.timestamp) == Int(timestamp) }) else {
            return nil
        }
        
        return TimelineItemData(
            script: item.script ?? "",
            imageData: item.image,
            timestamp: item.timestamp,
            createdAt: item.createdAt ?? Date(),
            updatedAt: item.updatedAt ?? Date(),
            imageUpdatedAt: item.imageUpdatedAt
        )
    }
} 