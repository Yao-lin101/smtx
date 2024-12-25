import SwiftUI

struct TimelinePreviewView: View {
    let timelineItems: [TimelineItemData]
    let totalDuration: Double
    
    // 添加一个方法来获取指定时间点的图片
    private func getImageForItem(_ currentItem: TimelineItemData) -> UIImage? {
        // 如果当前项目有图片，直接返回
        if let imageData = currentItem.imageData,
           let image = UIImage(data: imageData) {
            return image
        }
        
        // 如果当前项目没有图片，查找前面最近的带图片的项目
        let previousItems = timelineItems
            .filter { $0.timestamp < currentItem.timestamp }
            .sorted { $0.timestamp > $1.timestamp }
        
        if let previousItemWithImage = previousItems.first(where: { $0.imageData != nil }),
           let imageData = previousItemWithImage.imageData,
           let image = UIImage(data: imageData) {
            return image
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间轴预览")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !timelineItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(timelineItems.sorted(by: { $0.timestamp < $1.timestamp })) { item in
                            TimelinePreviewItem(
                                item: item,
                                image: getImageForItem(item)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 140)
            }
        }
    }
}

private struct TimelinePreviewItem: View {
    let item: TimelineItemData
    let image: UIImage? // 修改为直接接收 UIImage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图片预览
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 68) // 16:9 比例
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 68)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }
            
            // 台词和时间点预览
            VStack(alignment: .leading, spacing: 2) {
                if !item.script.isEmpty {
                    Text(item.script)
                        .font(.caption)
                        .lineLimit(2)
                        .frame(width: 120, alignment: .leading)
                }
                Text(formatTimestamp(item.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .center)
            }
        }
    }
    
    private func formatTimestamp(_ timestamp: Double) -> String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
} 