/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+MemoryCacheCost.h"
#import "objc/runtime.h"
#import "NSImage+Compatibility.h"

// 获取image内存cost大小
FOUNDATION_STATIC_INLINE NSUInteger SDMemoryCacheCostForImage(UIImage *image) {
    /*
     首先拿到该image的CGImage指针
     */
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return 0;
    }
    /*
     获取每一帧所占内存bytes = 获取每一行所占bytes * 图片所占高度
     */
    NSUInteger bytesPerFrame = CGImageGetBytesPerRow(imageRef) * CGImageGetHeight(imageRef);
    NSUInteger frameCount;
#if SD_MAC
    frameCount = 1;
#elif SD_UIKIT || SD_WATCH
    // 如果该image不是动图，那么 image.images = nil
    frameCount = image.images.count > 0 ? image.images.count : 1;
#endif
    
    // image 所占总大小 =  每帧所占大小 * 帧数
    NSUInteger cost = bytesPerFrame * frameCount;
    return cost;
}

@implementation UIImage (MemoryCacheCost)


- (NSUInteger)sd_memoryCost {
    NSNumber *value = objc_getAssociatedObject(self, @selector(sd_memoryCost));
    NSUInteger memoryCost;
    if (value != nil) {
        memoryCost = [value unsignedIntegerValue];
    } else {
        memoryCost = SDMemoryCacheCostForImage(self);
    }
    return memoryCost;
}

- (void)setSd_memoryCost:(NSUInteger)sd_memoryCost {
    objc_setAssociatedObject(self, @selector(sd_memoryCost), @(sd_memoryCost), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
