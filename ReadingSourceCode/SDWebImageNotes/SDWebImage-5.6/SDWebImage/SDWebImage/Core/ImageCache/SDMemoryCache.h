/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */


/*
 方式一： 声明一个 SDMemoryCache 协议，定义一些方法和属性，然后创建一个同名协议的实体类，并遵循该协议。
 
 方式二： 直接创建一个 SDMemoryCache 类，将 抽离出SDMemoryCache协议中的方法再合并到SDMemoryCache 中去。
 
 上面两个方式进行对比会发现：方式二不利于扩展和自定义，方式一是在方式二的基础上，将一些核心关键操作抽离出来声明一个协议，然后方便调用自定义一个新的SDMemoryCache类并有其单独实现。
 */
#import "SDWebImageCompat.h"

@class SDImageCacheConfig;
/**
 A protocol to allow custom memory cache used in SDImageCache.
 */
@protocol SDMemoryCache <NSObject>

@required

/**
 Create a new memory cache instance with the specify cache config. You can check `maxMemoryCost` and `maxMemoryCount` used for memory cache.

 @param config The cache config to be used to create the cache.
 @return The new memory cache instance.
 */
- (nonnull instancetype)initWithConfig:(nonnull SDImageCacheConfig *)config;

/**
 Returns the value associated with a given key.

 @param key An object identifying the value. If nil, just return nil.
 @return The value associated with key, or nil if no value is associated with key.
 */
- (nullable id)objectForKey:(nonnull id)key;

/**
 Sets the value of the specified key in the cache (0 cost).

 @param object The object to be stored in the cache. If nil, it calls `removeObjectForKey:`.
 @param key    The key with which to associate the value. If nil, this method has no effect.
 @discussion Unlike an NSMutableDictionary object, a cache does not copy the key
 objects that are put into it.
 */
- (void)setObject:(nullable id)object forKey:(nonnull id)key;

/**
 Sets the value of the specified key in the cache, and associates the key-value
 pair with the specified cost.

 @param object The object to store in the cache. If nil, it calls `removeObjectForKey`.
 @param key    The key with which to associate the value. If nil, this method has no effect.
 @param cost   The cost with which to associate the key-value pair.
 @discussion Unlike an NSMutableDictionary object, a cache does not copy the key
 objects that are put into it.
 */
- (void)setObject:(nullable id)object forKey:(nonnull id)key cost:(NSUInteger)cost;

/**
 Removes the value of the specified key in the cache.

 @param key The key identifying the value to be removed. If nil, this method has no effect.
 */
- (void)removeObjectForKey:(nonnull id)key;

/**
 Empties the cache immediately.
 */
- (void)removeAllObjects;

@end


/*
 2021.11.13 这里SDMemoryCache 是继承自系统的NSCache.YYCache 中的memoryCache是继承自原生的还是自己写的呢？
 在默认SDMemoryCache 对象中有一个 SDImageCacheConfig 缓存配置对象，里面有缓存策略以及缓存时间、大小等方面的设定值。
 */
/**
 A memory cache which auto purge the cache on memory warning and support weak cache.
 */
@interface SDMemoryCache <KeyType, ObjectType> : NSCache <KeyType, ObjectType> <SDMemoryCache>

@property (nonatomic, strong, nonnull, readonly) SDImageCacheConfig *config;

@end
