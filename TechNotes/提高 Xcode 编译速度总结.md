# 提高 Xcode 编译速度总结

不知道是因为新的 Xcode 的体积越来越大的缘故，还是因为工程越来越大的原因，现在 Xcode 打包的速度越来越慢，所以，开始猎寻 Xcode 打包速度变快的方法。
## 1.适当增加编译线程数来提高编译速度
Xcode 默认使用与 cpu 核数相同的线程来进行编译，但由于编译过程中的 I/O 操作往往比 cpu 运算更多，因此适当的提升线程数可以在一定程度上加快编译速度。

涉及到的命令有：
```

1.获取当前内核数:
sysctl -n hw.ncpu
2.设置编译线程数：
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks 16
3.获取编译线程数：
defaults read com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks
4.显示编译时长：
defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES

```

## 2.PCH 文件的预编译
pch 文件。pch 中引入的头文件会在每个类文件编译的时候再编译一次，所以

```
Build Setting -> Precompile Prefix Header -> YES
```
这一项可以大大缩短编译时间。

## 3.Architectures
`Architectures`: 是指定工程支持的指令集的集合，如果设置多个 architecture，则生成的二进制包会包含多个指令集代码。
`Valid Architectures`:有效的指令集集合，Architectures与Valid Architectures的交集来确定最终的数据包含的指令集代码。

`Build Active Architecture Only` : 指定是否只对当前链接设备所支持的指令集编译，默认 Debug 的时候设置为 YES,Release 的时候设为 NO.Debug设置为 YES时只编译当前的 architecture版本，生成的包只包含当前链接设备的指令集代码。设置为 NO 时，则生成的包包含所有的指令集代码（architectures与Valid Architectures的交集）.所以，为了更快的编译速度，Debug 应设为 YES,而 release 应设为 NO.


## 终极方案:增量编译，ccache