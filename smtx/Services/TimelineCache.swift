import Foundation

actor TimelineCache {
    static let shared = TimelineCache()
    private var cache: [String: (data: TimelineData, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {}
    
    func get(for uid: String) -> TimelineData? {
        if let cached = cache[uid] {
            // Check if cache is still valid
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                return cached.data
            } else {
                // Remove expired cache
                cache.removeValue(forKey: uid)
            }
        }
        return nil
    }
    
    func set(_ data: TimelineData, for uid: String) {
        cache[uid] = (data, Date())
    }
    
    func clear(for uid: String) {
        cache.removeValue(forKey: uid)
    }
    
    func clearAll() {
        cache.removeAll()
    }
} 