//
//  ThreadKeepLiveTestViewController.m
//  MultiThread
//
//  Created by minger on 2021/11/15.
//

#import "ThreadKeepLiveTestViewController.h"
#import "KeepThread.h"

@interface ThreadKeepLiveTestViewController ()

@property (nonatomic, strong) UIButton *testThreadBtn;
@property (nonatomic, strong) KeepThread *keepThread1;
@property (nonatomic, strong) KeepThread *keepThread2;

@end

@implementation ThreadKeepLiveTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.testThreadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.testThreadBtn.frame = CGRectMake(100, 100, 200, 100);
    [self.testThreadBtn setTitle:@"实例化KeepThread" forState:UIControlStateNormal];
    [self.testThreadBtn addTarget:self action:@selector(startThread) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.testThreadBtn];
    
}

- (void)startThread {
    self.keepThread1 = [[KeepThread alloc] initWithBlock:^{
        
    
        NSLog(@"keepThread1： %@,start",[NSThread currentThread]);
        NSLog(@"keepThread1：%@,end", [NSThread currentThread]);
    }];
    self.keepThread2 = [[KeepThread alloc] initWithBlock:^{
        
        NSLog(@"keepThread2：%@,start", [NSThread currentThread]);
        
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addPort:[NSPort port] forMode:NSRunLoopCommonModes];
        [runloop run];
        
        NSLog(@"keepThread2：%@,end", [NSThread currentThread]);
    }];
    
    [self.keepThread1 start];
    [self.keepThread2 start];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self performSelector:@selector(test1) onThread:self.keepThread1 withObject:nil waitUntilDone:NO];
    [self performSelector:@selector(test2) onThread:self.keepThread2 withObject:nil waitUntilDone:NO];
}

- (void)test1 {
    NSLog(@"%s",__func__);
}

- (void)test2 {
    NSLog(@"%s",__func__);
}

- (void)dealloc {
    NSLog(@"%lu%s",(unsigned long)self.hash,__func__);
}

@end
