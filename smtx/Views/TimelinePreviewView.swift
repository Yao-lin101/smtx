import SwiftUI

struct TimelinePreviewView: View {
    let timelineItems: [TimelineItemData]
    let totalDuration: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间轴预览")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !timelineItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(timelineItems.sorted(by: { $0.timestamp < $1.timestamp })) { item in
                            TimelinePreviewItem(item: item)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图片预览
            if let imageData = item.imageData,
               let image = UIImage(data: imageData) {
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