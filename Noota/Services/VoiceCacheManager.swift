// Noota/Services/VoiceCacheManager.swift

import Foundation

/// 🎤 Cache manager for voice profiles to avoid recomputing embeddings
class VoiceCacheManager {
    static let shared = VoiceCacheManager()
    
    private var voiceCache: [String: Data] = [:]
    private let queue = DispatchQueue(label: "com.noota.voice-cache", attributes: .concurrent)
    
    /// Cache a voice profile
    func cacheVoiceProfile(userId: String, audioData: Data) {
        queue.async(flags: .barrier) {
            self.voiceCache[userId] = audioData
        }
    }
    
    /// Get cached voice profile
    func getVoiceProfile(userId: String) -> Data? {
        var profile: Data?
        queue.sync {
            profile = self.voiceCache[userId]
        }
        return profile
    }
    
    /// Clear cache
    func clearCache() {
        queue.async(flags: .barrier) {
            self.voiceCache.removeAll()
        }
    }
    
    /// Get cache size
    func getCacheSize() -> Int {
        var size = 0
        queue.sync {
            size = self.voiceCache.values.reduce(0) { $0 + $1.count }
        }
        return size
    }
}
