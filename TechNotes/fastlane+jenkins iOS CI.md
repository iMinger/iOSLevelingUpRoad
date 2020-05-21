# jenkins + Fastlane + 蒲公英 自动化CI完整采坑过程记录

## 电脑环境
首先需要确保电脑上已经安装Homebrew、ruby、Xcode命令行工具等环境。
ruby 环境： 最好采用RVM 来安装管理ruby版本。因为，系统默认自带的ruby是系统自己使用的，用户权限很小。每次使用需要sudo,以后更新管理不方便，所以最好用RVM来设置ruby环境。
## Fastlane 的安装
1.命令行安装
```
sudo gem install fastlane -NV
```
2.通过Homebrew 包管理器来安装。
```
brew cask install fastlane
```
注意：最好使用命令行安装，因为上面我们使用RVM来管理ruby 环境，使用命令行安装会将 fastlane 安装到RVM下的ruby下，使用brew安装，会在brew下安装一套ruby环境，然后将fastlane 安装到brew的ruby下。

进入到我们主工程中，和xcworkspace 同级下，使用
```
fastlane init
```

来生成所需要的配置文件。
项目下会多出一个 `fastlane` 文件夹，里面有`Appfile`,`Fastfile`,`pluginfile` 等文件。
`Appfile` : 这里用来填写我们的App 相关信息，方便我们在`Fastlane` 打包脚本文件中用到。
`Fastlane`: fastlane  打包脚本文件。在这里我们填写我们的打包脚本，可以写beta下的打包脚本和testflight和AppStore的打包脚本。

`pluginfile` : 在这里填写 fastlane 打包用到的插件。例如蒲公英 pgyer 等。

下面贴出一份样例：
```
platform :ios do
    before_all do
    last_git_commit
    sh "rm -f ./Podfile.lock"
    cocoapods(use_bundle_exec: false)

end

# 提交一个新的Beta版本
# 确保配置文件是最新
lane :beta do
   
    match(
        type:                       "development" ,#can be appstore,adhoc, development,enterprise
        force_for_new_devices:      true,
        )
    # 开始打包    
    gym(

        #指定项目的scheme名称
        scheme: "HelloWorld",
        xcargs: "ARCHIVE=YES",
        configuration: "Debug", # 指定打包方式，Release 或者 Debug
        export_method: "development", # 打包方式，enterprise, adhoc,appstore,development
        silent: true, # 隐藏没有必要的信息
        clean: true, # 是否清空以前的编译信息 true：是
        workspace: "HelloWorld.xcworkspace",
        include_bitcode: false, #项目中的bitcode 设置
        output_directory: './pgy', # 指定输出文件夹
        output_name: "HelloWorld.ipa", #输出的ipa名称
        export_xcargs: "-allowProvisioningUpdates”, #忽略文件
        
        # We added this right here to make things work
        export_options: {
           compileBitcode: false,  #导出包的时候，关闭 bitcode 选项，这样会节省很多时间。如果打生产环境的包，要开启 bitcode.
        }


        )


         
    # 开始上传蒲公英，
    # 这里因为要使用jenkins进行打包，所以，不能在这里直接进行pgyer 上传，要在jenkins 那里使用shell 进行pgyer上传
    # 如果不使用jenkins,仅在本地使用fastlane 命令来进行打包，则可以在这里使用payer上传。

    # 获取最近一次的提交信息。 最近的一次提交信息中包含author,author_email,message,commit_hash,abbreviated_commit_hash等信息，我们上传的时候只需要message 即可。
    commit = last_git_commit
    pgyer(api_key: "f1d0e3a443xxxxxxxxxxxxxxx", user_key: "e5b41a10a380xxxxxxxxxxxxxx", update_description:commit[:message]) 
    
end


end

```

上面的打包脚本可以更丰富，例如更改build版本号等。

## fastlane match 来管理打包证书。
iOS 开发过程中，证书和配置文件的管理真令人烦躁。在开发过程中，我们可以使用xcode 的automatically manager signing 来自动创建证书及配置文件，这也仅限制开发人员较少的情况。怎么能确保开发团队证书的统一呢？然后我就google到了这篇文章[fastlane之使用match同步证书和配置文件](https://zrocky.com/2018/09/how-to-use-fastlane-match/) 里面讲解的非常清晰，可以直接跳过去观看，下面只是做了一个摘录。

`match` 方案是只创建一份 证书以及pp文件，然后使用Git 在团队内共享他们。

使用步骤：
    1.创建一个git仓库
    2.(非不要)创建一个共享的Apple Developer 账号
    3.进入工程目录执行脚本命令：
    ```
    fastlane match init
    ```
    
  ![](https://zrocky.com/assets/images/post/2018-09-07-match_init.gif)
  
  执行命令后会要求输入git仓库地址，建议使用ssl地址，这样节省验证步骤。
  fastlane match init命令不会获取或修改你的证书和配置文件, 只会在./fastlane目录生成一个Matchfile文件。
  
  Matchfile内配置示例:
  ```
  git_url("https://github.com/fastlane/certificates")
 
app_identifier("tools.fastlane.app")
# username("user@fastlane.tools")
  ```

### 生成证书和配置文件
>在首次运行前, 可以使用fastlane match nuke命令清除现有的配置文件和证书。

你可以使用以下命令来生成证书:
```
# 开发证书及配置文件
fastlane match development 

# 生成证书及内部分发配置文件
fastlane match adhoc

# 生产证书及配置文件
fastlane match appstore
```

![](https://zrocky.com/assets/images/post/2018-09-10-match_appstore_small.gif)

## bundle 管理iOS 项目的ruby 依赖。
为了使我们在本地编辑好的打包文件弄到我们的打包服务器上也可以正常运行，所以，我们要保证我们的打包环境是一致的，所以，我们要约束好打包环境，这就需要bundle 来管理。

进入到我们的工程中，和
```
bundle init
```

这时工程目录下回多出两个文件：Gemfile 和 Gemfile.lock

我们在Gemfile 中可以填写需要的环境依赖。具体可查看 [Bundler 官方文档](https://bundler.io/gemfile.html)

例如：
```
#gem的源地址。
source "https://gems.ruby-china.com"
# ruby 版本
ruby '2.6.3'
gem "fastlane" ,'2.144.0'
gem "cocoapods" 
```
这样以后在打包的时候，先执行 bundle install 确保环境依赖一致，然后在执行 bundle exec fastlane ios beta 就可以正常打包。如果觉得麻烦的话，可以写一个脚本将这两个命令和其他一些命令写在一起，这样，只需要一行执行脚本就可以完整打包了。

到这里，我们就可以使用上面的样例打包脚本打包了。

## jenkins

为了让测试和运行同学自己打出自己需要的版本的包，对于打包这样重复的无技术含量且浪费时间的工作，就交给机器来完成。节省我们开发人员的时间。

### 安装jenkins

首先要安装Java 1.8环境，可以从官网下载最新版。安装好之后，就可以开始安装jenkins.

jenkins 安装方式:
1.jenkins 包下载安装：[jenkins 下载地址](https://jenkins.io/download/)
2.Homebrew 安装。

这里先说一下结论： 建议使用Homebrew 安装。
为什么？ 因为刚开始使用包下载安装方式，默认会在/Users/Shared/下创建一个jenkins 用户。这样一些打包环境啥的就有问题了。

使用Homebrew安装，会在主用户目录下创建一个.jenkins目录.
在命令行通过下面命令开启jenkins
```
jenkins start 
```
如果终端出现
```
INFO	hudson.WebAppMain$3#run: Jenkins is fully up and running
```
说明启动成功，这个时候就可以打开浏览器输入下面地址打开网页。
```
http://localhost:8080/
```
>**注意** --: jenkins 默认占用8080端口 

首先会进入一个页面，让我们输入密码，这个密码的路径用红色标注，在终端打印出这个密码然后复制到这里。

然后会进入自定义插件页面，有两个选项，install suggested plugins 和 Select plugin to install.
建议选择第一个选项，安装的插件会比较全。也可以选择第二个选项，然后自选插件安装，我安装的如下：
插件安装：
Localization：Chinese 中文包插件
Xcode integration
RVM
Environment Injector  环境变量
GitLab
Upload to pgyer       上传蒲公英插件
Qy Wechat / DingTalk  企业微信或者钉钉插件 打包完成通知

在安装插件的过程中，会因为网络而失败。所以，最好在jenkins start 之前，先把终端的网络代理开启一下，增加插件安装的成功率。

### 创建一个job
新建item - 输入一个任务名称 - FreeStyle project
然后点击该item 的配置，进入配置页。

重要的几个步骤如下:
1.源码管理:
选择git选项，Repository URL 处填上我们的仓库ssh地址，下面的Credentials 如果没有设置的话，点击右侧添加，添加凭据页面的类型选择 SSH username with private key。
描述： 随便填写一些方便查找，例如：Minger's RSA秘钥
然后Username 就填上我们在git仓库的用户名，private key :
```
cd .ssh

// 顺序读取文件并输出到 Terminal 窗口，
cat id_rsa_xxxgit
```
将输出的字符串拷贝添加到private key 中。

2.构建环境

选中 Run the build in a RVM-managed environment
这里填写上我们的ruby 版本(因为我们使用RVM 来管理ruby 版本).
如果不设置RVM的ruby 版本的话，在执行 构建脚本额时候`bundle exec fastlane ios beta` 会报 一下错误。

>bundler: command not found: fastlane
Install missing gem executables with `bundle install`
Build step 'Execute shell' marked build as failure

3.构建
点击 增加构建步骤，选择 Execute shell
添加如下命令
```
bundle install
bundle exec fastlane ios beta
```
保存即可。

这样一个item 就构建完成，点击build 就可以开始打包了。

到这里，我们初步的目标就已经完成了，可以让测试和运营同学自己选择分支名打出对应的包了。如果想要更近一步，想要我们在提交代码后主动打包，那么就可以选择 构建触发器了。
### 总结
这一路摸索出来，爬过很多坑，因为现在图床问题还没解决，所以大多以文字叙述方式来替代中间出现的很多现象。以后再补充吧.
### 参考

[fastlane 官方文档](https://docs.fastlane.tools/)
[Bundler 官方文档](https://bundler.io/gemfile.html)
[match 官方文档](https://docs.fastlane.tools/actions/match/)
[为什么我们要使用 RVM / Bundler ？](https://segmentfault.com/a/1190000017478119)
[RVM](https://rvm.io/rvm/install)
[Rvm安装、Ruby升级安装及Cocoapods安装](https://www.jianshu.com/p/934849a5232a)
[管理 iOS 项目的 Ruby 依赖](https://zhuanlan.zhihu.com/p/35756358)
[fastlane之使用match同步证书和配置文件](https://zrocky.com/2018/09/how-to-use-fastlane-match/)