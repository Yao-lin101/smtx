import SwiftUI

struct CloudTemplateDetailView: View {
    let uid: String
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var selectedTab = 0
    @State private var timelineData: TimelineData?
    @State private var timelineImages: [String: Data] = [:]
    @State private var showingRecordingSheet = false
    
    var body: some View {
        ScrollView {
            if let template = viewModel.selectedTemplate {
                VStack(spacing: 16) {
                    CoverImageView(template: template)
                    
                    VStack(spacing: 12) {
                        Text(template.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(alignment: .center) {
                            UserInfoView(template: template)
                            
                            Spacer()
                            
                            InteractionButtonsView(template: template, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let timelineData = timelineData {
                        TimelinePreviewView(
                            timelineItems: timelineData.events.map { event in
                                TimelineItemData(
                                    script: event.text ?? "",
                                    imageData: event.image.flatMap { timelineImages[$0] },
                                    timestamp: event.time,
                                    createdAt: Date(),
                                    updatedAt: Date()
                                )
                            },
                            totalDuration: timelineData.duration
                        )
                        .padding(.horizontal)
                        .onAppear {
                            print("⏱️ 显示时间轴数据:")
                            print("  - 总时长: \(timelineData.duration)")
                            print("  - 事件数量: \(timelineData.events.count)")
                            print("  - 图片数量: \(timelineData.images.count)")
                            timelineData.events.forEach { event in
                                print("  - 事件: time=\(event.time), text=\(event.text ?? "nil"), image=\(event.image ?? "nil")")
                            }
                        }
                    }
                    
                    // 根据标签页显示不同的按钮
                    Group {
                        switch selectedTab {
                        case 1: // 评论标签页
                            Button(action: {
                                // TODO: 实现评论功能
                            }) {
                                HStack {
                                    Image(systemName: "bubble.left.circle.fill")
                                        .font(.title2)
                                    Text("添加评论")
                                        .font(.headline)
                                }
                                .foregroundColor(.accentColor)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                        case 0: // 录音标签页
                            Button(action: {
                                showingRecordingSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "mic.circle.fill")
                                        .font(.title2)
                                    Text("开始录音")
                                        .font(.headline)
                                }
                                .foregroundColor(.accentColor)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                        default:
                            EmptyView()
                        }
                    }
                    
                    TabSectionView(selectedTab: $selectedTab)
                }
                .padding(.vertical)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecordingSheet) {
            recordingSheet
        }
        .onAppear {
            print("🔄 视图出现，加载模板: \(uid)")
            viewModel.loadTemplate(uid)
        }
        .onChange(of: viewModel.selectedTemplate) { template in
            if let template = template {
                print("📥 模板加载完成，准备加载时间轴")
                print("  - 时间轴文件URL: \(template.fullTimelineFile)")
                loadTimelineData(from: template.fullTimelineFile)
            }
        }
        .toastManager()
    }
    
    private func loadTimelineData(from urlString: String) {
        print("🔄 开始加载时间轴数据: \(urlString)")
        Task {
            // Try to get from cache first
            if let template = viewModel.selectedTemplate,
               let cachedData = await TimelineCache.shared.get(for: template.uid) {
                print("📦 Using cached timeline data for template: \(template.uid)")
                await MainActor.run {
                    timelineData = cachedData
                }
                return
            }
            
            do {
                guard let url = URL(string: urlString) else {
                    print("❌ 无效的时间轴URL")
                    return
                }
                
                print("📡 发起网络请求")
                let (data, _) = try await URLSession.shared.data(from: url)
                print("📦 收到数据: \(data.count) bytes")
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 JSON数据: \(jsonString)")
                }
                
                let decoder = JSONDecoder()
                let timeline = try decoder.decode(TimelineData.self, from: data)
                print("✅ 时间轴数据解析成功")
                print("  - 总时长: \(timeline.duration)")
                print("  - 事件数量: \(timeline.events.count)")
                print("  - 图片数量: \(timeline.images.count)")
                
                // Cache the decoded data
                if let template = viewModel.selectedTemplate {
                    await TimelineCache.shared.set(timeline, for: template.uid)
                }
                
                // 加载时间轴图片
                if !timeline.images.isEmpty {
                    print("🖼️ 开始加载时间轴图片")
                    await loadTimelineImages(timeline: timeline)
                }
                
                // 更新状态
                await MainActor.run {
                    timelineData = timeline
                }
            } catch {
                print("❌ 加载时间轴数据失败: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("  - 缺少键: \(key.stringValue)")
                        print("  - 上下文: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("  - 类型不匹配: 期望 \(type)")
                        print("  - 上下文: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("  - 值不存在: 期望 \(type)")
                        print("  - 上下文: \(context.debugDescription)")
                    default:
                        print("  - 其他解码错误: \(decodingError)")
                    }
                }
            }
        }
    }
    
    private func loadTimelineImages(timeline: TimelineData) async {
        var images: [String: Data] = [:]
        
        for imageName in timeline.images {
            let imageUrl = APIConfig.shared.timelineImageURL(templateUid: uid, imageName: imageName)
            print("  📥 加载图片: \(imageUrl)")
            
            if let url = URL(string: imageUrl),
               let image = try? await ImageCacheManager.shared.loadImage(from: url),
               let imageData = image.jpegData(compressionQuality: 0.8) {
                print("  ✅ 图片加载成功: \(imageName)")
                images[imageName] = imageData
            } else {
                print("  ❌ 图片加载失败: \(imageName)")
            }
        }
        
        // 更新状态
        await MainActor.run {
            timelineImages = images
        }
    }
    
    var recordingSheet: some View {
        Group {
            if let timelineData = timelineData {
                CloudRecordingView(
                    timelineData: timelineData,
                    timelineImages: timelineImages,
                    templateUid: uid,
                    onSuccess: { message in
                        ToastManager.shared.show(message)
                    }
                )
            } else {
                ProgressView()
            }
        }
    }
}

// MARK: - Subviews

struct CoverImageView: View {
    let template: CloudTemplate
    @State private var coverImage: UIImage?
    
    var body: some View {
        Group {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(4/3, contentMode: .fit)
            }
        }
        .task {
            if coverImage == nil {
                if let url = URL(string: template.fullCoverOriginal) {
                    coverImage = try? await ImageCacheManager.shared.loadImage(from: url)
                }
            }
        }
    }
}

struct UserInfoView: View {
    let template: CloudTemplate
    @State private var avatarImage: UIImage?
    
    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let image = avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                }
            }
            .task {
                if avatarImage == nil, 
                   let avatarUrl = template.fullAuthorAvatar,
                   let url = URL(string: avatarUrl) {
                    avatarImage = try? await ImageCacheManager.shared.loadImage(from: url)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(template.authorName ?? "未知用户")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("更新于：\(formatDate(template.updatedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

struct InteractionButtonsView: View {
    let template: CloudTemplate
    let viewModel: CloudTemplateViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.likeTemplate(uid: template.uid)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: template.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                    Text("\(template.likesCount)")
                        .font(.caption2)
                }
                .foregroundColor(template.isLiked ? .red : .primary)
            }
            
            Button {
                viewModel.collectTemplate(uid: template.uid)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: template.isCollected ? "star.fill" : "star")
                        .font(.system(size: 18))
                    Text("\(template.collectionsCount)")
                        .font(.caption2)
                }
                .foregroundColor(template.isCollected ? .yellow : .primary)
            }
        }
    }
}

struct TabSectionView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack {
            Picker("内容", selection: $selectedTab) {
                Text("录音").tag(0)
                Text("评论").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Group {
                if selectedTab == 0 {
                    VStack {
                        ForEach(0..<3) { _ in
                            RecordingRow()
                        }
                    }
                } else {
                    VStack {
                        ForEach(0..<3) { _ in
                            CommentRow()
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
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
