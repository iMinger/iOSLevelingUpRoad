# iOS 阿拉伯语的 RTL适配历程

首先要知道一点，iOS 9.0 之前是默认不支持阿拉伯语序的，所以 iOS 9.0之前的项目如果想要支持 RTL,那么就比较麻烦了，需要我们全部自己用代码来实现RTL效果，也就不用往下看了。从这里开始往下，默认为项目是基于 iOS 9.0 之上的。

## 全局UI布局方式的更改

```
if (isRTL()) {
        UIView.appearance.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    } else {
        UIView.appearance.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
}
```

而这个 isRTL() 是个内联函数，返回BOOL值，是否是 RTL布局。这个值应该与我们工程中用户所选的语言直接相关。

## collectionView 适配
UICollectionView 在 UISemanticContentAttributeForceRightToLeft 环境下，不同的 iOS 版本可能会出现不同的现象。现象之一是 indexpath.row = 0 的第一个元素会放在最左边，最后一个元素在最右边，而此时UICollectionView的起始位置在最右面，造成了顺序的不对。等等情况。为了使UICollectionView 能够适应多版本的iOS 版本及机型，我们需要重写UICollectionViewFlowLayout 的一个方法。flipsHorizontallyInOppositeLayoutDirection是指开启 一个布尔值，指示水平坐标系是否在适当的时间自动翻转。 这个属性是默认关闭的 如果发生无法反转的话,我们需要这样打开


swift
```
extension HorizontalCollectionViewFlowLayout { 
    open override var flipsHorizontallyInOppositeLayoutDirection: Bool { 
         return true 
    }
}

```

OC 需要重写一个类来继承UICollectionViewFlowLayout ，然后重写该干方法

```
- (BOOL)flipsHorizontallyInOppositeLayoutDirection {
    return YES;
}

```


## UILabel 文字适配
两个问题：
1.LTR默认情况下,文字居左对齐.
  RTL下，文字应该居右对齐。
2.文字异常 Unicode字符串

针对第一个问题，我们可以在实例化 UILabel 的时候，更改label.textAlignment = isRTL()? NSTextAlignmentRight : NSTextAlignmentLeft;
为了不每次实例化 label 的时候都重写一遍，我们可以写一个 UILabel 的分类，默认帮其实现以下该方法。如下：

```
#import "UILabel+FitTRL.h"

@implementation UILabel (FitTRL)
+ (void)load {
    [self wm_siwzzleWithOriginalSEL:@selector(initWithFrame:) withSEL:@selector(rtl_initWithFrame:)];
}

- (instancetype)rtl_initWithFrame:(CGRect)frame
{
    if ([self rtl_initWithFrame:frame]) {
        self.textAlignment = isRTL()? NSTextAlignmentRight : NSTextAlignmentLeft;
    }
    return self;
}
@end

```

第二个问题。
Unicode 字符串由于阅读习惯的差异（阿拉伯语从右往左阅读，其他语言从左往右阅读），所以字符的排序是不一样的，普通语言左边是第一个字符，阿拉伯语右边是第一个字符。如果是单纯某种文字，不管是阿拉伯文还是英文还是汉语，系统已经帮我们做好了适配。那么他是怎么实现的呢？对于一个 string ,系统会用第一个字符来决定当前是 LTR还是 RTL.
那么问题来了，当 string 是混排情况下（阿拉伯语和其他语言混排），会发生错乱，因为是根据第一个字符来决定语序的。

举个例子：
假设有一个这样的字符串@"小明بدأ في متابعتك"（翻译过来为：小明关注了你），在阿拉伯语的情况下，由于阅读顺序是从右往左，我们希望他显示为@"بدأ في متابعتك小明"。然而按照系统的适配方案，是永远无法达到我们期望的。
如果"小明"放前面，第一个字符是中文，系统识别为LTR，从左往右排序，显示为@"小明بدأ في متابعتك"。
如果"小明"放后面，第一个字符是阿拉伯语，系统识别为RTL，从右往左排序，依然显示为@"小明بدأ في متابعتك"。
为了适配这种情况，可以在字符串前面加一些不会显示的字符，强制将字符串变为LTR或者RTL。

在字符串前面添加"\u202B"表示RTL，加"\u202A"LTR。
注意： 添加 "\u202B" 或者 "\u202A" 之后，虽然字符串表面看起来没发生变化，但是毕竟是添加了字符，新的字符串的 range 会发生改变，长度会 +1. 所以，在我们对一些字符串进行添加 Attribute的时候，取 range 不要固定写死，而是要用 subString 从 totalSring 中取，这样才不会发生错误。
