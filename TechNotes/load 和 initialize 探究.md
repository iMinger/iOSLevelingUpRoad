# load 和 initialize 探究

## load 
load函数调用特点如下:
 当类被引用进项目的时候就会执行 load 函数(在 main 函数开始执行之前),与这个类是否被调用到无关,每个类的 load 函数只会自动调用一次,由于 load 函数是系统自动加载的,
 因此不需要调用父类的 load 函数,否则父类的 load 函数会被多次执行.
 
 1. 当父类和子类都实现 load 函数时,父类的 load 方法执行顺序要优先于子类.
 2. 当子类未实现 load 方法时,不会调用父类的 load 方法.
 3. 类中的 load 方法执行顺序要优先于类别(category)
 4. 当有多个类别(category) 都实现了 load 方法,这几个 load 方法都会执行,其执行顺序与类别在 compile source 中出现的顺序一致
 5. 当有多个不同的类时,每个类的 load 执行顺序预期在 compile source 中出现的顺序一致.
 
 
## initialize 
initialize 在类或者其子类的第一个方法被调用前调用.即使类文件被引用进项目,但是没有使用,initialize 不会被调用.由于是系统自动调用,也不需要再调用[super initialize].
 否则父类的 initialize 会被多次执行.假如这个类放到代码中,而这段代码并没有被执行,这个函数是不会执行的.
 每个类的 initialize 方法只会被调用一次.
 
  1. 父类的 initiazile 方法会比子类先执行.
  2. 当子类未实现 initialize 方法时,会先调用父类的 initialize 方法,子类实现 initialize 方法时,会覆盖父类的 initialize 方法
  3. 当有多个 category 都实现了 initialize 时,只执行一个 (会执行Compile Sources 列表中最后一个Category 的initialize方法). 根据 category 底层源码可知,将这个类的所有分类的方法按照倒序的方式查找,找到后会直接返回,后面的不再执行.

