import SwiftUI
import AVFoundation

struct CloudRecordingView: View {
    let timelineData: TimelineData
    let timelineImages: [String: Data]
    let templateUid: String
    @Environment(\.dismiss) private var dismiss
    @State private var isUploading = false
    @StateObject private var toastManager = ToastManager.shared
    
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
            delegate: recordingDelegate,
            onUpload: {
                isUploading = true
            }
        )
        .onChange(of: isUploading) { uploading in
            if uploading {
                Task {
                    do {
                        let message = try await recordingDelegate.uploadRecording()
                        await MainActor.run {
                            isUploading = false
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                ToastManager.shared.show(message)
                            }
                        }
                    } catch {
                        await MainActor.run {
                            isUploading = false
                            ToastManager.shared.show(error.localizedDescription, type: .error)
                        }
                    }
                }
            }
        }
        .toastManager()
    }
} 