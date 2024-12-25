import SwiftUI
import AVFoundation

struct RecordingView: View {
    let template: TemplateFile
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var currentTime: Double = 0
    @State private var currentItem: TemplateData.TimelineItem?
    @State private var currentImage: UIImage?
    @State private var overlayHeight: CGFloat = 0
    @State private var timer: Timer?
    @State private var isRecordingStopped = false
    @State private var isPreviewMode = false
    @State private var recordedDuration: Double = 0
    @State private var previewPlayer: AVAudioPlayer?
    
    private var progress: Double {
        template.template.totalDuration > 0 ? currentTime / template.template.totalDuration : 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部内容区域
            VStack(spacing: 20) {
                // 图片区域
                ZStack {
                    if let image = currentImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.2))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            }
                    }
                }
                .frame(height: 200)
                
                // 台词区域
                ZStack {
                    if let script = currentItem?.script {
                        Text(script)
                            .font(.body)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("无台词")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 60)
                .padding(.horizontal)
                
                // 进度条
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景条
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 4)
                            
                            // 进度条
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    // 时间显示
                    HStack {
                        Text(formatTime(currentTime))
                        Spacer()
                        Text(formatTime(template.template.totalDuration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            Spacer()
            
            // 底部录音区域
            VStack(spacing: 16) {
                // 示波图区域（录音时显示）
                if audioRecorder.isRecording {
                    WaveformView(levels: audioRecorder.audioLevels)
                        .frame(height: 100)
                        .padding(.horizontal)
                }
                
                // 控制按钮
                HStack(spacing: 40) {
                    if isPreviewMode {
                        // 返回按钮
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.secondary)
                        }
                        
                        // 播放/暂停按钮
                        Button {
                            if let player = previewPlayer {
                                if player.isPlaying {
                                    pausePreview()
                                } else {
                                    startPreview()
                                }
                            }
                        } label: {
                            Image(systemName: previewPlayer?.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.accentColor)
                        }
                        
                        // 完成按钮
                        Button {
                            saveRecordingAndDismiss()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                        }
                    } else {
                        // 录音按钮
                        Button {
                            withAnimation(.spring()) {
                                if audioRecorder.isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            }
                        } label: {
                            Circle()
                                .fill(audioRecorder.isRecording ? Color.red : Color.accentColor)
                                .frame(width: 80, height: 80)
                                .overlay {
                                    RoundedRectangle(cornerRadius: audioRecorder.isRecording ? 4 : 40)
                                        .fill(Color.white)
                                        .frame(width: audioRecorder.isRecording ? 30 : 30,
                                             height: audioRecorder.isRecording ? 30 : 30)
                                }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: overlayHeight + 160)
                    .ignoresSafeArea()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let firstItem = template.template.timelineItems.first {
                updateContent(for: firstItem)
            }
        }
        .onDisappear {
            stopRecording()
            stopPreview()
        }
    }
    
    private func startRecording() {
        print("🎙️ Starting recording...")
        
        // 重置录音停止标志
        isRecordingStopped = false
        
        // 创建录音文件URL
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get documents directory")
            return
        }
        let recordingName = "recording_\(Date().timeIntervalSince1970).m4a"
        let recordingURL = documentsPath.appendingPathComponent(recordingName)
        print("📝 Recording will be saved to: \(recordingURL.path)")
        
        // 开始录音和时间轴播放
        audioRecorder.startRecording(url: recordingURL)
        overlayHeight = 200
        
        // 重置时间
        currentTime = 0
        
        // 启动计时器
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime += 0.1
            updateTimelineContent()
            
            if currentTime >= template.template.totalDuration {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        // 避免重复调用
        if isRecordingStopped {
            return
        }
        isRecordingStopped = true
        
        print("🛑 Stopping recording...")
        
        // 停止录音和时间轴播放
        audioRecorder.stopRecording()
        overlayHeight = 0
        
        // 停止计时器
        timer?.invalidate()
        timer = nil
        
        // 如果没有实际录音，直接返回
        guard let recordingURL = audioRecorder.recordingURL else {
            return
        }
        
        // 保存录音时长
        recordedDuration = currentTime
        
        // 配置音频会话为播放模式
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set audio session category: \(error)")
        }
        
        // 准备预览
        do {
            previewPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            isPreviewMode = true
            currentTime = 0
            if let firstItem = template.template.timelineItems.first {
                updateContent(for: firstItem)
            }
        } catch {
            print("❌ Failed to create preview player: \(error)")
        }
    }
    
    private func updateTimelineContent() {
        // 查找当前时间对应的时间轴项目
        let currentTimeInt = Int(currentTime)
        if let item = template.template.timelineItems.first(where: { Int($0.timestamp) == currentTimeInt }) {
            updateContent(for: item)
        }
    }
    
    private func updateContent(for item: TemplateData.TimelineItem) {
        // 只有在项目变化时才更新内容
        if currentItem?.timestamp != item.timestamp {
            currentItem = item
            loadImage(for: item)
        }
    }
    
    private func loadImage(for item: TemplateData.TimelineItem) {
        guard let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) else {
            return
        }
        
        let imageURL = baseURL.appendingPathComponent(item.image)
        
        guard let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return
        }
        
        currentImage = image
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startPreview() {
        guard let player = previewPlayer else { return }
        
        // 确保音频会话处于活动状态
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to activate audio session: \(error)")
        }
        
        // 重置时间轴
        currentTime = 0
        if let firstItem = template.template.timelineItems.first {
            updateContent(for: firstItem)
        }
        
        // 开始播放
        player.play()
        
        // 启动计时器
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = player.currentTime
            updateTimelineContent()
            
            if currentTime >= recordedDuration {
                stopPreview()
            }
        }
    }
    
    private func pausePreview() {
        previewPlayer?.pause()
        timer?.invalidate()
        timer = nil
    }
    
    private func stopPreview() {
        previewPlayer?.stop()
        timer?.invalidate()
        timer = nil
        currentTime = 0
        if let firstItem = template.template.timelineItems.first {
            updateContent(for: firstItem)
        }
    }
    
    private func saveRecordingAndDismiss() {
        do {
            // 获取模板���录
            guard let templateDir = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) else {
                print("❌ Failed to get template directory")
                return
            }
            
            // 生成唯一的录音文件名
            let recordingName = "recording_\(Date().timeIntervalSince1970).m4a"
            let destinationURL = templateDir.appendingPathComponent("records").appendingPathComponent(recordingName)
            
            // 将录音文件移动到模板目录
            let sourceURL = audioRecorder.recordingURL
            
            print("📦 Moving recording file from: \(sourceURL?.path ?? "nil")")
            print("📦 to: \(destinationURL.path)")
            
            if let sourceURL = sourceURL {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                print("✅ Recording file moved successfully")
                
                // 创建新的录音记录
                let record = RecordData(
                    id: UUID().uuidString,
                    createdAt: Date(),
                    duration: recordedDuration,
                    audioFile: "records/\(recordingName)"
                )
                
                // 更新模板数据
                var updatedTemplate = try TemplateStorage.shared.loadTemplate(templateId: template.metadata.id)
                updatedTemplate.records.append(record)
                try TemplateStorage.shared.saveTemplate(updatedTemplate)
                print("✅ Record added to template")
                
                // 发送录音完成通知
                NotificationCenter.default.post(name: .recordingFinished, object: updatedTemplate)
                print("📢 Recording finished notification posted")
                
                // 等待一小段时间确保通知被处理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
            } else {
                print("❌ Recording URL is nil")
            }
        } catch {
            print("❌ Failed to save recording: \(error)")
        }
    }
} 