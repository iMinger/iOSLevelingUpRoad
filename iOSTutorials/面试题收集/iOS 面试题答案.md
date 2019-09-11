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
    
    具体可看一下[iOS：三种常见计时器（NSTimer、CADisplayLink、dispatch_source_t）的使用](https://www.cnblogs.com/XYQ-208910/p/6590829.html)
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

# 网络
- 1.TCP 为什么是三次握手和四次挥手？
    
- 2.TCP和UDP 的区别？为什么UDP传输的速率快？

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
- 4.项目国际化方案？
    接口国际化？ 在请求request header 中添加一个 language 字段，将要请求的语言做value传进去。
    时间国际化？ 跟服务端约定好，凡是涉及到时间相关的字段，都要返回时间戳格式。然后通过NSDateFormatter 对象将时间戳转换成可用的字符串，NSDateFormatter 对象里有个TimeZone 属性，默认是取系统当前时区，那么我们要做的是不去setTimeZone.这样获取到的就是当前系统对应的时间，随系统时区切换，时间也会跟着变化。
    字符串国际化？ 字符串加宏。 Localizable.strings 文件生成
    storyboard/xib下的string文件管理
    
    应用内动态更新语言？
        常见的更新语言方式：
        1.reloadRootViewController
        2.通知
        3.预留更新文字的方法。
        方法一代码成本低，改动的地方少。
    
    国际化相关的工具：
    [TCZLocalizableTool](https://github.com/lefex/TCZLocalizableTool)
    
    引用文章：
    [iOS国际化方案---看我就够
](https://www.jianshu.com/p/1550f2835f4f)

- 5.H5与native交互？
    - JavascripCore
        OC与JS的交互如下：
        这个里面主要用到了两个类:JSContext和JSValue.
        - JSContext 
        是JS代码的执行环境，JSContext为JS的执行提供了上下文环境，通过JSCore执行的JS代码都是得通过JSContext来执行
        JSContext 对应于一个JS中的全局对象JSContext对应着一个全局对象，相当于浏览器中的window对象，JSContext中有一个GlobalObject属性，实际上JS代码都是在这个GlobalObject上执行的，但是为了容易理解，可以把JSContext等价于全局对象。
        
        - JSValue 
        JSValue 是对JS值的包装，JS中的值拿到OC中是不能直接使用的，需要包装一下，这个JSValue就是对JS值的包装，一个JSValue对应着一个JS值，这个JS值可能是JS中的number，boolean等基本类型，也可能是对象，函数，设置可以是undefined,或者null，
        就是JS中的var
        
        使用：
        
        JS中的代码
        ```
        var factorial = function (n) {
            if (n < 0)  return;
            if (n = 0)  return 1;
            return n * factorial(n - 1);
        }
        ```
        
        OC中调用这个JS中的函数
        ```
        NSString *factorialScript = [self loadJSFromBundle];
        JSContext context = [[JSContext alloc]init];
        [context evaluateScript:factorialScript];
        JSValue *function = context[@"factorial"];
        JSValue *result = [function callWithArguments:@[@5]];
        NSLog(@"factorial(5) = %d",[result toInt32]);
        ```
        
   JS与OC的交互：
      JS与OC的交互主要是通过两种方式：
      1.Block： 第一种方式是使用block,block 也可以称作闭包函数，使用block可以很方便的将OC中的单个方法暴露给js调用。
      2.JSExport 协议。  
      
    - WebViewJavascriptBridge
        - WebViewJavascriptBridge的使用
            - JS调用OC
                首先需要在OC中注册JS可以调用的方法,registerHandle: 注册，然后JS中调用
            - OC调用JS
                首先JS中得注册OC可以调用的方法，然后OC代码中通过 callHandle调用
        - WebViewJavascriptBridge的原理

- 6.常见的crash有哪些类型？怎么样处理预防？
    - UI非主线程刷新
    - KVO非对称添加删除
    - unrecognized selector
    - 数组（不可变字典进行更改，数组越界，）
    - 字典（不可变字典添加key-value， key 为nil）
    - 字符串
    
    1.UI非主线程刷新。
        当我们在子线程中进行了一些操作后想要刷新UI,但是没有切换线程的操作，例如：在子线程中发送通知，在主线程收到后需的操作其实也是子线程中进行的。即：接受通知后的操作是与发送通知所在的线程是同一个线程。
        可进行的预防措施有:利用runtime，hook view的setNeedsLayout、setNeedsDisplay、setNeedsDisplayInRect、setNeedsUpdateConstraints四个方法，判断当前是否是主线程，如果不是主线程，则跳转到dispatch_get_main_queue 执行。
    
- 7.事件的响应链与传递链。
    
    
    
  
    


#数据结构与算法
- 1.单链表的反转
    分为迭代法和递归法；
    - 迭代法
        思路：1->2->3->4->5->NULL  change: NULL<-1<-2<-3<-4<-5
        把指针反向指就可以了，需要三个指针，preNode,currNode,nextNode,
        1.先保存前一个节点preNode，再将当前一个节点currNode的next指针设为前一个节点preNode
        2.然后当前节点就作为前一个节点，继续迭代。
        ```
        struct ListNode * reverseList(struct ListNode *head) {
            if (head == NULL) return head;
            struct ListNode *pre = NULL;
            struct ListNode *curr = head;
            struct ListNode *next = NULL;
            
            while(curr) {
                //1。首先要保存一下下一个要进行遍历的Node节点，防止curr->next 指针指向别的节点后，找不到下一个要遍历的node节点
                next = curr->next;
                //2. 将curr->next 指针指向上一个节点，进行链表的反转
                curr->next = pre;
                //3.4 步将pre和curr节点后移一个节点，进行下一次的遍历。
                pre = curr;
                curr = next;
            }
            
            // 循环结束，curr == NULL
            // pre 即最后一个节点，也就是新的头节点。
            return pre;
        }
        ```
    - 递归法
- 2.判断一个单链表是否有环。
    快慢指针，快指针一次走两步，慢指针一次走一步，如果有环，那么最终快指针和满指针将会指向同一个node
- 3.十大排序算法。