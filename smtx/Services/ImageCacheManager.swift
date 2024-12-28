import Foundation
import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private var loadingTasks: [URL: Task<UIImage?, Error>] = [:]
    private let lock = NSLock()
    
    private init() {
        cache.countLimit = 100  // 最多缓存100张图片
        cache.totalCostLimit = 1024 * 1024 * 100  // 100 MB
    }
    
    func image(for url: URL) -> UIImage? {
        return cache.object(forKey: url.absoluteString as NSString)
    }
    
    func loadImage(from url: URL) async throws -> UIImage {
        // 1. 检查内存缓存
        if let cachedImage = image(for: url) {
            return cachedImage
        }
        
        // 2. 如果已经有相同URL的加载任务，等待其完成
        lock.lock()
        if let existingTask = loadingTasks[url] {
            lock.unlock()
            return try await existingTask.value ?? UIImage()
        }
        
        // 3. 创建新的加载任务
        let task = Task<UIImage?, Error> {
            let request = URLRequest(url: url)
            
            // 检查是否有磁盘缓存
            if let cachedResponse = URLCache.shared.cachedResponse(for: request),
               let image = UIImage(data: cachedResponse.data) {
                cache.setObject(image, forKey: url.absoluteString as NSString)
                return image
            }
            
            // 从网络加载
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                throw URLError(.badServerResponse)
            }
            
            // 保存到缓存
            cache.setObject(image, forKey: url.absoluteString as NSString)
            let cachedResponse = CachedURLResponse(
                response: response,
                data: data,
                storagePolicy: .allowed
            )
            URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            
            return image
        }
        
        loadingTasks[url] = task
        lock.unlock()
        
        // 4. 等待任务完成并清理
        defer {
            lock.lock()
            loadingTasks[url] = nil
            lock.unlock()
        }
        
        return try await task.value ?? UIImage()
    }
    
    func clearCache() {
        cache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
    }
} 