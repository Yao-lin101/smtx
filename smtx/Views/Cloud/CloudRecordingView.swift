import SwiftUI
import AVFoundation

struct CloudRecordingView: View {
    let timelineData: TimelineData
    let timelineImages: [String: Data]
    let templateUid: String
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isUploading = false
    @State private var showingOverrideAlert = false
    @State private var pendingRecordingData: (Data, Double)?
    
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
                            pendingRecordingData = nil
                            onSuccess(message)
                            dismiss()
                        }
                    } catch let error as NSError {
                        await MainActor.run {
                            if error.domain == "NetworkError" && error.code == 409 {
                                if let recordingData = recordingDelegate.recordingData {
                                    pendingRecordingData = recordingData
                                    showingOverrideAlert = true
                                }
                            } else {
                                ToastManager.shared.show(error.localizedDescription, type: .error)
                            }
                            isUploading = false
                        }
                    }
                }
            }
        }
        .alert("已存在录音", isPresented: $showingOverrideAlert) {
            Button("覆盖", role: .destructive) {
                if let (_, _) = pendingRecordingData {
                    Task {
                        do {
                            let message = try await recordingDelegate.uploadRecording(forceOverride: true)
                            await MainActor.run {
                                pendingRecordingData = nil
                                onSuccess(message)
                                dismiss()
                            }
                        } catch {
                            await MainActor.run {
                                pendingRecordingData = nil
                                ToastManager.shared.show(error.localizedDescription, type: .error)
                            }
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {
                pendingRecordingData = nil
            }
        } message: {
            Text("您已经上传过录音，是否要覆盖现有录音？")
        }
        .toastManager()
    }
} 
