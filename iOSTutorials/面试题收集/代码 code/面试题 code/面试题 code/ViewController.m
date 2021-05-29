//
//  ViewController.m
//  面试题 code
//
//  Created by minger on 2021/5/29.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSMutableArray *muArr = [[NSMutableArray alloc]init];
    
    NSLog(@"muArr 地址: %p", &muArr);
    
    void (^block)(void) = ^{
        NSLog(@"block: muArr 地址: %p", &muArr);
        [muArr addObject:@"1"];
    };
    
    block();
    
    NSLog(@"muArr 地址: %p", &muArr);
    
    
    NSLog(@"%@",muArr);
}


@end
