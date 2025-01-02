import SwiftUI
import AVFoundation

struct BaseRecordingView: View {
    let timelineProvider: TimelineProvider
    let delegate: RecordingDelegate
    @State private var recordId: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var currentTime: Double = 0
    @State private var currentItem: TimelineItemData?
    @State private var isRecordingStopped = false
    @State private var isPreviewMode = false
    @State private var recordedDuration: Double = 0
    @State private var previewPlayer: AVAudioPlayer?
    @State private var showingDeleteAlert = false
    @State private var showingWaveform = false
    @State private var timer: Timer?
    @State private var isPlaying = false
    
    init(timelineProvider: TimelineProvider,
         delegate: RecordingDelegate,
         recordId: String? = nil) {
        self.timelineProvider = timelineProvider
        self.delegate = delegate
        self._recordId = State(initialValue: recordId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 时间轴播放器
            TimelinePlayerView(
                currentTime: currentTime,
                totalDuration: timelineProvider.totalDuration,
                currentItem: currentItem
            )
            
            Spacer()
            
            // 底部控制区域
            VStack(spacing: 20) {
                // 示波器
                WaveformView(levels: showingWaveform ? [] : audioRecorder.audioLevels)
                    .frame(height: 100)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.08))
                    )
                    .padding(.horizontal, 8)
                    .opacity((audioRecorder.isRecording || showingWaveform) ? 1 : 0)
                
                // 控制按钮
                RecordingControlsView(
                    mode: isPreviewMode ? .preview : .recording,
                    isRecording: audioRecorder.isRecording,
                    isPlaying: isPlaying,
                    onRecordTap: audioRecorder.isRecording ? stopRecording : startRecording,
                    onPlayTap: isPlaying ? pausePreview : startPreview,
                    onBackward: backward15Seconds,
                    onForward: forward15Seconds,
                    onDelete: { showingDeleteAlert = true },
                    onDismiss: { @MainActor in dismiss() }
                )
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let recordId = recordId {
                print("📱 Loading recording for preview: \(recordId)")
                loadRecordingForPreview(recordId: recordId)
            } else {
                if let firstItem = timelineProvider.timelineItems.first {
                    currentItem = firstItem
                }
            }
        }
        .onDisappear {
            stopRecording()
            stopPreview()
        }
        .alert("删除录音", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                print("❌ Delete cancelled")
            }
            Button("删除", role: .destructive) {
                print("✅ Delete confirmed, proceeding with deletion")
                deleteRecording()
            }
        } message: {
            Text("确定要删除这个录音吗？")
        }
    }
    
    // MARK: - Recording Methods
    
    private func startRecording() {
        print("🎙️ Starting recording...")
        
        isRecordingStopped = false
        
        // 创建录音文件URL
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get documents directory")
            return
        }
        let recordingName = "recording_\(Date().timeIntervalSince1970).m4a"
        let recordingURL = documentsPath.appendingPathComponent(recordingName)
        print("📝 Recording will be saved to: \(recordingURL.path)")
        
        audioRecorder.startRecording(url: recordingURL)
        
        currentTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            currentTime += 0.03
            updateTimelineContent()
            
            if currentTime >= timelineProvider.totalDuration {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        guard !isRecordingStopped else { return }
        isRecordingStopped = true
        
        print("🛑 Stopping recording...")
        
        audioRecorder.stopRecording()
        timer?.invalidate()
        timer = nil
        
        guard let recordingURL = audioRecorder.recordingURL else { return }
        
        recordedDuration = currentTime
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            previewPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            
            Task {
                do {
                    guard let audioData = try? Data(contentsOf: recordingURL) else { return }
                    let newRecordId = try await delegate.saveRecording(audioData: audioData, duration: recordedDuration)
                    print("✅ Recording saved with ID: \(newRecordId)")
                    
                    await MainActor.run {
                        isPreviewMode = true
                        currentTime = 0
                        self.recordId = newRecordId
                        if let firstItem = timelineProvider.timelineItems.first {
                            currentItem = firstItem
                        }
                    }
                    
                    try? FileManager.default.removeItem(at: recordingURL)
                } catch {
                    print("❌ Failed to save recording: \(error)")
                }
            }
        } catch {
            print("❌ Failed to prepare preview: \(error)")
        }
    }
    
    // MARK: - Preview Methods
    
    private func startPreview() {
        guard let player = previewPlayer else { return }
        print("▶️ Starting preview at time: \(currentTime)")
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to activate audio session: \(error)")
        }
        
        // 重置播放器状态
        player.currentTime = currentTime
        player.prepareToPlay()
        
        player.play()
        isPlaying = true
        print("⏱️ Starting timer for playback tracking")
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            currentTime = player.currentTime
            updateTimelineContent()
            
            if currentTime >= recordedDuration {
                print("🏁 Reached end of recording (currentTime: \(currentTime), duration: \(recordedDuration))")
                stopPreview()
            }
        }
    }
    
    private func pausePreview() {
        print("⏸️ Pausing preview at time: \(currentTime)")
        previewPlayer?.pause()
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    private func stopPreview() {
        print("⏹️ Stopping preview")
        previewPlayer?.stop()
        timer?.invalidate()
        timer = nil
        isPlaying = false
        
        // 重置状态
        currentTime = 0
        if let player = previewPlayer {
            player.currentTime = 0
            player.prepareToPlay()
        }
        if let item = timelineProvider.timelineItems.first {
            currentItem = item
        }
        print("🔄 Reset player state: currentTime = 0")
    }
    
    private func forward15Seconds() {
        if let player = previewPlayer {
            let newTime = min(recordedDuration, player.currentTime + 15)
            print("⏩ Forward 15s: \(player.currentTime) -> \(newTime) (max: \(recordedDuration))")
            player.currentTime = newTime
            currentTime = newTime
            updateTimelineContent()
        }
    }
    
    private func backward15Seconds() {
        if let player = previewPlayer {
            let newTime = max(0, player.currentTime - 15)
            print("⏪ Backward 15s: \(player.currentTime) -> \(newTime)")
            player.currentTime = newTime
            currentTime = newTime
            updateTimelineContent()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateTimelineContent() {
        if let item = timelineProvider.getItemAt(timestamp: currentTime) {
            currentItem = item
        }
    }
    
    private func loadRecordingForPreview(recordId: String) {
        Task {
            do {
                guard let (audioData, duration) = try await delegate.loadRecording(id: recordId) else {
                    print("❌ Failed to load recording data")
                    return
                }
                
                // 创建临时文件
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview_\(recordId).m4a")
                try audioData.write(to: tempURL)
                
                // 配置音频会话
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                
                // 创建播放器
                previewPlayer = try AVAudioPlayer(contentsOf: tempURL)
                previewPlayer?.prepareToPlay()
                recordedDuration = duration
                
                await MainActor.run {
                    isPreviewMode = true
                    if let firstItem = timelineProvider.timelineItems.first {
                        currentItem = firstItem
                    }
                }
            } catch {
                print("❌ Failed to load recording for preview: \(error)")
            }
        }
    }
    
    private func deleteRecording() {
        guard let recordId = recordId else {
            print("❌ Cannot delete recording: recordId is nil")
            return
        }
        
        print("🗑️ Starting to delete recording: \(recordId)")
        Task {
            do {
                try await delegate.deleteRecording(id: recordId)
                print("✅ Successfully deleted recording: \(recordId)")
                await MainActor.run {
                    print("🔄 Dismissing view after deletion")
                    dismiss()
                }
            } catch {
                print("❌ Failed to delete recording: \(error)")
            }
        }
    }
} 
