# 网络编程


- URL Loading System
- NSURLConnection
- NSURLSession

- 上传
- 下载
- 断点续传下载

- TCP/IP
    IP协议服务的主要特点是 IP 服务为上层协议提供无状态，无连接，不可靠的服务。
    无状态： 无状态协议是指IP通信双方不同步传输数据的状态信息，所有ip 数据报的发送，传递，接受都是相互独立的、没有上下文关系的。这种服务有点在于简单，高效。 最大的缺点是无法处理乱序和重复的IP数据报，确保IP 数据包完整的工作只能交友上层协议来处理。
    无连接：无连接是指通信双方都不能长久地维持对方的任何信息。上层协议每次发送数据的时候，都需要明确指出对方的ip地址。
    不可靠： 不可靠是指IP协议不能保证IP数据报准确达到接收端，它只承诺尽最大的努力交付。IP模块一旦检测到数据报发送失败，就通知上层协议，而不会试图重传。
    
- TCP 协议三次握手
- 长连接
- HTTP（1.0，2.0）、HTTPS
- 安全
- 接口加密
- 即时通讯
- TCP 和 UDP
- Cookie 和 Session
- POST 和 GET


### 推荐阅读：
#### 自己已经看过的有:
- [HTTPS 基本过程](https://hit-alibaba.github.io/interview/basic/network/HTTPS.html)
- [SSL/TLS 握手过程详解](https://www.jianshu.com/p/7158568e4867)
- [IP协议详解](https://www.jianshu.com/p/58a77f173f71)

#### 还没看过的有:

- [IP，TCP 和 HTTP - objc.io](https://www.objccn.io/issue-10-6/)
- [移动 APP 网络优化概述 - bang](http://blog.cnbang.net/tech/3531/)
- [Networking Overview](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/WorkingWithHTTPAndHTTPSRequests/WorkingWithHTTPAndHTTPSRequests.html)：Provides a basic understanding of how networking software works, and how to avoid common mistakes.
- [Networking Concepts](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/NetworkingConcepts/Introduction/Introduction.html#//apple_ref/doc/uid/TP40012487): Provides a basic explanation of socket-based networking at a conceptual level.
- [Getting Started with Networking, Internet, and Web](https://developer.apple.com/library/content/referencelibrary/GettingStarted/GS_NetworkingInternetWeb/_index.html)
- 《网络是怎样连接的》
- 《图解 HTTP》
- 《图解 TCP/IP》
