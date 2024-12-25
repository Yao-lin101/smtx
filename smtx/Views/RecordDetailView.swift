import SwiftUI
import AVFoundation

struct RecordDetailView: View {
    let record: Record
    let template: Template
    @StateObject private var player = AudioPlayer()
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(String(format: "%.1f秒", currentTime))
                        .font(.title2)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if player.isPlaying {
                        Button(action: stopPlaying) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: startPlaying) {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("录音信息") {
                HStack {
                    Text("创建时间")
                    Spacer()
                    Text(record.createdAt ?? Date(), style: .date)
                }
                
                HStack {
                    Text("时长")
                    Spacer()
                    Text(String(format: "%.1f秒", record.duration))
                }
            }
        }
        .navigationTitle("录音详情")
        .onAppear {
            loadAudio()
        }
        .onDisappear {
            stopPlaying()
        }
    }
    
    private func loadAudio() {
        guard let audioData = record.audioData else { return }
        
        do {
            try player.loadAudio(data: audioData)
        } catch {
            print("Error loading audio: \(error)")
        }
    }
    
    private func startPlaying() {
        do {
            try player.startPlaying()
            
            // 开始计时
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = player.currentTime
            }
        } catch {
            print("Error starting playback: \(error)")
        }
    }
    
    private func stopPlaying() {
        timer?.invalidate()
        timer = nil
        player.stopPlaying()
    }
}

class AudioPlayer: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    
    var currentTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }
    
    func loadAudio(data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
    }
    
    func startPlaying() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        
        guard let player = audioPlayer else {
            throw PlaybackError.playerNotReady
        }
        
        if player.play() {
            isPlaying = true
        } else {
            throw PlaybackError.playbackFailed
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            print("Playback finished unsuccessfully")
        }
        isPlaying = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Playback decode error: \(error)")
        }
        isPlaying = false
    }
}

enum PlaybackError: Error {
    case playerNotReady
    case playbackFailed
} 