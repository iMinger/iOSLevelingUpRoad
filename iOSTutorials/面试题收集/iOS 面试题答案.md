# 内存管理
- 1.什么情况下使用weak,和assign 有什么不同？
什么情况下使用`weak`关键字：
    1. `weak` 是为了打破循环引用而使用的。可以用来修饰代理，`block`外的对象等。
    2. 在自身已经对它进行过一次强引用的情况下，没有必要再强引用一次，此时也是会用`weak`,例如自定义IBoutlet 控件属性一般设置为weak

    不同点:
    1.`weak`: 此特质表明该属性（对象）定义了一种“非拥有关系”（nonowning relationship）.为这种属性设置新值时，设置方法既不保留新值，也不释放旧值。此特质同assign类似， 然而在属性所指的对象遭到摧毁时，属性值也会清空(nil out)。 而 assign 的“设置方法”只会执行针对“纯量类型” (scalar type，例如 `CGFloat` 或 `NSlnteger` 等)的简单赋值操作。
    2.从修饰对象范围来看，`assign` 可以用非 OC 对象,而 `weak` 必须用于 OC 对象.  `assign` : 现在主要是修饰基本数据类型。
- 2.runtime 如何实现weak 属性？ （weak 变量的自动置nil）

要想实现weak 属性，首先要搞清楚weak 属相的特点：
>  此特质表明该属性（对象）定义了一种“非拥有关系”（nonowning relationship）.为这种属性设置新值时，设置方法既不保留新值，也不释放旧值。此特质同assign类似， 然而在属性所指的对象遭到摧毁时，属性值也会清空(nil out)。 而 assign 的“设置方法”只会执行针对“纯量类型” (scalar type，例如 `CGFloat` 或 `NSlnteger` 等)的简单赋值操作。

那么runtime 如何实现weak 变量的自动置为nil？
>  runtime 对注册的类， 会进行布局，对于 weak 对象会放入一个 hash 表中。 用 weak 指向的对象内存地址作为 key，当此对象的引用计数为0的时候会 dealloc，假如 weak 指向的对象内存地址是a，那么就会以a为键， 在这个 weak 表中搜索，找到所有以a为键的 weak 对象，从而设置为 nil。

（注：在下文的《使用runtime Associate方法关联的对象，需要在主对象dealloc的时候释放么？》里给出的“对象的内存销毁时间表”也提到__weak引用的解除时间。）

先看runtime 里面源码的实现：

```
/**
* The internal structure stored in the weak references table. 
* It maintains and stores
* a hash set of weak references pointing to an object.
* If out_of_line==0, the set is instead a small inline array.
*/
#define WEAK_INLINE_COUNT 4
struct weak_entry_t {
   DisguisedPtr<objc_object> referent;
   union {
       struct {
           weak_referrer_t *referrers;
           uintptr_t        out_of_line : 1;
           uintptr_t        num_refs : PTR_MINUS_1;
           uintptr_t        mask;
           uintptr_t        max_hash_displacement;
       };
       struct {
           // out_of_line=0 is LSB of one of these (don't care which)
           weak_referrer_t  inline_referrers[WEAK_INLINE_COUNT];
       };
   };
};

/**
* The global weak references table. Stores object ids as keys,
* and weak_entry_t structs as their values.
*/
struct weak_table_t {
   weak_entry_t *weak_entries;
   size_t    num_entries;
   uintptr_t mask;
   uintptr_t max_hash_displacement;
}; 
```

具体完整实现参照 objc/objc-weak.h 。

我们可以设计一个函数（伪代码）来表示上述机制：

objc_storeWeak(&a, b)函数：

objc_storeWeak函数把第二个参数--赋值对象（b）的内存地址作为键值key，将第一个参数--weak修饰的属性变量（a）的内存地址（&a）作为value，注册到 weak 表中。如果第二个参数（b）为0（nil），那么把变量（a）的内存地址（&a）从weak表中删除，

你可以把objc_storeWeak(&a, b)理解为：objc_storeWeak(value, key)，并且当key变nil，将value置nil。

在b非nil时，a和b指向同一个内存地址，在b变nil时，a变nil。此时向a发送消息不会崩溃：在Objective-C中向nil发送消息是安全的。

而如果a是由 assign 修饰的，则： 在 b 非 nil 时，a 和 b 指向同一个内存地址，在 b 变 nil 时，a 还是指向该内存地址，变野指针。此时向 a 发送消息极易崩溃。

下面我们将基于objc_storeWeak(&a, b)函数，使用伪代码模拟“runtime如何实现weak属性”：

```// 使用伪代码模拟：runtime如何实现weak属性
// http://weibo.com/luohanchenyilong/
// https://github.com/ChenYilong

 id obj1;
 objc_initWeak(&obj1, obj);
/*obj引用计数变为0，变量作用域结束*/
 objc_destroyWeak(&obj1);
```
下面对用到的两个方法objc_initWeak和objc_destroyWeak做下解释：

总体说来，作用是： 通过objc_initWeak函数初始化“附有weak修饰符的变量（obj1）”，在变量作用域结束时通过objc_destoryWeak函数释放该变量（obj1）。

下面分别介绍下方法的内部实现：

objc_initWeak函数的实现是这样的：在将“附有weak修饰符的变量（obj1）”初始化为0（nil）后，会将“赋值对象”（obj）作为参数，调用objc_storeWeak函数。

```
obj1 = 0；
obj_storeWeak(&obj1, obj);
```
也就是说：

```
weak 修饰的指针默认值是 nil （在Objective-C中向nil发送消息是安全的）
```


然后obj_destroyWeak函数将0（nil）作为参数，调用objc_storeWeak函数。

objc_storeWeak(&obj1, 0);

前面的源代码与下列源代码相同。

```
// 使用伪代码模拟：runtime如何实现weak属性
// http://weibo.com/luohanchenyilong/
// https://github.com/ChenYilong

id obj1;
obj1 = 0;
objc_storeWeak(&obj1, obj);
/* ... obj的引用计数变为0，被置nil ... */
objc_storeWeak(&obj1, 0);

```


objc_storeWeak 函数把第二个参数--赋值对象（obj）的内存地址作为键值，将第一个参数--weak修饰的属性变量（obj1）的内存地址注册到 weak 表中。如果第二个参数（obj）为0（nil），那么把变量（obj1）的地址从 weak 表中删除，在后面的相关一题会详解。

什么时候将weak 修饰的对象置为nil呢，一般来说，是在 weak 指向的对象 dealloc 的时候，在执行此函数时，编译器会以该对象的地址为key去找weak_table 中的值，并将数组里所有weak对象全部置为nil。



#二 runtime
- 1. 使用runtime associate 方法关联的对象，需要在主对象dealloc的时候释放吗？
- 2.分类
    - 1.分类可以添加什么，不可以添加什么？
    - 2.分类中方法和所属主类中的方法名相同的话，会执行哪个？为什么？
    - 3.两个分类中添加了同一个方法，但是方法的实现不同，那么，当调用这个方法时，会执行哪个？为什么？

#三 runloop
- 1.讲讲RunLoop,项目中有用到吗？
- 2.RunLoop 内部实现逻辑？
- 3.RunLoop 和线程的关系？
- 4.timer 与 RunLoop 的关系？
- 5.程序中添加每3秒响应一次的NSTimer,当拖动scrollview时timer可能无法响应时应该怎么解决？
- 6.RunLoop是怎么响应用户操作的，具体流程是怎么样的？
- 7.说说RunLoop的几种状态
- 8.RunLoop的mode的左右是什么？

#源码分析

#杂项
- 1.iOS中常用到的定时器有哪些？分别描述一下其原理以及优缺点？（NSTimer,CADisplayLink,dispatch_source_t）
- 2.iOS 中常用到的锁有哪些？
- 3.iOS 接受通知的线程一定是主线程吗？（或者说iOS 在子线程中发送通知，主线程中接收到处理事件会有什么问题吗？）
    问题：在主线程中A对象监听到通知B后，调用函数functionX。然后我们开启一条子线程，在子线程中发出通知B。现在问A对象执行方法functionX时是在哪个线程？
    ```
    In a multithreaded application, notifications are always delivered in
the thread in which the notification was posted, which may not be the
same thread in which an observer registered itself.
官方文档说：在多线程的程序中，通知会在post通知时所在的线程被传达，这就导致了观察者注册通知的线程和收到通知的线程不在一个线程。
    ```
    经过Xcode 执行后functionX 是在发送通知的子线程执行的。这样的话，如果在子线程中进行UI 操作的话，就会出现crash.因此在这种情况下，需要回到主线程进行操作。
    


#数据结构与算法
- 1.单链表的反转
- 2.判断一个单链表是否有环。