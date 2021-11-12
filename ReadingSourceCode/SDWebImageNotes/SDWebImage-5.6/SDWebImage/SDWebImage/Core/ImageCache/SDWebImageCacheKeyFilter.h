/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

// 声明一个    SDWebImageCacheKeyFilter 协议，里面定义一些要实现的方法
// 然后声明一个 SDWebImageCacheKeyFilter 同名实体类，实现SDWebImageCacheKeyFilter协议中的方法。体会一下这样做的好处，可参考NSObject.

// 我们可以新创建一个类 遵循 SDWebImageCacheKeyFilter 协议并实现其中的 cacheKeyForURL 方法，来自定义cacheKey 的生成。


#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

typedef NSString * _Nullable(^SDWebImageCacheKeyFilterBlock)(NSURL * _Nonnull url);

/**
 This is the protocol for cache key filter.
 We can use a block to specify the cache key filter. But Using protocol can make this extensible, and allow Swift user to use it easily instead of using `@convention(block)` to store a block into context options.
 */
@protocol SDWebImageCacheKeyFilter <NSObject>

- (nullable NSString *)cacheKeyForURL:(nonnull NSURL *)url;

@end

/**
 A cache key filter class with block.
 */
@interface SDWebImageCacheKeyFilter : NSObject <SDWebImageCacheKeyFilter>

- (nonnull instancetype)initWithBlock:(nonnull SDWebImageCacheKeyFilterBlock)block;
+ (nonnull instancetype)cacheKeyFilterWithBlock:(nonnull SDWebImageCacheKeyFilterBlock)block;

@end
