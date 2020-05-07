# FBKVOController 源码阅读总结
iOS 中的 KVO(Key Value Observing) 键值观察，是 iOS 观察者模式的一种实现，另外还有通知（Notification）实现。KVO 是允许一个对象监听另外一个对象特定属性的改变，并在改变时接受事件。使用起来很爽，但是有很多容易 造成crash 的情况。比如：dealloc时未释放 KVO 等。
而 KVOController 做了一个一套措施来解决 KVO 遇到的问题.

### 源码解读
FBKVOController 代码结构如下：

![KVOController_sourcefile](https://gitee.com/iminger/CommonImage/raw/master/MarkDown_image/FBKVOController/KVOController_sourcefile.png)

这个库中一共有 5 个类，一个头文件类`KVOController.h`，其中共引入了连个头文件
![8f3acbc0ce453a594aff5f0ba3555ec5.png](evernotecid://0F9C3E48-DD6A-49F2-B223-09C4CBC87201/appyinxiangcom/11847268/ENResource/p107)

一个 `NSObject+FBKVOController.h` NSObject 分类，给所有 NSObject 类添加了一些语法糖,都可以调用KVOController和KVOControllerNonRetaining 属性.调用时,如果没有值则创建一个实例保存起来并返回该值.

其核心处理类为 `FBKVOController`.这个类中主要包含三部分：

>FBKVOInfo              来保存一个 观察者和一个观察事件
 FBKVOShareController   一个单例，真正的观察者，所有通过FBKVOController来添加观察者的操作最终都是由FBKVOShareController来进行观察，内部维护了一个所有观察信息对象的数组(NSHashTable).开发者不会直接调用该类。
 FBKVOController        面对开发者使用,定义一些添加观察者和观察事件的添加和删除的 API 接口.以及检测到 KVO 变化的block 回调等.
 内部是通过FBKVOShareController这个单例类来进行观察。
 
 ### 使用
 
 如果我们不用 FBKVOController，那么原生上使用 KVO 方法如下。
``` objc
 [self.textView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
 
```
 
使用 FBKVOController 的方法

``` objc
[self.KVOController observe:self.textView keyPath:@"contentSize" options:NSKeyValueObservingOptionNew block:^(id observer, id object, NSDictionary *change) {
        id newValue = change[NSKeyValueChangeNewKey];
    }];

```

### KVOController 流程分析
1.self.KVOController 我们在 NSObject+FBKVOController 分类中添加了一个KVOController 属性，并在 get 方法中判断是否是在该值，不存在的话则创建一个KVOController并保存起来。
2.addObserver forKeyPath Options context 方法，这个是 FBKVOController对外暴露的 public API ，添加要观察的对象和其 keyPath(属性)。

3. 在 FBController 的 addObserver forKeyPath Options context 方法内部中，创建一个_FBKVOInfo 对象。

FBKVOInfo 的定义如下：
```  objc
@implementation _FBKVOInfo
{
@public
  __weak FBKVOController *_controller;
  NSString *_keyPath;
  NSKeyValueObservingOptions _options;
  SEL _action;
  void *_context;
  FBKVONotificationBlock _block;
  _FBKVOInfoState _state;
}
```

从其源码中可以看到包含这些内容：
一个FBKVOController对象，
要观察的 属性 keyPath,
观察到值发生改变后的回到 block 或者 动作 action.
观察状态 `_FBKVOInfoState`

创建完_FBKVOInfo之后，会调用内部私有方法 `_observe:info:` 方法,从方法名可以看出这个一个私有的，因为方法名前面添加了"_",

4.`_observe:info:` 该方法是线程安全的。

``` objc
  // lock
  pthread_mutex_lock(&_lock);

  NSMutableSet *infos = [_objectInfosMap objectForKey:object];

  // check for info existence
  _FBKVOInfo *existingInfo = [infos member:info];
  if (nil != existingInfo) {
    // observation info already exists; do not observe it again

    // unlock and return
    pthread_mutex_unlock(&_lock);
    return;
  }

  // lazilly create set of infos
  if (nil == infos) {
    infos = [NSMutableSet set];
    [_objectInfosMap setObject:infos forKey:object];
  }

  // add info and oberve
  [infos addObject:info];

  // unlock prior to callout
  pthread_mutex_unlock(&_lock);

  [[_FBKVOSharedController sharedController] observe:object info:info];
```

可以看到，进入方法后，先加锁，然后对数据进行处理，处理完成后再将锁打开。 FBKVOController内部中保存着两个私有变量：

``` objc
{
  // 定义一个保存 (所要观察的对象及其要观察的属性所组成的 info事件数组)的 字典
  NSMapTable<id, NSMutableSet<_FBKVOInfo *> *> *_objectInfosMap;
  
  // 定义一个互斥锁
  pthread_mutex_t _lock;
}
```

举个例子方便理解下：
在一个控制器中有两个 textView,分别为 textView1 和 textView2,

``` objc
[self.KVOController observe:self.textView1 keyPath:@"contentSize" options:NSKeyValueObservingOptionNew block:^(id observer, id object, NSDictionary *change) {
        id newValue = change[NSKeyValueChangeNewKey];
    }];
  
 [self.KVOController observe:self.textView1 keyPath:@"text" options:NSKeyValueObservingOptionNew block:^(id observer, id object, NSDictionary *change) {
        id newValue = change[NSKeyValueChangeNewKey];
    }];
    
 [self.KVOController observe:self.textView2 keyPath:@"contentSize" options:NSKeyValueObservingOptionNew block:^(id observer, id object, NSDictionary *change) {
        id newValue = change[NSKeyValueChangeNewKey];
    }];
 
```
那么_objectInfosMap的数据结构简化如下：
后面的 value 中的 contentSize text 应该是其生成的 info对象，这里只是为了方便理解用contentSize和text来展示。
```
{
textView1:["contentSize","text"],
textView2:["text"],
}

```

再回到源码中，在加锁的这一段源码中，首先看_objectInfosMap中有没有添加过以contentSize为 keypath组成的 info事件，如果有，则解锁返回，如果没有，那么就将其添加到以textView1为 key,value 为info集合中。然后，再调用 FBKVOShareController 来进行最终的事件 KVO.
observe:info：

5.FBKVOShareController 的observe:info： 源码如下：

``` objc
- (void)observe:(id)object info:(nullable _FBKVOInfo *)info
{
  if (nil == info) {
    return;
  }

  // register info
  pthread_mutex_lock(&_mutex);
  [_infos addObject:info];
  pthread_mutex_unlock(&_mutex);

  // add observer
  
  // 这里将使用系统的 KVO 方法,将观察者改为_FBKVOSharedController 实例,而该实例是一个单例.
  [object addObserver:self forKeyPath:info->_keyPath options:info->_options context:(void *)info];

  if (info->_state == _FBKVOInfoStateInitial) {
    info->_state = _FBKVOInfoStateObserving;
  } else if (info->_state == _FBKVOInfoStateNotObserving) {
    // this could happen when `NSKeyValueObservingOptionInitial` is one of the NSKeyValueObservingOptions,
    // and the observer is unregistered within the callback block.
    // at this time the object has been registered as an observer (in Foundation KVO),
    // so we can safely unobserve it.
    [object removeObserver:self forKeyPath:info->_keyPath context:(void *)info];
  }
}
```

可以看到，该方法也是线程安全的，进入方法中先进行加锁操作，然后将 info 添加到_infos数组中，最后还是调用原生的 KVO 方法来检测值发生改变。这个 object 还是我们传进来的 textview1对象，keypath 还是 contextSize,发生改变的的是观察者由 textView 所属的对象->`_FBKVOSharedController` ,context从nil ->info 对象，这是为了方便回调。

``` objc
@implementation _FBKVOSharedController
{
  
  // 这里定义一个 hashTable,用来保存观察事件. 该数组是不对里面的元素进行强引用的.
  NSHashTable<_FBKVOInfo *> *_infos;
  
  // 这里定义一个互斥锁
  pthread_mutex_t _mutex;
}
```
可以看到 `_FBKVOSharedController` 内部也有维护了一个数组：用来保存所有添加了 KVO的 info 数组，还有一个互斥锁。
 
6.在`_FBKVOSharedController` 中添加 `- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context` 回调方法。
                       
``` objc
// 这里接受 KVO 发生改变的处理.
- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context
{
  NSAssert(context, @"missing context keyPath:%@ object:%@ change:%@", keyPath, object, change);

  _FBKVOInfo *info;

  {
    // lookup context in registered infos, taking out a strong reference only if it exists
    pthread_mutex_lock(&_mutex);
    info = [_infos member:(__bridge id)context];
    pthread_mutex_unlock(&_mutex);
  }

  if (nil != info) {

    // take strong reference to controller
    FBKVOController *controller = info->_controller;
    if (nil != controller) {

      // take strong reference to observer
      id observer = controller.observer;
      if (nil != observer) {

        // dispatch custom block or action, fall back to default action
        if (info->_block) {
          NSDictionary<NSKeyValueChangeKey, id> *changeWithKeyPath = change;
          // add the keyPath to the change dictionary for clarity when mulitple keyPaths are being observed
          
          // 这里将 KVO 检测到的value 改变,通过block 回调到对应的使用区域处,供后续业务处理.
          if (keyPath) {
            NSMutableDictionary<NSString *, id> *mChange = [NSMutableDictionary dictionaryWithObject:keyPath forKey:FBKVONotificationKeyPathKey];
            [mChange addEntriesFromDictionary:change];
            changeWithKeyPath = [mChange copy];
          }
          info->_block(observer, object, changeWithKeyPath);
        } else if (info->_action) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
          [observer performSelector:info->_action withObject:change withObject:object];
#pragma clang diagnostic pop
        } else {
          [observer observeValueForKeyPath:keyPath ofObject:object change:change context:info->_context];
        }
      }
    }
  }
}
```


源码中有获取 observer 的操作，这个observer就是 FBController的宿主对象，他是FBController的 weak属性，防止造成循环引用。这里先判断 observer 是否已经dealloc，如果没有再回调。通过 info.block 来回调。这个 info.block 是保存的FBController API 传进来的 block.同理，如果没有 block,那么再判断是否通过 action回调。最后，做了一个保底操作，如果没有通过 block也没 action,则让原来的observer自己来相应change.

简单做了一个流程图如下：

![FBKVOController_flow](https://gitee.com/iminger/CommonImage/raw/master/MarkDown_image/FBKVOController/FBKVOController_flow.png)

7.怎么处理宿主对象 dealloc的时候可以 remove掉 observer?
源码中是在 FBKVOController 的 dealloc 的方法中 remove,因为如果宿主对象要释放，那么其子元素都会走 dealloc.
所以要注意的一点是，我们在使用 FBKVOCOntroller 时，要将其作为宿主对象的属性来使用，防止其自动释放造成 KVO 失败。