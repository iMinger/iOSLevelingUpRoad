//
//  Son.m
//  runtime 学习之四道题
//
//  Created by 王民 on 2018/5/28.
//  Copyright © 2018 Minger. All rights reserved.
//

#import "Son.h"

@implementation Son

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"%@",NSStringFromClass([self class]));
        NSLog(@"%@",NSStringFromClass([super class]));
    }
    return self;
}
@end
