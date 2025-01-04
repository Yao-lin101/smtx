import SwiftUI

struct CloudTemplateDetailView: View {
    let uid: String
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var selectedTab = 0
    @State private var timelineData: TimelineData?
    @State private var timelineImages: [String: Data] = [:]
    @State private var showingRecordingSheet = false
    @State private var showingCommentSheet = false
    @State private var newComment = ""
    
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
                                showingCommentSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "bubble.left.circle.fill")
                                        .font(.title2)
                                    Text("我喵两句")
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
                                    Text("开始表演")
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
                    
                    TabSectionView(
                        selectedTab: $selectedTab,
                        recordings: template.recordings,
                        timelineData: timelineData,
                        timelineImages: timelineImages,
                        templateUid: uid
                    )
                    .environmentObject(viewModel)
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
        .sheet(isPresented: $showingCommentSheet) {
            NavigationView {
                VStack {
                    TextEditor(text: $newComment)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding()
                    
                    Text("\(newComment.count)/100")
                        .font(.caption)
                        .foregroundColor(newComment.count > 100 ? .red : .secondary)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle("发表评论")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            showingCommentSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("发送") {
                            Task {
                                do {
                                    try await viewModel.addComment(templateUid: uid, content: String(newComment.prefix(100)))
                                    showingCommentSheet = false
                                    newComment = ""
                                } catch {
                                    ToastManager.shared.show(error.localizedDescription, type: .error)
                                }
                            }
                        }
                        .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newComment.count > 100)
                    }
                }
            }
            .padding(.horizontal)
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
                        viewModel.loadTemplate(uid)
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
    let recordings: [TemplateRecording]
    let timelineData: TimelineData?
    let timelineImages: [String: Data]
    let templateUid: String
    @EnvironmentObject private var viewModel: CloudTemplateViewModel
    @State private var showingCommentSheet = false
    @State private var newComment = ""
    
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
                    if recordings.isEmpty {
                        Text("暂无录音")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(recordings, id: \.uid) { recording in
                                RecordingRow(
                                    recording: recording,
                                    timelineData: timelineData,
                                    timelineImages: timelineImages,
                                    templateUid: templateUid
                                )
                                .environmentObject(viewModel)
                            }
                        }
                    }
                } else {
                    if let template = viewModel.selectedTemplate {
                        if template.comments.isEmpty {
                            Text("暂无评论")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(template.comments, id: \.id) { comment in
                                        CommentRow(comment: comment)
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingCommentSheet) {
            NavigationView {
                VStack {
                    TextEditor(text: $newComment)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding()
                    
                    Text("\(newComment.count)/100")
                        .font(.caption)
                        .foregroundColor(newComment.count > 100 ? .red : .secondary)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle("发表评论")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            showingCommentSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("发送") {
                            Task {
                                do {
                                    try await viewModel.addComment(templateUid: templateUid, content: String(newComment.prefix(100)))
                                    showingCommentSheet = false
                                    newComment = ""
                                } catch {
                                    ToastManager.shared.show(error.localizedDescription, type: .error)
                                }
                            }
                        }
                        .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newComment.count > 100)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

struct RecordingRow: View {
    let recording: TemplateRecording
    let timelineData: TimelineData?
    let timelineImages: [String: Data]
    let templateUid: String
    @State private var avatarImage: UIImage?
    @State private var showingRecordingPreview = false
    @State private var showingDeleteAlert = false
    @EnvironmentObject private var viewModel: CloudTemplateViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // 用户头像
            Group {
                if let image = avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)
                }
            }
            .task {
                if avatarImage == nil,
                   let avatarUrl = recording.fullUserAvatar,
                   let url = URL(string: avatarUrl) {
                    avatarImage = try? await ImageCacheManager.shared.loadImage(from: url)
                }
            }
            
            // 用户名和时长
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.username)
                    .font(.headline)
                Text(formatDuration(recording.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 删除按钮
            if let currentUser = UserStore.shared.currentUser,
               let template = viewModel.selectedTemplate,
               recording.userUid == currentUser.uid || template.authorUid == currentUser.uid {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        .onTapGesture {
            showingRecordingPreview = true
        }
        .sheet(isPresented: $showingRecordingPreview) {
            if let timelineData = timelineData {
                CloudRecordingPreviewView(
                    timelineData: timelineData,
                    timelineImages: timelineImages,
                    recordingUrl: recording.fullAudioFile,
                    templateUid: templateUid
                )
            }
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteRecording(templateUid: templateUid, recordingUid: recording.uid)
                        ToastManager.shared.show("录音已删除")
                    } catch {
                        ToastManager.shared.show(error.localizedDescription, type: .error)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除这条录音吗？此操作不可恢复。")
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct CommentRow: View {
    let comment: TemplateComment
    @State private var avatarImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 用户头像
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
                       let avatarUrl = comment.fullUserAvatar,
                       let url = URL(string: avatarUrl) {
                        avatarImage = try? await ImageCacheManager.shared.loadImage(from: url)
                    }
                }
                
                Text(comment.username)
                    .font(.headline)
                
                Spacer()
                
                Text(formatTime(comment.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.content)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 {
            return "\(minutes)分钟前"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)小时前"
        } else if let days = components.day, days < 30 {
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }
    }
}

#Preview {
    NavigationStack {
        CloudTemplateDetailView(uid: "test")
            .environmentObject(NavigationRouter())
    }
} 
