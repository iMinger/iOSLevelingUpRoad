# UICollectionViewLeftAlignedLayout 源码阅读

## 为什么要用这个库？
首先我们要知道UICollectionViewFlowLayout 默认的排布方式是：
itemSize 需要我们设置好固定大小或者通过UIcollectionViewFlowLayout的delegate方法来计算并返回.
举个例子： 假如我们设置itemSize固定大小为CGSizeMake(150,150),
同时设置layout.minimumInteritemSpacing = 30,在iPhone6的屏幕上（屏幕宽度为375pt），那么他的排布方式如下：

发现其排布方式是靠左一个，靠右一个，中间会流出75pt的空白。如果我们想让每个item之间间距为minimumInteritemSpacing 固定大小，那该怎么办呢？这时候，就需要我们来自定义layout了，像一些瀑布流layout 一样。
UICollectionViewLeftAlignedLayout 就是帮我们做了自定义layout 的事情，我们直接可以拿来用即可，就像平常用系统的UICollectionViewFlowLayout 一样。
## 阅读源码
这个库看起来比较简单明了，就一个类：`UICollectionViewLeftAlignedLayout`，继承自系统`UICollectionViewFlowLayout`
同时声明一个`UICollectionViewDelegateLeftAlignedLayout`协议，该协议遵循`<UICollectionViewDelegateFlowLayout>`

该类.h文件没有暴露出任何的接口，其使用方式和系统`UICollectionViewFlowLayout`完全一致。

在.m中,写了四个方法：
```
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect；
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath；
- (CGFloat)evaluatedMinimumInteritemSpacingForSectionAtIndex:(NSInteger)sectionIndex；
- (UIEdgeInsets)evaluatedSectionInsetForItemAtIndex:(NSInteger)index;
```
其中
```
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect；
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath；
```

这两个方法是重写系统UICollectionViewFlowLayout的方法，在开发文档中可以看到苹果的描述：
```
// UICollectionView calls these four methods to determine the layout information.
// Implement -layoutAttributesForElementsInRect: to return layout attributes for for supplementary or decoration views, or to perform layout in an as-needed-on-screen fashion.
// Additionally, all layout subclasses should implement -layoutAttributesForItemAtIndexPath: to return layout attributes instances on demand for specific index paths.
// If the layout supports any supplementary or decoration view types, it should also implement the respective atIndexPath: methods for those types.
- (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect; // return an array layout attributes instances for all the views in the given rect
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString*)elementKind atIndexPath:(NSIndexPath *)indexPath;
```

**通过重写这四个方法来计算并排布每个item 的位置和大小。**



## 最后附上这个库的地址
- [UICollectionViewLeftAlignedLayout](https://github.com/mokagio/UICollectionViewLeftAlignedLayout)


