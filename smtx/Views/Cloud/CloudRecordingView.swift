import SwiftUI
import AVFoundation

struct CloudRecordingView: View {
    let timelineData: TimelineData
    let timelineImages: [String: Data]
    let templateUid: String
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isUploading = false
    
    private let timelineProvider: CloudTimelineProvider
    private let recordingDelegate: CloudRecordingDelegate
    
    init(timelineData: TimelineData, timelineImages: [String: Data], templateUid: String, onSuccess: @escaping (String) -> Void) {
        self.timelineData = timelineData
        self.timelineImages = timelineImages
        self.templateUid = templateUid
        self.onSuccess = onSuccess
        self.timelineProvider = CloudTimelineProvider(timelineData: timelineData, timelineImages: timelineImages)
        self.recordingDelegate = CloudRecordingDelegate(templateUid: templateUid)
    }
    
    var body: some View {
        BaseRecordingView(
            timelineProvider: timelineProvider,
            delegate: recordingDelegate,
            onUpload: {
                guard !isUploading else { return }
                isUploading = true
            },
            isUploading: isUploading
        )
        .onChange(of: isUploading) { uploading in
            if uploading {
                Task {
                    do {
                        let message = try await recordingDelegate.uploadRecording()
                        await MainActor.run {
                            isUploading = false
                            onSuccess(message)
                            dismiss()
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