import SwiftUI

struct TemplateDetailView: View {
    let template: TemplateFile
    @EnvironmentObject private var router: NavigationRouter
    @State private var showingDeleteAlert = false
    @State private var coverImage: UIImage?
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 封面图片
                    coverImageSection
                    
                    // 时间轴预览
                    TimelinePreviewView(
                        timelineItems: template.template.timelineItems.map { item in
                            TimelineItemData(
                                script: item.script,
                                imageURL: getImageURL(for: item),
                                timestamp: item.timestamp
                            )
                        },
                        totalDuration: template.template.totalDuration
                    )
                    
                    // 录音记录列表
                    if !template.records.isEmpty {
                        recordListSection
                    }
                    
                    // 底部留空，确保内容不被录音按钮遮挡
                    Color.clear.frame(height: 80)
                }
                .padding()
            }
            
            // 固定在底部的录音按钮
            VStack {
                Spacer()
                recordButton
            }
        }
        .navigationTitle(template.template.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCoverImage()
        }
        .onDisappear {
            // 清理图片缓存
            coverImage = nil
        }
        .alert("删除录音", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("确定要删除这条录音吗？")
        }
    }
    
    private var coverImageSection: some View {
        Group {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
            }
        }
    }
    
    private var recordListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("录音记录")
                .font(.headline)
            
            ForEach(template.records) { record in
                NavigationLink(value: Route.recordDetail(template.metadata.id, record)) {
                    RecordRow(record: record)
                }
            }
        }
    }
    
    private var recordButton: some View {
        Button(action: {
            router.navigate(to: .recording(template))
        }) {
            HStack {
                Image(systemName: "record.circle.fill")
                Text("开始表演")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .clipShape(Capsule())
            .padding(.horizontal)
            .shadow(radius: 4)
        }
        .padding(.bottom)
    }
    
    private func loadCoverImage() {
        guard let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) else {
            return
        }
        
        let imageURL = baseURL.appendingPathComponent(template.template.coverImage)
        
        // 在后台线程加载图片
        DispatchQueue.global(qos: .userInitiated).async {
            if let imageData = try? Data(contentsOf: imageURL),
               let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.coverImage = image
                }
            }
        }
    }
    
    private func getImageURL(for item: TemplateData.TimelineItem) -> URL? {
        guard !item.image.isEmpty,
              let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) else {
            return nil
        }
        return baseURL.appendingPathComponent(item.image)
    }
    
    private func deleteRecord() {
        // TODO: 删除录音的实现
    }
}

struct RecordRow: View {
    let record: RecordData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.createdAt, style: .date)
                    .font(.subheadline)
                Text(formatDuration(record.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)分\(String(format: "%02d", seconds))秒"
        } else {
            return "\(seconds)秒"
        }
    }
} 