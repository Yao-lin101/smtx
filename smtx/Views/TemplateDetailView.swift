import SwiftUI

struct TemplateDetailView: View {
    let template: TemplateFile
    @EnvironmentObject private var router: NavigationRouter
    @State private var coverImage: UIImage?
    @State private var currentTemplate: TemplateFile
    
    init(template: TemplateFile) {
        self.template = template
        self._currentTemplate = State(initialValue: template)
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 封面图片
                    coverImageSection
                    
                    // 时间轴预览
                    TimelinePreviewView(
                        timelineItems: currentTemplate.template.timelineItems.map { item in
                            TimelineItemData(
                                script: item.script,
                                imageURL: getImageURL(for: item),
                                timestamp: item.timestamp
                            )
                        },
                        totalDuration: currentTemplate.template.totalDuration
                    )
                    
                    // 录音记录列表
                    if !currentTemplate.records.isEmpty {
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
        .navigationTitle(currentTemplate.template.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCoverImage()
        }
        .onDisappear {
            // 清理图片缓存
            coverImage = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingFinished)) { notification in
            if let updatedTemplate = notification.object as? TemplateFile {
                currentTemplate = updatedTemplate
                print("✅ Template updated from notification")
            } else {
                // 如果通知中没有模板数据，则重新加载
                do {
                    currentTemplate = try TemplateStorage.shared.loadTemplate(templateId: template.metadata.id)
                    print("✅ Template reloaded from storage")
                } catch {
                    print("❌ Failed to reload template after recording: \(error)")
                }
            }
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
                .padding(.horizontal)
            
            List {
                ForEach(Array(currentTemplate.records.enumerated()), id: \.element.id) { index, record in
                    NavigationLink(value: Route.recordDetail(currentTemplate.metadata.id, record)) {
                        RecordRow(record: record)
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteRecord(at: index)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(currentTemplate.records.count) * 60 + 16)
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
    
    private func deleteRecord(at index: Int) {
        do {
            // 获取模板目录
            guard let templateDir = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) else {
                print("❌ Failed to get template directory")
                return
            }
            
            // 尝试删除录音文件（如果存在）
            let audioURL = templateDir.appendingPathComponent(currentTemplate.records[index].audioFile)
            try? FileManager.default.removeItem(at: audioURL)
            
            // 从模板数据中删除记录
            var updatedTemplate = currentTemplate
            updatedTemplate.records.remove(at: index)
            try TemplateStorage.shared.saveTemplate(updatedTemplate)
            
            // 重新从磁盘加载模板数据
            currentTemplate = try TemplateStorage.shared.loadTemplate(templateId: template.metadata.id)
            print("✅ Record removed from template")
        } catch {
            print("❌ Failed to update template: \(error)")
        }
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
        .padding(.horizontal)
        .frame(height: 52)
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