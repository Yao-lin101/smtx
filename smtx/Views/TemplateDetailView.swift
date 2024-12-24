import SwiftUI

struct TemplateDetailView: View {
    let template: TemplateFile
    @EnvironmentObject private var router: NavigationRouter
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            // 基本信息部分
            Section("基本信息") {
                templateInfoView
            }
            
            // 时间轴部分
            Section("时间轴") {
                timelineListView
            }
            
            // 录音记录部分
            if !template.records.isEmpty {
                Section("录音记录") {
                    recordListView
                }
            }
        }
        .navigationTitle(template.template.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                startRecordingButton
            }
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
    
    // MARK: - Subviews
    
    private var templateInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("创建时间：\(template.metadata.createdAt, style: .date)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("总时长：\(String(format: "%.1f", template.template.totalDuration))秒")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var timelineListView: some View {
        ForEach(template.template.timelineItems, id: \.id) { item in
            TimelineItemView(templateId: template.metadata.id, item: item)
        }
    }
    
    private var recordListView: some View {
        ForEach(template.records) { record in
            NavigationLink(value: Route.recordDetail(template.metadata.id, record)) {
                RecordRow(record: record)
            }
        }
    }
    
    private var startRecordingButton: some View {
        Button(action: {
            router.navigate(to: .recording(template))
        }) {
            Image(systemName: "record.circle")
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteRecord() {
        // 删除录音的实现
    }
}

// MARK: - Supporting Views

struct TimelineItemView: View {
    let templateId: String
    let item: TemplateData.TimelineItem
    @State private var image: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 150)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }
            
            if !item.script.isEmpty {
                Text(item.script)
                    .font(.body)
            }
            
            Text(String(format: "时间点：%.1f秒", item.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: templateId),
              let imageData = try? Data(contentsOf: baseURL.appendingPathComponent(item.image)),
              let uiImage = UIImage(data: imageData) else {
            return
        }
        image = uiImage
    }
}

struct RecordRow: View {
    let record: RecordData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.createdAt, style: .date)
                .font(.subheadline)
            
            Text(String(format: "时长：%.1f秒", record.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
} 