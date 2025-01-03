import SwiftUI
import AVFoundation

struct CloudRecordingPreviewView: View {
    let timelineData: TimelineData
    let timelineImages: [String: Data]
    let recordingUrl: String
    let templateUid: String
    
    private let delegate: CloudRecordingDelegate
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var recordId = UUID().uuidString
    @State private var isLoading = true
    
    init(timelineData: TimelineData, timelineImages: [String: Data], recordingUrl: String, templateUid: String) {
        print("🎯 CloudRecordingPreviewView 初始化")
        print("  - 时间轴事件数: \(timelineData.events.count)")
        print("  - 图片数: \(timelineImages.count)")
        print("  - 录音URL: \(recordingUrl)")
        
        self.timelineData = timelineData
        self.timelineImages = timelineImages
        self.recordingUrl = recordingUrl
        self.templateUid = templateUid
        self.delegate = CloudRecordingDelegate(templateUid: templateUid, recordingUrl: recordingUrl)
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                BaseRecordingView(
                    timelineProvider: CloudTimelineProvider(timelineData: timelineData, timelineImages: timelineImages),
                    delegate: delegate,
                    recordId: recordId,
                    onUpload: nil,
                    isUploading: isPlaying,
                    showDeleteButton: false,
                    showUploadButton: false
                )
            }
        }
        .task {
            print("🔄 开始加载录音数据")
            if let url = URL(string: recordingUrl) {
                do {
                    let (data, duration) = try await RecordingCacheManager.shared.loadRecording(from: url)
                    print("✅ 录音数据加载成功，duration: \(duration)")
                    delegate.setRecordingData(audioData: data, duration: duration)
                    
                    // 确保在主线程更新 UI
                    await MainActor.run {
                        isLoading = false
                        print("👀 视图准备完成")
                        print("  - recordId: \(recordId)")
                    }
                } catch {
                    print("❌ 加载录音失败: \(error)")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
} 