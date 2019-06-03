//
//  ViewController.m
//  runtime 学习之四道题
//
//  Created by 王民 on 2018/5/28.
//  Copyright © 2018 Minger. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import "Father.h"
#import "Son.h"
#import "NSObject+Sark.h"
#import "Sark.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    Son *son = [[Son alloc]init];
    
    BOOL res1 = [(id)[NSObject class] isKindOfClass:[NSObject class]];
    BOOL res2 = [(id)[NSObject class] isMemberOfClass:[NSObject class]];
    BOOL res3 = [(id)[Son class] isKindOfClass:[Son class]];
    BOOL res4 = [(id)[Son class] isMemberOfClass:[Son class]];
    
    NSLog(@"%@,%@,%@,%@",@(res1),@(res2),@(res3),@(res4));
    
    [NSObject foo];
//    [[NSObject new] foo];
    
    
    id cls = [Sark class];
    void *obj = &cls;
    [(__bridge id)obj speak];
    
    
    Sark *sark = [[Sark alloc]init];
    NSLog(@"Sark instance = %@ 地址 = %p",sark,&sark);
    
    [sark speak];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
