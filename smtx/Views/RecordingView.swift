import SwiftUI
import AVFoundation

struct RecordingView: View {
    let template: TemplateFile
    @StateObject private var recorder = AudioRecorder()
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        List {
            Section {
                ForEach(template.template.timelineItems, id: \.id) { item in
                    TimelineItemView(templateId: template.metadata.id, item: item)
                }
            }
            
            Section {
                HStack {
                    Text(String(format: "%.1f秒", currentTime))
                        .font(.title2)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if recorder.isRecording {
                        Button(action: stopRecording) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: startRecording) {
                            Image(systemName: "record.circle")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("录音")
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        do {
            try recorder.startRecording()
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    private func stopRecording() {
        do {
            let recordData = try recorder.stopRecording()
            currentTime = 0
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