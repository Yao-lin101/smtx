import SwiftUI
import CoreData

struct TemplateDetailView: View {
    let templateId: String
    @EnvironmentObject private var router: NavigationRouter
    @State private var template: Template?
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 封面图片
                    if let template = template {
                        coverImageSection(template)
                        
                        // 时间轴预览
                        if let items = template.timelineItems?.allObjects as? [TimelineItem],
                           !items.isEmpty {
                            TimelinePreviewView(
                                timelineItems: items.map { item in
                                    TimelineItemData(
                                        script: item.script ?? "",
                                        imageData: item.image,
                                        timestamp: item.timestamp,
                                        createdAt: item.createdAt ?? Date()
                                    )
                                },
                                totalDuration: template.totalDuration
                            )
                        }
                        
                        // 录音记录列表
                        if let records = template.records?.allObjects as? [Record],
                           !records.isEmpty {
                            recordListSection(records)
                        }
                        
                        // 底部留空，确保内容不被录音按钮遮挡
                        Color.clear.frame(height: 80)
                    } else {
                        ProgressView()
                    }
                }
                .padding()
            }
            
            // 固定在底部的录音按钮
            if let template = template {
                VStack {
                    Spacer()
                    recordButton(template)
                }
            }
        }
        .navigationTitle(template?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTemplate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingFinished)) { notification in
            if let updatedTemplate = notification.object as? Template,
               updatedTemplate.id == templateId {
                template = updatedTemplate
            }
        }
    }
    
    private func coverImageSection(_ template: Template) -> some View {
        Group {
            if let imageData = template.coverImage,
               let image = UIImage(data: imageData) {
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
    
    private func recordListSection(_ records: [Record]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("录音记录")
                .font(.headline)
                .padding(.horizontal)
            
            List {
                ForEach(records.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }, id: \.id) { record in
                    RecordRow(record: record)
                        .onTapGesture {
                            if let recordId = record.id {
                                router.navigate(to: .recording(templateId, recordId))
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(record)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(records.count) * 88)
        }
    }
    
    private func recordButton(_ template: Template) -> some View {
        Button(action: {
            router.navigate(to: .recording(templateId, nil))
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
    
    private func loadTemplate() {
        do {
            template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
        } catch {
            print("Error loading template: \(error)")
        }
    }
    
    private func deleteRecord(_ record: Record) {
        do {
            try TemplateStorage.shared.deleteRecord(record)
            // 重新加载模板数据以更新列表
            loadTemplate()
            print("✅ Record deleted successfully")
        } catch {
            print("❌ Failed to delete record: \(error)")
        }
    }
}

// MARK: - Helper Views
struct TimelineItemRow: View {
    let item: TimelineItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = item.image,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let script = item.script {
                    Text(script)
                        .font(.body)
                        .lineLimit(2)
                }
                Text(String(format: "%.1f秒", item.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
    }
}

struct RecordRow: View {
    let record: Record
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.createdAt ?? Date(), style: .date)
                Text(String(format: "%.1f秒", record.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
} 