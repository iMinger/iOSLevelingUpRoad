//
//  ViewController.m
//  runtimeStudyDemo1
//
//  Created by 王民 on 2019/1/7.
//  Copyright © 2019 Minger. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import "RuntimeCategoryClass.h"
#import "RuntimeCategoryClass+catagory.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"ViewController";
    
#pragma mark - SEL
    SEL sel1 = @selector(Method1);
    NSLog(@"sel : %p", sel1);
    
    NSString *selName =  [NSString stringWithCString:sel_getName(sel1) encoding:NSUTF8StringEncoding];
    NSLog(@"sel name str = %@", selName);
    
#pragma mark - catagory test
    
    NSLog(@"测试objc_class 中的方法列表中是否包含c分类中的方法");
    unsigned int outCount = 0;
    /*
     从一个类中获取方法列表。只能获取到本类和本类的分类中定义的方法，本类的父类中定义的方法在本类的方法列表中是找不到的。
     */
    
    Method *methodList = class_copyMethodList(RuntimeCategoryClass.class, &outCount);
    
    for (int i = 0; i < outCount; i ++) {
        Method method = methodList[i];
        
        const char * name = sel_getName(method_getName(method));
        NSLog(@"RuntimeCategoryClass's method: %s", name);
        if (strcmp(name, sel_getName(@selector(method2)))) {
            NSLog(@"分类方法method2在objc_class的方法列表中");
        }
    }
    
    
}


- (void)Method1 {
    NSLog(@"Method1 run");
}

@end
