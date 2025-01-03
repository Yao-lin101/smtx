import Foundation
import AVFoundation

class RecordingCacheManager {
    static let shared = RecordingCacheManager()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // 获取缓存目录
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachePath.appendingPathComponent("recordings", isDirectory: true)
        
        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// 从 URL 加载录音，如果本地有缓存则使用缓存
    func loadRecording(from url: URL) async throws -> (Data, Double) {
        let cacheKey = url.lastPathComponent
        let cachedFileURL = cacheDirectory.appendingPathComponent(cacheKey)
        
        // 检查缓存
        if fileManager.fileExists(atPath: cachedFileURL.path) {
            let audioData = try Data(contentsOf: cachedFileURL)
            let player = try AVAudioPlayer(data: audioData)
            return (audioData, player.duration)
        }
        
        // 从网络下载
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // 保存到缓存
        try data.write(to: cachedFileURL)
        
        let player = try AVAudioPlayer(data: data)
        return (data, player.duration)
    }
    
    /// 清理过期缓存（7天前的文件）
    func cleanExpiredCache() {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        for file in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }
            
            if creationDate < sevenDaysAgo {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    /// 清理所有缓存
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
} 