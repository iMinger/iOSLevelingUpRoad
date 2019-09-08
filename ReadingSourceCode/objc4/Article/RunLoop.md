#iOS 底层原理总结-RunLoop

##带着问题看源码
- 1.讲讲 RunLoop，项目中有用到吗？
- 2.RunLoop内部实现逻辑？
- 3.Runloop和线程的关系？
- 4.timer 与 Runloop 的关系？
- 5.程序中添加每3秒响应一次的NSTimer，当拖动tableview时timer可能无法响应要怎么解决？
- 6.Runloop 是怎么响应用户操作的， 具体流程是什么样的？
- 7.说说RunLoop的几种状态？
- 8.Runloop的mode作用是什么？

##RunLoop概念
运行循环，在程序运行过程中做一些事情，如果没有RunLoop程序执行完毕后就会立即退出，如果有RunLoop程序就会一直运行，并且时时刻刻在等待用户的输入操作。RunLoop 可以在需要的时候自己跑起来运行，在没有操作的时候就停下来休息。充分节省CPU资源，提高程序性能。
## RunLoop的基本作用。
1.保持程序持续运行。程序一启动就会开一个主线程，主线程一开起来就会跑一个主线程对应的RunLoop，RunLoop保证主线程不会被销毁，也就保证了程序的持续运行。
2.处理APP中的各种事件。比如：触摸事件，定时器事件，Selector 事件等。
3.节省CPU资源，提高程序的性能。
# RunLoop 对象
> Foundation 框架（基于CFRunLoopRef 的封装）NSRunLoop 

>CoreFoundation CFRunLoopRef 对象

主要研究CFRunLoopRef 源码

### 如何获得RunLoop 对象
```
Foundation
[NSRunLoop currentRunLoop]; // 获得当前线程的RunLoop对象
[NSRunLoop mainRunLoop]; // 获得主线程的RunLoop对象

Core Foundation
CFRunLoopGetCurrent(); // 获得当前线程的RunLoop对象
CFRunLoopGetMain(); // 获得主线程的RunLoop对象
```
# RunLoop 和线程之间的关系
> 1.每条线程都有唯一的一个与之对应的RunLoop 对象。
> 2.RunLoop 保存在一个全局的Dictionary里，线程作为key，RunLoop作为value
> 3.主线程的RunLoop 自动创建好了，子线程的RunLoop需要主动创建。
> 4.RunLoop在第一次获取时创建，在线程结束时销毁。

### 通过源码查看上述对应
```
// 获取当前线程的RunLoop，调用_CFRunLoopGet0方法
CFRunLoopRef CFRunLoopGetCurrent(void) {
    CHECK_FOR_FORK();
    /*
     1. 在获取当前线程的Runloop的时候，首先会通过_CFGetTSD获取Runloop，如果没有在通过__cfRunloopGet0,传入的是当前线程。
     2. CFTSD 是什么。TSD 指的是 Thread-specific data，Thread-specific data 是线程私有数据，顾名思义就是存在一些特定的数据的，Runloop 会保存在线程的私有数据中，
     
     3. 从ForFoundationOnly.h 文件中查看 _CFGetTSD的定义
     */
    CFRunLoopRef rl = (CFRunLoopRef)_CFGetTSD(__CFTSDKeyRunLoop);
    if (rl) return rl;
    return _CFRunLoopGet0(pthread_self());
}

// should only be called by Foundation
// t==0 is a synonym for "main thread" that always works

// 查看_CFRunLoopGet0 方法内部， 传参是一个pthread_t,即对应的线程
CF_EXPORT CFRunLoopRef _CFRunLoopGet0(pthread_t t) {
    if (pthread_equal(t, kNilPthreadT)) {
	t = pthread_main_thread_np();
    }
    
    //加锁
    __CFLock(&loopsLock);
    if (!__CFRunLoops) {
        __CFUnlock(&loopsLock);
	CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    //根据传入的主线程，获取主Runloop
	CFRunLoopRef mainLoop = __CFRunLoopCreate(pthread_main_thread_np());
    //保存主线程 将主线程-key 主RunLoop - value  保存到字典中
	CFDictionarySetValue(dict, pthreadPointer(pthread_main_thread_np()), mainLoop);
	if (!OSAtomicCompareAndSwapPtrBarrier(NULL, dict, (void * volatile *)&__CFRunLoops)) {
	    CFRelease(dict);
	}
	CFRelease(mainLoop);
        __CFLock(&loopsLock);
    }
    
    // 从字典里面拿，将线程作为key 从字典中获取一个loop
    CFRunLoopRef loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
    __CFUnlock(&loopsLock);
    
    //如果获取到的loop为空，则创建一个新的loop，所以Runloopu会在第一次获取的时候创建。
    if (!loop) {
	CFRunLoopRef newLoop = __CFRunLoopCreate(t);
        __CFLock(&loopsLock);
	loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
        
        // 创建好之后，以线程为 key ,runloop 为value， 一对一存储到字典中，下次获取的会后，则直接返回字典内的runloop
	if (!loop) {
	    CFDictionarySetValue(__CFRunLoops, pthreadPointer(t), newLoop);
	    loop = newLoop;
	}
        // don't release run loops inside the loopsLock, because CFRunLoopDeallocate may end up taking it
        __CFUnlock(&loopsLock);
	CFRelease(newLoop);
    }
    
    // t为当前线程的话，将loop保存在线程私有数据中
    if (pthread_equal(t, pthread_self())) {
        _CFSetTSD(__CFTSDKeyRunLoop, (void *)loop, NULL);
        
        // __CFFinalizeRunLoop 是RunLoop的析构函数
        // PTHREAD_DESTRUCTOR_ITERATIONS 表示线程退出时销毁线程私有数据的最大次数
        // 这也是RunLoop的释放时机 -- 线程退出的时候
        if (0 == _CFGetTSD(__CFTSDKeyRunLoopCntr)) {
            _CFSetTSD(__CFTSDKeyRunLoopCntr, (void *)(PTHREAD_DESTRUCTOR_ITERATIONS-1), (void (*)(void *))__CFFinalizeRunLoop);
        }
    }
    return loop;
}

```

从上面的代码可以看出，线程和 RunLoop 之间是一一对应的，其关系是保存在一个 Dictionary 里。所以我们创建子线程RunLoop时，只需在子线程中获取当前线程的RunLoop对象即可[NSRunLoop currentRunLoop];如果不获取，那子线程就不会创建与之相关联的RunLoop，并且只能在一个线程的内部获取其 RunLoop
[NSRunLoop currentRunLoop];方法调用时，会先从线程私有数据中取，如果取不到， 则再看一下字典里有没有存子线程相对用的RunLoop，如果有则直接返回RunLoop，如果没有则会创建一个，并将与之对应的子线程存入字典中。当线程结束时，RunLoop会被销毁。

# RunLoop 的源码
在CFRunLoop.c 中关于RunLoop 的类一共有五个，它们分别是CFRunLoopRef、CFRunLoopModeRef、CFRunLoopSourceRef、CFRunLoopObserverRef、CFRunLoopTimerRef.他们之间的关系：

![image] (https://github.com/iMinger/iOSLevelingUpRoad/raw/master/ReadingSourceCode/objc4/src/RunLoopClassRelation.png)

##CFRunLoopRef
通过源码我们找到__CFRunLoop 结构体

```
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;			/* locked for accessing mode list */  // 锁，这里用了pthread_mutex_t， 常见的几种锁，它们分别是什么？有什么区别，使用场景是什么。
    __CFPort _wakeUpPort;			// used for CFRunLoopWakeUp  // 唤醒端口
    Boolean _unused;
    volatile _per_run_data *_perRunData;              // reset for runs of the run loop
    pthread_t _pthread;
    uint32_t _winthread;
    CFMutableSetRef _commonModes;       // common mode 的集合（如果没有往里面添加mode，则默认为defaultModel 和 UITrackingModel,这是苹果默认添加的）
    CFMutableSetRef _commonModeItems;   // 每个common mode都有的item(source,timer and observer)集合
    CFRunLoopModeRef _currentMode;      // 当前Mode
    CFMutableSetRef _modes;             // 所有的Mode 的集合
    struct _block_item *_blocks_head;
    struct _block_item *_blocks_tail;
    CFAbsoluteTime _runTime;
    CFAbsoluteTime _sleepTime;
    CFTypeRef _counterpart;
};
```

主要看一下两个成员变量
```
CFRunLoopModeRef _currentMode;      // 当前Mode
    CFMutableSetRef _modes;
```

##CFRunLoopModeRef

CFRunLoopModeRef 其实是指向__CFRunLoopMode 结构体的指针，__CFRunLoopMode的结构体源码如下：

```
typedef struct __CFRunLoopMode *CFRunLoopModeRef;

#pragma mark __CFRunLoopMode 定义
struct __CFRunLoopMode {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;	/* must have the run loop locked before locking this */
    CFStringRef _name;
    Boolean _stopped;
    char _padding[3];
    CFMutableSetRef _sources0;  //  非基于Prot(端口)的,是用户主动触发的事件，如触摸事件，PerformSelectors source0的集合
    CFMutableSetRef _sources1;  // 基于port(端口)的，通过内核和其他线程相互发送消息。 source1的集合
    CFMutableArrayRef _observers;  // 监听器的数组
    CFMutableArrayRef _timers;     // 定时器的数组
    CFMutableDictionaryRef _portToV1SourceMap;
    __CFPortSet _portSet;
    CFIndex _observerMask;
    
    // 这里判断如果用了 dispatch_source_t 定时器
#if USE_DISPATCH_SOURCE_FOR_TIMERS
    dispatch_source_t _timerSource;
    dispatch_queue_t _queue;
    Boolean _timerFired; // set to true by the source when a timer has fired
    Boolean _dispatchTimerArmed;
#endif
#if USE_MK_TIMER_TOO
    mach_port_t _timerPort;
    Boolean _mkTimerArmed;
#endif
#if DEPLOYMENT_TARGET_WINDOWS
    DWORD _msgQMask;
    void (*_msgPump)(void);
#endif
    uint64_t _timerSoftDeadline; /* TSR */
    uint64_t _timerHardDeadline; /* TSR */
};
```

通过上面分析我们知道，CFRunLoopModeRef代表RunLoop的运行模式，一个RunLoop包含若干个Mode，每个Mode又包含若干个Source0/Source1/Timer/Observer，而RunLoop启动时只能选择其中一个Mode作为currentMode。

前面提到RunLoop 必须在执行的Mode下运行，如果RunLoop 需要切换Mode,只能退出loop，再重新制定一个Mode进入。这样做的好处是：不同组的source0/source1/timer/observer 可以相互隔离，互不影响，从而提高执行效率。

###RunLoop 的Mode

RunLoop 有五种运行模式，其中常见的1、2、5这三种。
- 1.`kCFRunLoopDefaultMode` : App 的默认Mode，通常主线程是在这个Mode 下运行；
- 2.`UITrackingRunLoopMode` : 界面跟踪的Mode, 用于滚动视图追踪触摸滑动，保证界面滑动时不受其他Mode影响。
- 3.`UIInitializationRunLoopMode` : 在刚启动APP 时进入的第一个Mode，启动完成后就不在使用，会切换到kCFRunLoopDefaultMode ;
- 4.`GSEventReceiveRunLoopMode`: 接受系统事件的内部Mode
- 5.`kCFRunLoopCommonModes` : 这是一个站位用的Mode，并不是一种真正的Mode.

#### commonModes
kCFRunLoopCommonModes 是苹果提供的一种“CommonModes”, 它其实是一个标识符，并不是一个具体的Mode.kCFRunLoopDefaultMode 和 UITrackingRunLoopMode 都被标记为 "commonModes".

一个Mode 可以将自己标记为 “Common” 属性，（通过将其`ModeName` 添加到RunLoop 的commonModes 中）。每当RunLoop的内容发生变化时，RunLoop都会自动将 `_commonModeItems` 里的 source0/source1/timer/observer 同步到具有“Common”标记的所有的Mode里，即能在所有具有“Common” 标记的Mode里运行。

以`CFRunLoopAddSource` 函数为例，只关注“CommonModes” 的部分

```
void CFRunLoopAddSource(CFRunLoopRef rl, CFRunLoopSourceRef rls, CFStringRef modeName) {	
    /* 部分代码省略*/  
    // 该Mode 是CommonMode
    if (modeName == kCFRunLoopCommonModes) {
        // _commonModes存在则获取一份数据拷贝
        CFSetRef set = rl->_commonModes ? CFSetCreateCopy(kCFAllocatorSystemDefault, rl->_commonModes) : NULL;
        // _commonModeItems不存在则创建一个新的集合。
        if (NULL == rl->_commonModeItems) {
            rl->_commonModeItems = CFSetCreateMutable(kCFAllocatorSystemDefault, 0, &kCFTypeSetCallBacks);
        }
        CFSetAddValue(rl->_commonModeItems, rls);
        if (NULL != set) {
            CFTypeRef context[2] = {rl, rls};
            /* add new item to all common-modes */
            // 调用__CFRunLoopAddItemToCommonModes函数向_commonModes中所有的Mode添加这个source
            CFSetApplyFunction(set, (__CFRunLoopAddItemToCommonModes), (void *)context);
            CFRelease(set);
        }
     } 
     
     /*部分代码省略*/
}
```

上面的 source0/source1/observer/timer 被统称为mode item, 一个item 可以被同时加入多个Mode。如果Mode里没有任何的source0/source1/observer/timer,RunLoop 便会立即退出。

这也解决了一个问题- **为什么列表滑动的时候，NSTimer 不执行回调?该如何解决?**

默认NSTimer 是运行在RunLoop的kCFRunLoopDefaultMode 下的，在聊表滑动的时候，RunLoop会切换UITrackingRunLoopMode，因为RunLoop只能运行在一种模式下，所以NSTimer不会执行回调。使用现成的API将NSTimer将添加到commonModes 就可以， kCFRunLoopDefaultMode和 UITrackingRunLoopMode 都已经被标记为“Common” 属性的。这样Timer 就同时加入了这两个Mode中。

## CFRunLoopSourceRef
CFRunLoopSourceRef 对应着__CFRunLoopSource结构体，其源码定义如下：

```
struct __CFRunLoopSource {
    CFRuntimeBase _base;
    uint32_t _bits;
    pthread_mutex_t _lock;
    CFIndex _order;			/* immutable */
    CFMutableBagRef _runLoops;
    union {
	CFRunLoopSourceContext version0;	/* immutable, except invalidation */ //对应source0
        CFRunLoopSourceContext1 version1;	/* immutable, except invalidation */ //对应source1
    } _context;
};
```

#### source0
source0 的定义如下:
```
typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
    Boolean	(*equal)(const void *info1, const void *info2);
    CFHashCode	(*hash)(const void *info);
    // 当source 被添加到RunLoop中后，会调用这个指针
    void	(*schedule)(void *info, CFRunLoopRef rl, CFStringRef mode);
    // 当调CFRunLoopSourceInvalidate函数 移除该source时，会调用这个指针
    void	(*cancel)(void *info, CFRunLoopRef rl, CFStringRef mode);
    // RunLoop 处理source0的时候，会调用这个指针
    void	(*perform)(void *info);
} CFRunLoopSourceContext;
```

#### source1
source1的定义如下：

```
typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
    Boolean	(*equal)(const void *info1, const void *info2);
    CFHashCode	(*hash)(const void *info);
#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)) || (TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
    mach_port_t	(*getPort)(void *info);   //mach_port是用于内核向线程发送消息的
    void *	(*perform)(void *msg, CFIndex size, CFAllocatorRef allocator, void *info);
#else
    void *	(*getPort)(void *info);
    void	(*perform)(void *info);
#endif
} CFRunLoopSourceContext1;
```
source1 中有一个mach_port_t,这个mach_port 是用于内核向线程发送消息的。注意：source1 在处理的时候会分发一些操作给Source0 去处理。

使用Source1的情况：
    - 基于端口的线程间通信（A线程通过端口发送消息给B线程，这个消息是Source1的）；
    - 系统事件的捕获，以点击屏幕事件为例，我们点击屏幕到系统捕捉这个点击事件是 Source1,接着分发到Source0 去处理这个事件。 


其中有两个字段version0 和 version1 对应着source0 和 source1.


### Source0/Source1/Timer/Observer 分别代表什么

#### 1.Source0 : 非基于Port(端口)的,是用户主动触发的事件，如触摸事件，performSelectors
#### 2.Source1 ：基于Port (端口的)的线程间通信




##参考链接
- 1. [iOS底层原理总结 - RunLoop](https://juejin.im/post/5add46606fb9a07abf721d1d#heading-3)  作者：[xx_cc](https://juejin.im/user/5795c0a48ac247005f2fb14a)
- 2. [重拾RunLoop原理](https://juejin.im/post/5cda7a24f265da03a85ae250) 作者：[NeroXie](https://juejin.im/user/595c8f866fb9a06bbf6fecba)