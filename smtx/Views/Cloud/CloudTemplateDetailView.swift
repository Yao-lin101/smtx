import SwiftUI

struct CloudTemplateDetailView: View {
    let uid: String
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            if let template = viewModel.templates.first {
                VStack(spacing: 16) {
                    // 封面图
                    AsyncImage(url: URL(string: template.coverThumbnail)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // 标题和作者
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.title)
                            .font(.title2)
                            .bold()
                        
                        HStack {
                            Text("作者：\(template.authorName ?? "未知")")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(template.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 标签
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(template.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 点赞和收藏按钮
                    HStack(spacing: 24) {
                        Spacer()
                        
                        Button {
                            viewModel.likeTemplate(uid: template.uid)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: template.isLiked ?? false ? "heart.fill" : "heart")
                                    .font(.title2)
                                Text("\(template.likesCount ?? 0)")
                                    .font(.caption)
                            }
                            .foregroundColor(template.isLiked ?? false ? .red : .primary)
                        }
                        
                        Button {
                            viewModel.collectTemplate(uid: template.uid)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: template.isCollected ?? false ? "star.fill" : "star")
                                    .font(.title2)
                                Text("\(template.collectionsCount ?? 0)")
                                    .font(.caption)
                            }
                            .foregroundColor(template.isCollected ?? false ? .yellow : .primary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    // 时间轴预览
                    TimelinePreviewView(
                        timelineItems: [
                            TimelineItemData(script: "示例文本1", imageData: nil, timestamp: 1.0, createdAt: Date(), updatedAt: Date()),
                            TimelineItemData(script: "示例文本2", imageData: nil, timestamp: 2.5, createdAt: Date(), updatedAt: Date()),
                            TimelineItemData(script: "示例文本3", imageData: nil, timestamp: 4.0, createdAt: Date(), updatedAt: Date())
                        ],
                        totalDuration: Double(template.duration)
                    )
                    .padding(.horizontal)
                    
                    // 标签切换
                    Picker("内容", selection: $selectedTab) {
                        Text("录音").tag(0)
                        Text("评论").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // 录音和评论列表
                    Group {
                        if selectedTab == 0 {
                            // 录音列表
                            VStack {
                                ForEach(0..<3) { _ in
                                    RecordingRow()
                                }
                            }
                        } else {
                            // 评论列表
                            VStack {
                                ForEach(0..<3) { _ in
                                    CommentRow()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadTemplate(uid)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct RecordingRow: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("2024年1月1日")
                Text("1:30")
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
    }
}

struct CommentRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("用户名")
                    .font(.headline)
                
                Spacer()
                
                Text("1分钟前")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("这是一条示例评论")
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        CloudTemplateDetailView(uid: "test")
            .environmentObject(NavigationRouter())
    }
} 
