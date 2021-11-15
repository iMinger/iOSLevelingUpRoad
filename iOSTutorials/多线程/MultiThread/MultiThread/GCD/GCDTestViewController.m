//
//  GCDTestViewController.m
//  MultiThread
//
//  Created by minger on 2021/11/15.
//

#import "GCDTestViewController.h"

@interface GCDTestViewController ()

@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, strong) dispatch_queue_t concurrentQueue;
@property (nonatomic, strong) dispatch_queue_t mainQueue;
@property (nonatomic, strong) UIButton *logBtn;
@property (nonatomic, strong) UIButton *concurrentSyncBtn;
@property (nonatomic, strong) UIButton *concurrentAsyncBtn;
@property (nonatomic, strong) UIButton *mainQueueBtn;

@end

@implementation GCDTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.ioQueue = dispatch_queue_create("com.hackemist.SDImageCache", DISPATCH_QUEUE_SERIAL);
    self.concurrentQueue = dispatch_queue_create("com.concurrent.WM", DISPATCH_QUEUE_CONCURRENT);
    // 这里将 mainQueue的label 设置的和主线程队列中的label 名称一致，看会不会该队列会不会是主队列
    // 答案是不会，
    self.mainQueue = dispatch_queue_create(dispatch_queue_get_label(dispatch_get_main_queue()), DISPATCH_QUEUE_SERIAL);

    [self.view addSubview:self.logBtn];
    self.logBtn.frame = CGRectMake(100, 100, 200, 50);
    
    [self.view addSubview:self.concurrentSyncBtn];
    self.concurrentSyncBtn.frame = CGRectMake(100, 200, 200, 50);
    
    [self.view addSubview:self.concurrentAsyncBtn];
    self.concurrentAsyncBtn.frame = CGRectMake(100, 300, 200, 50);
    
    [self.view addSubview:self.mainQueueBtn];
    self.mainQueueBtn.frame = CGRectMake(100, 400, 200, 50);
    
}

- (void)doLog {
    dispatch_async(self.ioQueue, ^{
        // 在iOqueue 输出
        NSLog(@"在iOqueue 异步输出： %@", [NSThread currentThread]);
        dispatch_async(self.ioQueue, ^{
            // 在iOqueue 输出
            NSLog(@"在iOqueue 异步输出： %@", [NSThread currentThread]);
        });
    });
    
    dispatch_sync(self.ioQueue, ^{
        // 在iOqueue 输出
        NSLog(@"在iOqueue 同步输出： %@", [NSThread currentThread]);
        // 下面会发生线程锁死的情况
//        dispatch_sync(self.ioQueue, ^{
//            // 在iOqueue 输出
//            NSLog(@"在iOqueue 同步输出： %@", [NSThread currentThread]);
//        });
    });
    
}

- (void)concurrentSyncLog {
    dispatch_sync(self.concurrentQueue, ^{
        // 在concurrentqueue 同步输出
        NSLog(@"在concurrentqueue 同步输出： %@", [NSThread currentThread]);
    });
}
- (void)concurrentAsyncLog {
    dispatch_async(self.concurrentQueue, ^{
        // 在concurrentqueue 异步输出
        NSLog(@"在concurrentqueue 异步输出： %@", [NSThread currentThread]);
    });
}

- (void)mainQueueAsyncLog {
    
    /*
     下面两行为输出log：
     在mainQueue 异步输出1： <NSThread: 0x600003005040>{number = 6, name = (null)}
     在main queue 异步输出2： <_NSMainThread: 0x600003058a00>{number = 1, name = main}
     可以看到，虽然 self.mainQueue的label设置成和 dispatch_get_main_queue()
     */
    dispatch_async(self.mainQueue, ^{
        // 在concurrentqueue 异步输出
        NSLog(@"在mainQueue 异步输出1： %@", [NSThread currentThread]);
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 在concurrentqueue 异步输出
        NSLog(@"在main queue 异步输出2： %@", [NSThread currentThread]);
    });
}

-(void)dealloc {
    
}

#pragma  mark -lazyload
- (UIButton *)logBtn {
    if (!_logBtn) {
        _logBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_logBtn setTitle:@"在iOqueue 输出" forState:UIControlStateNormal];
        _logBtn.backgroundColor = [UIColor blackColor];
        [_logBtn addTarget:self action:@selector(doLog) forControlEvents:UIControlEventTouchUpInside];
    }
    return _logBtn;
}

- (UIButton *)concurrentSyncBtn {
    if (!_concurrentSyncBtn) {
        _concurrentSyncBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_concurrentSyncBtn setTitle:@"在concurrentqueue 同步输出" forState:UIControlStateNormal];
        _concurrentSyncBtn.backgroundColor = [UIColor greenColor];
        [_concurrentSyncBtn addTarget:self action:@selector(concurrentSyncLog) forControlEvents:UIControlEventTouchUpInside];
    }
    return _concurrentSyncBtn;
}

- (UIButton *)concurrentAsyncBtn {
    if (!_concurrentAsyncBtn) {
        _concurrentAsyncBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_concurrentAsyncBtn setTitle:@"在concurrentqueue 异步输出" forState:UIControlStateNormal];
        _concurrentAsyncBtn.backgroundColor = [UIColor redColor];
        [_concurrentAsyncBtn addTarget:self action:@selector(concurrentAsyncLog) forControlEvents:UIControlEventTouchUpInside];
    }
    return _concurrentAsyncBtn;
}

- (UIButton *)mainQueueBtn {
    if (!_mainQueueBtn) {
        _mainQueueBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_mainQueueBtn setTitle:@"在mainQueue 异步输出" forState:UIControlStateNormal];
        _mainQueueBtn.backgroundColor = [UIColor blueColor];
        [_mainQueueBtn addTarget:self action:@selector(mainQueueAsyncLog) forControlEvents:UIControlEventTouchUpInside];
    }
    return _mainQueueBtn;
}




@end
