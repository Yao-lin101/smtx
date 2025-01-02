import SwiftUI

struct TimelinePlayerView: View {
    let currentTime: Double
    let totalDuration: Double
    let currentItem: TimelineItemData?
    let isPreviewMode: Bool
    let onSeek: ((Double) -> Void)?
    let onDragStart: (() -> Void)?
    @State private var currentImage: UIImage?
    @State private var isDragging = false
    @State private var dragTime: Double = 0
    
    private var progress: Double {
        totalDuration > 0 ? (isDragging ? dragTime : currentTime) / totalDuration : 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 图片区域
            ZStack {
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                }
            }
            .frame(height: 200)
            
            // 台词区域
            ZStack {
                if let script = currentItem?.script {
                    Text(script)
                        .font(.body)
                        .multilineTextAlignment(.center)
                } else {
                    Text("无台词")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 60)
            .padding(.horizontal)
            
            // 进度条
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景条
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)
                        
                        // 进度条
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(isDragging ? nil : .linear(duration: 0.1), value: progress)
                        
                        // 拖动手柄
                        if isPreviewMode {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                                .shadow(radius: 2)
                                .position(x: geometry.size.width * progress, y: 2)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if !isDragging {
                                                isDragging = true
                                                onDragStart?()
                                            }
                                            let ratio = max(0, min(1, value.location.x / geometry.size.width))
                                            dragTime = ratio * totalDuration
                                        }
                                        .onEnded { _ in
                                            isDragging = false
                                            onSeek?(dragTime)
                                        }
                                )
                        }
                    }
                }
                .frame(height: 4)
                
                // 时间显示
                HStack {
                    Text(formatTime(isDragging ? dragTime : currentTime))
                    Spacer()
                    Text(formatTime(totalDuration))
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .onChange(of: currentItem) { item in
            // 如果当前项目有图片，则更新图片
            if let imageData = item?.imageData,
               let image = UIImage(data: imageData) {
                currentImage = image
            }
            // 如果当前项目没有图片，保持现有图片不变
        }
        .onChange(of: currentTime) { _ in
            if isDragging {
                isDragging = false
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 