import Foundation
import AVFoundation
import SwiftUI

class AudioRecorder: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private(set) var recordingURL: URL?
    
    @Published var isRecording = false
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            DispatchQueue.main.async {
                self?.updateAudioLevels(buffer: buffer)
            }
        }
    }
    
    private func updateAudioLevels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataCount = Int(buffer.frameLength)
        
        let normalizeSample = { (sample: Float) -> CGFloat in
            let absolute = abs(sample)
            return CGFloat(absolute)
        }
        
        // 计算音频样本的平均值
        var sum: Float = 0
        for i in 0..<channelDataCount {
            sum += abs(channelData[i])
        }
        let average = sum / Float(channelDataCount)
        
        // 更新音频电平数组
        audioLevels.removeFirst()
        audioLevels.append(normalizeSample(average))
    }
    
    func startRecording(url: URL) {
        recordingURL = url
        print("🎙️ AudioRecorder - Starting recording to: \(url.path)")
        
        // 设置录音参数
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            
            try audioEngine?.start()
            isRecording = true
            print("✅ AudioRecorder - Recording started successfully")
        } catch {
            print("❌ AudioRecorder - Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        print("🛑 AudioRecorder - Stopping recording...")
        audioRecorder?.stop()
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        isRecording = false
        print("✅ AudioRecorder - Recording stopped")
        
        // 重置音频电平
        audioLevels = Array(repeating: 0, count: 30)
    }
}

struct WaveformView: View {
    let levels: [CGFloat]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(levels.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 4, height: geometry.size.height * levels[index])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
} 
