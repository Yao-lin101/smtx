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
                    AuthorInfoView(template: template)
                    TitleView(title: template.title)
                    InteractionButtonsView(template: template, viewModel: viewModel)
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

struct AuthorInfoView: View {
    let template: CloudTemplate
    @State private var avatarImage: UIImage?
    
    var body: some View {
        HStack {
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
                   let avatarUrl = template.fullAuthorAvatar,
                   let url = URL(string: avatarUrl) {
                    avatarImage = try? await ImageCacheManager.shared.loadImage(from: url)
                }
            }
            
            VStack(alignment: .leading) {
                Text(template.authorName ?? "未知用户")
                    .font(.headline)
                Text(formatDate(template.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

struct TitleView: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(.horizontal)
    }
}

struct InteractionButtonsView: View {
    let template: CloudTemplate
    let viewModel: CloudTemplateViewModel
    
    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            
            Button {
                viewModel.likeTemplate(uid: template.uid)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: template.isLiked ? "heart.fill" : "heart")
                        .font(.title2)
                    Text("\(template.likesCount)")
                        .font(.caption)
                }
                .foregroundColor(template.isLiked ? .red : .primary)
            }
            
            Button {
                viewModel.collectTemplate(uid: template.uid)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: template.isCollected ? "star.fill" : "star")
                        .font(.title2)
                    Text("\(template.collectionsCount)")
                        .font(.caption)
                }
                .foregroundColor(template.isCollected ? .yellow : .primary)
            }
            
            Spacer()
        }
        .padding(.vertical)
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
