import SwiftUI
import AVFoundation
import CoreData

struct RecordingView: View {
    let template: Template
    let recordId: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var currentTime: Double = 0
    @State private var currentItem: TimelineItem?
    @State private var currentImage: UIImage?
    @State private var overlayHeight: CGFloat = 0
    @State private var timer: Timer?
    @State private var isRecordingStopped = false
    @State private var isPreviewMode = false
    @State private var recordedDuration: Double = 0
    @State private var previewPlayer: AVAudioPlayer?
    
    private var progress: Double {
        template.totalDuration > 0 ? currentTime / template.totalDuration : 0
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
                            // 
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
                        Text(formatTime(template.totalDuration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            Spacer()
            
            // 底部控制区域
            VStack(spacing: 20) {
                // 示波图区域 (录音和预览都显示)
                WaveformView(levels: audioRecorder.audioLevels)
                    .frame(height: 100)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.08))
                    )
                    .padding(.horizontal, 8)
                    .opacity(audioRecorder.isRecording ? 1 : 0) // 只在录音时显示
                
                // 控制按钮区域
                HStack(spacing: 40) {
                    Group {
                        if isPreviewMode {
                            // 预览模式按钮组
                            HStack(spacing: 40) {
                                // 波形图按钮
                                Button {
                                    // TODO: 显示波形图
                                } label: {
                                    Image(systemName: "waveform")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                                
                                // 后退15秒
                                Button {
                                    if let player = previewPlayer {
                                        let newTime = max(0, player.currentTime - 15)
                                        player.currentTime = newTime
                                        currentTime = newTime
                                        updateTimelineContent()
                                    }
                                } label: {
                                    Image(systemName: "gobackward.15")
                                        .font(.title)
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
                                    Image(systemName: previewPlayer?.isPlaying == true ? "pause.fill" : "play.fill")
                                        .font(.system(size: 40))
                                }
                                
                                // 前进15秒
                                Button {
                                    if let player = previewPlayer {
                                        let newTime = min(recordedDuration, player.currentTime + 15)
                                        player.currentTime = newTime
                                        currentTime = newTime
                                        updateTimelineContent()
                                    }
                                } label: {
                                    Image(systemName: "goforward.15")
                                        .font(.title)
                                }
                                
                                // 删除按钮
                                Button {
                                    // TODO: 实现删除功能
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.3)
                                    .combined(with: .opacity)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                removal: .scale(scale: 0.3)
                                    .combined(with: .opacity)
                                    .animation(.easeOut(duration: 0.2))
                            ))
                        } else {
                            // 录音按钮
                            Button(action: audioRecorder.isRecording ? stopRecording : startRecording) {
                                Circle()
                                    .fill(audioRecorder.isRecording ? .red : .accentColor)
                                    .frame(width: 80, height: 80)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: audioRecorder.isRecording ? 4 : 40)
                                            .fill(Color.white)
                                            .frame(width: audioRecorder.isRecording ? 30 : 30,
                                                 height: audioRecorder.isRecording ? 30 : 30)
                                    }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.3)
                                    .combined(with: .opacity)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                removal: .scale(scale: 0.3)
                                    .combined(with: .opacity)
                                    .animation(.easeOut(duration: 0.2))
                            ))
                        }
                    }
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8),
                        value: isPreviewMode
                    )
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let recordId = recordId {
                // 如果有 recordId，加载录音并进入预览模式
                loadRecordingForPreview(recordId: recordId)
            } else {
                // 没有 recordId，初始化为录音模式
                if let firstItem = template.timelineItems?.allObjects.first as? TimelineItem {
                    currentItem = firstItem
                    initializeFirstImage()
                }
            }
        }
        .onDisappear {
            stopRecording()
            stopPreview()
        }
    }
    
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
        overlayHeight = 200
        
        currentTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime += 0.1
            updateTimelineContent()
            
            if currentTime >= template.totalDuration {
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
        
        do {
            // 先配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 创建预览播放器
            previewPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            
            // 自动保存录音
            saveRecording { success in
                if success {
                    DispatchQueue.main.async { [self] in
                        // 进入预览模式
                        isPreviewMode = true
                        currentTime = 0
                        if let firstItem = template.timelineItems?.allObjects.first as? TimelineItem {
                            updateContent(for: firstItem)
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to prepare preview: \(error)")
        }
    }
    
    private func updateTimelineContent() {
        // 查找当前时间对应的时间轴项目
        let currentTimeInt = Int(currentTime)
        if let items = template.timelineItems?.allObjects as? [TimelineItem],
           let currentItem = items.first(where: { Int($0.timestamp) == currentTimeInt }) {
            // 更新台词
            self.currentItem = currentItem
            
            // 如果当前项目有图片，则更新图片
            if let imageData = currentItem.image,
               let image = UIImage(data: imageData) {
                currentImage = image
            }
            // 如果当前项目没有图片，保持现有图片不变
        }
    }
    
    private func updateContent(for item: TimelineItem) {
        // 只有在项目变化时才更新内容
        if currentItem?.timestamp != item.timestamp {
            currentItem = item
            if let imageData = item.image,
               let image = UIImage(data: imageData) {
                currentImage = image
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startPreview() {
        guard let player = previewPlayer else { return }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to activate audio session: \(error)")
        }
        
        currentTime = 0
        if let items = template.timelineItems?.allObjects as? [TimelineItem],
           let firstItem = items.first {
            updateContent(for: firstItem)
        }
        
        player.play()
        
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
        if let firstItem = template.timelineItems?.allObjects.first as? TimelineItem {
            updateContent(for: firstItem)
        }
    }
    
    private func saveRecordingAndDismiss() {
        do {
            // 将录音文件转换为数据
            guard let sourceURL = audioRecorder.recordingURL,
                  let audioData = try? Data(contentsOf: sourceURL) else {
                print("❌ Failed to get recording data")
                return
            }
            
            // 保存录音记录
            guard let templateId = template.id else {
                print("❌ Template ID is nil")
                return
            }
            
            let recordId = try TemplateStorage.shared.saveRecord(
                templateId: templateId,
                duration: recordedDuration,
                audioData: audioData
            )
            
            print("✅ Recording saved with ID: \(recordId)")
            
            // 发送录音完成通知
            NotificationCenter.default.post(
                name: .recordingFinished,
                object: nil,
                userInfo: ["templateId": templateId]
            )
            
            // 等待一小段时间确保通知被处理
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
            
            // 删除临时录音文件
            try? FileManager.default.removeItem(at: sourceURL)
            
        } catch {
            print("❌ Failed to save recording: \(error)")
        }
    }
    
    private func initializeFirstImage() {
        guard let items = template.timelineItems?.allObjects as? [TimelineItem] else { return }
        
        // 查找第一个包含图片的项目
        if let firstItemWithImage = items.first(where: { $0.image != nil }),
           let imageData = firstItemWithImage.image,
           let image = UIImage(data: imageData) {
            currentImage = image
        }
    }
    
    private func loadRecordingForPreview(recordId: String) {
        if let records = template.records?.allObjects as? [Record],
           let record = records.first(where: { $0.id == recordId }),
           let audioData = record.audioData {
            do {
                // 创建临时文件
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview_\(recordId).m4a")
                try audioData.write(to: tempURL)
                
                // 创建播放器
                previewPlayer = try AVAudioPlayer(contentsOf: tempURL)
                recordedDuration = record.duration
                isPreviewMode = true
                
                // 初始化第一帧内容
                if let firstItem = template.timelineItems?.allObjects.first as? TimelineItem {
                    currentItem = firstItem
                    initializeFirstImage()
                }
                
            } catch {
                print("❌ Failed to load recording for preview: \(error)")
            }
        }
    }
    
    private func saveRecording(completion: @escaping (Bool) -> Void) {
        do {
            guard let sourceURL = audioRecorder.recordingURL,
                  let audioData = try? Data(contentsOf: sourceURL),
                  let templateId = template.id else {
                completion(false)
                return
            }
            
            let recordId = try TemplateStorage.shared.saveRecord(
                templateId: templateId,
                duration: recordedDuration,
                audioData: audioData
            )
            
            print("✅ Recording saved with ID: \(recordId)")
            
            // 发送录音完成通知
            NotificationCenter.default.post(
                name: .recordingFinished,
                object: nil,
                userInfo: ["templateId": templateId]
            )
            
            // 在完成回调之后再删除源文件
            DispatchQueue.main.async {
                try? FileManager.default.removeItem(at: sourceURL)
                completion(true)
            }
        } catch {
            print("❌ Failed to save recording: \(error)")
            completion(false)
        }
    }
} 