import SwiftUI
import AVFoundation

struct CloudRecordingView: View {
    let timelineData: TimelineData
    let timelineImages: [String: Data]
    let templateUid: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingUploadAlert = false
    
    private let timelineProvider: CloudTimelineProvider
    private let recordingDelegate: CloudRecordingDelegate
    
    init(timelineData: TimelineData, timelineImages: [String: Data], templateUid: String) {
        self.timelineData = timelineData
        self.timelineImages = timelineImages
        self.templateUid = templateUid
        self.timelineProvider = CloudTimelineProvider(timelineData: timelineData, timelineImages: timelineImages)
        self.recordingDelegate = CloudRecordingDelegate(templateUid: templateUid)
    }
    
    var body: some View {
        BaseRecordingView(
            timelineProvider: timelineProvider,
            delegate: recordingDelegate
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("上传") {
                    showingUploadAlert = true
                }
            }
        }
        .alert("上传录音", isPresented: $showingUploadAlert) {
            Button("取消", role: .cancel) {}
            Button("上传") {
                // TODO: 实现上传逻辑
            }
        } message: {
            Text("确定要上传这个录音吗？")
        }
    }
} 