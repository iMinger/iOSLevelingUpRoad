/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDMemoryCache.h"
#import "SDImageCacheConfig.h"
#import "UIImage+MemoryCacheCost.h"
#import "SDInternalMacros.h"

static void * SDMemoryCacheContext = &SDMemoryCacheContext;

@interface SDMemoryCache <KeyType, ObjectType> ()

@property (nonatomic, strong, nullable) SDImageCacheConfig *config;
#if SD_UIKIT

// NSMapTable 该数据结构中，对其value 是weak弱引用，不会造成引用计数器+1的问题，然后因为这里weakCache泛型，SDMemoryCache也设定了泛型。
@property (nonatomic, strong, nonnull) NSMapTable<KeyType, ObjectType> *weakCache; // strong-weak cache
@property (nonatomic, strong, nonnull) dispatch_semaphore_t weakCacheLock; // a lock to keep the access to `weakCache` thread-safe
#endif
@end

@implementation SDMemoryCache

- (void)dealloc {
    // KVO 在dealloc 的时候，要将观察者去掉，防止出现内存泄漏的问题
    [_config removeObserver:self forKeyPath:NSStringFromSelector(@selector(maxMemoryCost)) context:SDMemoryCacheContext];
    [_config removeObserver:self forKeyPath:NSStringFromSelector(@selector(maxMemoryCount)) context:SDMemoryCacheContext];
#if SD_UIKIT
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
    self.delegate = nil;
}

// 目前一个SDMemoryCache 有两种实例化方式：一种是使用默认SDImageCacheConfig，一种是外部传入SDImageCacheConfig
- (instancetype)init {
    self = [super init];
    if (self) {
        _config = [[SDImageCacheConfig alloc] init];
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithConfig:(SDImageCacheConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
        [self commonInit];
    }
    return self;
}

// 在这里设定一些公共初始化参数和KVO
- (void)commonInit {
    SDImageCacheConfig *config = self.config;
    self.totalCostLimit = config.maxMemoryCost;
    self.countLimit = config.maxMemoryCount;

    [config addObserver:self forKeyPath:NSStringFromSelector(@selector(maxMemoryCost)) options:0 context:SDMemoryCacheContext];
    [config addObserver:self forKeyPath:NSStringFromSelector(@selector(maxMemoryCount)) options:0 context:SDMemoryCacheContext];

#if SD_UIKIT
    self.weakCache = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
    self.weakCacheLock = dispatch_semaphore_create(1);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
#endif
}

// Current this seems no use on macOS (macOS use virtual memory and do not clear cache when memory warning). So we only override on iOS/tvOS platform.
#if SD_UIKIT
- (void)didReceiveMemoryWarning:(NSNotification *)notification {
    // Only remove cache, but keep weak cache
    [super removeAllObjects];
}

// `setObject:forKey:` just call this with 0 cost. Override this is enough
- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g {
    [super setObject:obj forKey:key cost:g];
    if (!self.config.shouldUseWeakMemoryCache) {
        return;
    }
    if (key && obj) {
        // 这里如果允许使用弱引用内存缓存，那么就需要将obj存到weakCache中
        // Store weak cache
        SD_LOCK(self.weakCacheLock);
        [self.weakCache setObject:obj forKey:key];
        SD_UNLOCK(self.weakCacheLock);
    }
}

- (id)objectForKey:(id)key {
    // 因为SDMemoryCache是继承自NSCache的，所以可以通过父类中的objectForKey 取得对象。
    id obj = [super objectForKey:key];
    if (!self.config.shouldUseWeakMemoryCache) {
        return obj;
    }
    if (key && !obj) {
        // Check weak cache
        SD_LOCK(self.weakCacheLock);
        obj = [self.weakCache objectForKey:key];
        SD_UNLOCK(self.weakCacheLock);
        if (obj) {
            // Sync cache
            NSUInteger cost = 0;
            if ([obj isKindOfClass:[UIImage class]]) {
                cost = [(UIImage *)obj sd_memoryCost];
            }
            [super setObject:obj forKey:key cost:cost];
        }
    }
    return obj;
}

// 从NSCache 中移除该key-value, 并尝试从weakCache 中移除
- (void)removeObjectForKey:(id)key {
    [super removeObjectForKey:key];
    if (!self.config.shouldUseWeakMemoryCache) {
        return;
    }
    if (key) {
        // Remove weak cache
        SD_LOCK(self.weakCacheLock);
        [self.weakCache removeObjectForKey:key];
        SD_UNLOCK(self.weakCacheLock);
    }
}

- (void)removeAllObjects {
    [super removeAllObjects];
    if (!self.config.shouldUseWeakMemoryCache) {
        return;
    }
    // Manually remove should also remove weak cache
    SD_LOCK(self.weakCacheLock);
    [self.weakCache removeAllObjects];
    SD_UNLOCK(self.weakCacheLock);
}
#endif

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == SDMemoryCacheContext) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(maxMemoryCost))]) {
            self.totalCostLimit = self.config.maxMemoryCost;
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(maxMemoryCount))]) {
            self.countLimit = self.config.maxMemoryCount;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
