import SwiftUI

struct CloudTemplateDetailView: View {
    let uid: String
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = CloudTemplateViewModel()
    @State private var selectedTab = 0
    
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
                    
                    TimelinePreviewView(
                        timelineItems: [
                            TimelineItemData(script: "示例文本1", imageData: nil, timestamp: 1.0, createdAt: Date(), updatedAt: Date()),
                            TimelineItemData(script: "示例文本2", imageData: nil, timestamp: 2.5, createdAt: Date(), updatedAt: Date()),
                            TimelineItemData(script: "示例文本3", imageData: nil, timestamp: 4.0, createdAt: Date(), updatedAt: Date())
                        ],
                        totalDuration: Double(template.duration)
                    )
                    .padding(.horizontal)
                    
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
        .onAppear {
            viewModel.loadTemplate(uid)
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
