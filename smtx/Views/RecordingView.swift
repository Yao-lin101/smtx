import SwiftUI
import AVFoundation

struct RecordingView: View {
    let template: TemplateFile
    @StateObject private var recorder = AudioRecorder()
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // 时间轴预览
            TimelinePreviewView(
                timelineItems: template.template.timelineItems.map { item in
                    TimelineItemData(
                        script: item.script,
                        imageURL: getImageURL(for: item),
                        timestamp: item.timestamp
                    )
                },
                totalDuration: template.template.totalDuration
            )
            .padding(.horizontal)
            
            // 录音控制面板
            VStack(spacing: 16) {
                Text(String(format: "%.1f", currentTime))
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                
                // 录音按钮
                Button(action: recorder.isRecording ? stopRecording : startRecording) {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
            }
            .padding(32)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding()
        }
        .navigationTitle("录音")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func getImageURL(for item: TemplateData.TimelineItem) -> URL? {
        guard !item.image.isEmpty,
              let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) else {
            return nil
        }
        let url = baseURL.appendingPathComponent(item.image)
        // 确保文件存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
    
    private func startRecording() {
        do {
            try recorder.startRecording()
            // 启动计时器
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = recorder.currentTime
            }
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    private func stopRecording() {
        guard recorder.isRecording else { return }
        
        do {
            let recordData = try recorder.stopRecording()
            // TODO: 保存录音数据
            
            // 停止并清除计时器
            timer?.invalidate()
            timer = nil
            currentTime = 0
            
            // 返回上一页
            dismiss()
        } catch {
            print("Error stopping recording: \(error)")
        }
    }
}

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?
    @Published var isRecording = false
    
    var currentTime: TimeInterval {
        audioRecorder?.currentTime ?? 0
    }
    
    func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        // 创建临时文件URL
        let tempDir = FileManager.default.temporaryDirectory
        audioURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")
        
        // 录音设置
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        guard let url = audioURL else {
            throw RecordingError.urlCreationFailed
        }
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        
        if audioRecorder?.record() == true {
            isRecording = true
        } else {
            throw RecordingError.recordingFailed
        }
    }
    
    func stopRecording() throws -> Data {
        guard isRecording else { throw RecordingError.notRecording }
        guard let url = audioURL else { throw RecordingError.urlCreationFailed }
        
        audioRecorder?.stop()
        isRecording = false
        
        // 读取录音文件数据
        let data = try Data(contentsOf: url)
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: url)
        
        return data
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
        isRecording = false
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
        isRecording = false
    }
}

enum RecordingError: Error {
    case urlCreationFailed
    case recordingFailed
    case notRecording
} 