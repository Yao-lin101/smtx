import SwiftUI
import AVFoundation

struct CloudRecordingView: View {
    let timelineData: TimelineData
    let timelineImages: [String: Data]
    let templateUid: String
    let recordingUrl: String?
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isUploading = false
    @State private var showingOverrideAlert = false
    @State private var pendingRecordingData: (Data, Double)?
    @State private var isPreviewMode = false
    @State private var recordId: String?
    @State private var isLoading = true
    
    private let timelineProvider: CloudTimelineProvider
    private let recordingDelegate: CloudRecordingDelegate
    
    init(timelineData: TimelineData, timelineImages: [String: Data], templateUid: String, recordingUrl: String? = nil, onSuccess: @escaping (String) -> Void) {
        self.timelineData = timelineData
        self.timelineImages = timelineImages
        self.templateUid = templateUid
        self.recordingUrl = recordingUrl
        self.onSuccess = onSuccess
        self.timelineProvider = CloudTimelineProvider(timelineData: timelineData, timelineImages: timelineImages)
        self.recordingDelegate = CloudRecordingDelegate(templateUid: templateUid, recordingUrl: recordingUrl)
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                BaseRecordingView(
                    timelineProvider: timelineProvider,
                    delegate: recordingDelegate,
                    recordId: recordId,
                    onUpload: {
                        guard !isUploading else { return }
                        isUploading = true
                    },
                    isUploading: isUploading
                )
            }
        }
        .task {
            if let recordingUrl = recordingUrl,
               let url = URL(string: recordingUrl) {
                do {
                    let (audioData, duration) = try await RecordingCacheManager.shared.loadRecording(from: url)
                    await MainActor.run {
                        recordingDelegate.setRecordingData(audioData: audioData, duration: duration)
                        recordId = UUID().uuidString
                        isLoading = false
                    }
                } catch {
                    print("❌ Failed to load recording: \(error)")
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
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
