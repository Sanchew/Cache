import Foundation

/// Save objects to memory based on NSCache
final class MemoryStorage {
    // Memory cache keys
    var keys = Set<String>()
    /// Memory cache instance
    fileprivate let cache = NSCache<NSString, MemoryCapsule>()
    /// Configuration
    fileprivate let config: MemoryConfig
    
    // MARK: - Initialization
    
    init(config: MemoryConfig) {
        self.config = config
        self.cache.countLimit = Int(config.countLimit)
        self.cache.totalCostLimit = Int(config.totalCostLimit)
    }
}

extension MemoryStorage: StorageAware {
    func entry<T: Codable>(ofType type: T.Type, forKey key: String) throws -> Entry<T> {
        guard let capsule = cache.object(forKey: NSString(string: key)) else {
            throw StorageError.notFound
        }
        
        guard let object = capsule.object as? T else {
            throw StorageError.typeNotMatch
        }
        
        return Entry(object: object, expiry: capsule.expiry)
    }
    
    func removeObject(forKey key: String) {
        cache.removeObject(forKey: NSString(string: key))
        keys.remove(key)
    }
    
    func setObject<T: Codable>(_ object: T, forKey key: String, expiry: Expiry? = nil) {
        var expiry: Expiry = expiry ?? config.expiry
        if case .seconds(let seconds) = expiry {
            expiry = .date(Date().addingTimeInterval(seconds))
        }
        let capsule = MemoryCapsule(value: object, expiry: expiry)
        cache.setObject(capsule, forKey: NSString(string: key))
        keys.insert(key)
    }
    
    func removeAll() {
        cache.removeAllObjects()
        keys.removeAll()
    }
    
    func removeExpiredObjects() {
        let allKeys = keys
        for key in allKeys {
            removeObjectIfExpired(forKey: key)
        }
    }
}

extension MemoryStorage {
    /**
     Removes the object from the cache if it's expired.
     - Parameter key: Unique key to identify the object in the cache
     */
    func removeObjectIfExpired(forKey key: String) {
        if let capsule = cache.object(forKey: NSString(string: key)), capsule.expiry.isExpired {
            removeObject(forKey: key)
        }
    }
}

/// Helper class to hold cached instance and expiry date.
/// Used in memory storage to work with NSCache.
class MemoryCapsule: NSObject {
    /// Object to be cached
    let object: Any
    /// Expiration date
    let expiry: Expiry
    
    /**
     Creates a new instance of Capsule.
     - Parameter value: Object to be cached
     - Parameter expiry: Expiration date
     */
    init(value: Any, expiry: Expiry) {
        self.object = value
        self.expiry = expiry
    }
}
