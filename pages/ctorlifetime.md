# 构造函数选择与服务生命周期管理

* [1. 构造函数选择](#1-构造函数选择)
* [2. 生命周期管理](#2-生命周期管理)
    * [2.1 ServiceScope与ServiceScopeFactory](#21-servicescope与servicescopefactory)
    * [2.2 三种生命周期管理模式](#22-三种生命周期管理模式)
    * [2.3 服务实例的回收](#23-服务实例的回收)

ServiceProvider最终提供的服务实例都是根据对应的ServiceDescriptor创建的，对于一个具体的ServiceDescriptor对象来说，如果它的ImplementationInstance和ImplementationFactory属性均为Null，那么ServiceProvider最终会利用其ImplementationType属性返回的真实类型选择一个适合的构造函数来创建最终的服务实例。我们知道服务服务的真实类型可以定义了多个构造函数，那么ServiceProvider针对构造函数的选择会采用怎样的策略呢？

## 1. 构造函数选择
如果ServiceProvider试图通过调用构造函数的方式来创建服务实例，传入构造函数的所有参数必须先被初始化，最终被选择出来的构造函数必须具备一个基本的条件：**ServiceProvider能够提供构造函数的所有参数。**

我们在一个控制台应用中定义了四个服务接口（IFoo、IBar、IBaz和IGux）以及实现它们的四个服务类（Foo、Bar、Baz和Gux）。如下面的代码片段所示，我们为Gux定义了三个构造函数，参数均为我们定义了服务接口类型。为了确定ServiceProvider最终选择哪个构造函数来创建目标服务实例，我们在构造函数执行时在控制台上输出相应的指示性文字。

```csharp
public interface IFoo {}
public interface IBar {}
public interface IBaz {}
public interface IGux {}
 
public class Foo : IFoo {}
public class Bar : IBar {}
public class Baz : IBaz {}
public class Gux : IGux
{
    public Gux(IFoo foo)
    {
        Console.WriteLine("Gux(IFoo)");
    }
 
    public Gux(IFoo foo, IBar bar)
    {
        Console.WriteLine("Gux(IFoo, IBar)");
    }
 
    public Gux(IFoo foo, IBar bar, IBaz baz)
    {
        Console.WriteLine("Gux(IFoo, IBar, IBaz)");
    }
}
```

我们在作为程序入口的Main方法中创建一个ServiceCollection对象并在其中添加针对IFoo、IBar以及IGux这三个服务接口的服务注册，针对服务接口IBaz的注册并未被添加。我们利用由它创建的ServiceProvider来提供针对服务接口IGux的实例，究竟能否得到一个Gux对象呢？如果可以，它又是通过执行哪个构造函数创建的呢？

```csharp
class Program
{
    static void Main(string[] args)
    {       
        new ServiceCollection()
            .AddTransient<IFoo, Foo>()
            .AddTransient<IBar, Bar>()
            .AddTransient<IGux, Gux>()
            .BuildServiceProvider()
            .GetServices<IGux>();
    }
}
```

对于定义在Gux中的三个构造函数来说，ServiceProvider所在的ServiceCollection包含针对接口IFoo和IBar的服务注册，所以它能够提供前面两个构造函数的所有参数。由于第三个构造函数具有一个类型为IBaz的参数，这无法通过ServiceProvider来提供。根据我们上面介绍的第一个原则（ServiceProvider能够提供构造函数的所有参数），Gux的前两个构造函数会成为合法的候选构造函数，那么ServiceProvider最终会选择哪一个呢？

在所有合法的候选构造函数列表中，最终被选择出来的构造函数具有这么一个特征：**每一个候选构造函数的参数类型集合都是这个构造函数参数类型集合的子集。**如果这样的构造函数并不存在，一个类型为InvalidOperationException的异常会被抛出来。根据这个原则，Gux的第二个构造函数的参数类型包括IFoo和IBar，而第一个构造函数仅仅具有一个类型为IFoo的参数，最终被选择出来的会是Gux的第二个构造函数，所有运行我们的实例程序将会在控制台上产生如下的输出结果。

```
Gux(IFoo, IBar)
```

接下来我们对实例程序略加改动。如下面的代码片段所示，我们只为Gux定义两个构造函数，它们都具有两个参数，参数类型分别为IFoo&IBar和IBar&IBaz。在Main方法中，我们将针对IBaz/Baz的服务注册添加到创建的ServiceCollection上。

```csharp
class Program
{
    static void Main(string[] args)
    {       
        new ServiceCollection()
            .AddTransient<IFoo, Foo>()
            .AddTransient<IBar, Bar>()
            .AddTransient<IBaz, Baz>()
            .AddTransient<IGux, Gux>()
            .BuildServiceProvider()
            .GetServices<IGux>();
    }
}
 
public class Gux : IGux
{
    public Gux(IFoo foo, IBar bar) {}
    public Gux(IBar bar, IBaz baz) {}
}
```

对于Gux的两个构造函数，虽然它们的参数均能够由ServiceProvider来提供，但是并没有一个构造函数的参数类型集合能够成为所有有效构造函数参数类型集合的超集，所以ServiceProvider无法选择出一个最佳的构造函数。如果我们运行这个程序，一个InvalidOperationException异常会被抛出来，控制台上将呈现出如下所示的错误消息。

```
Unhandled Exception: System.InvalidOperationException: Unable to activate type 'Gux'. The following constructors are ambigious:
Void .ctor(IFoo, IBar)
Void .ctor(IBar, IBaz)
...
```

## 2. 生命周期管理
生命周期管理决定了ServiceProvider采用怎样的方式创建和回收服务实例。ServiceProvider具有三种基本的生命周期管理模式，分别对应着枚举类型ServiceLifetime的三个选项（Singleton、Scoped和Transient）。对于ServiceProvider支持的这三种生命周期管理模式，Singleton和Transient的语义很明确，前者（Singleton）表示以“单例”的方式管理服务实例的生命周期，意味着ServiceProvider对象多次针对同一个服务类型所提供的服务实例实际上是同一个对象；而后者（Transient）则完全相反，对于每次服务提供请求，ServiceProvider总会创建一个新的对象。那么Scoped又体现了ServiceProvider针对服务实例怎样的生命周期管理方式呢？

### 2.1 ServiceScope与ServiceScopeFactory
ServiceScope为某个ServiceProvider对象圈定了一个“作用域”，枚举类型ServiceLifetime中的Scoped选项指的就是这么一个ServiceScope。在依赖注入的应用编程接口中，ServiceScope通过一个名为IServiceScope的接口来表示。如下面的代码片段所示，继承自IDisposable接口的IServiceScope具有一个唯一的只读属性ServiceProvider返回确定这个服务范围边界的ServiceProvider。ServiceScope由它对应的工厂ServiceScopeFactory来创建，后者体现为具有如下定义的接口IServiceScopeFactory。

```csharp
public interface IServiceScope : IDisposable
{
    IServiceProvider ServiceProvider { get; }
}
 
public interface IServiceScopeFactory
{
    IServiceScope CreateScope();
}
```

若要充分理解ServiceScope和ServiceProvider之间的关系，我们需要简单了解一下ServiceProvider的层级结构。除了直接通过一个ServiceCollection对象创建一个独立的ServiceProvider对象之外，一个ServiceProvider还可以根据另一个ServiceProvider对象来创建，如果采用后一种创建方式，我们指定的ServiceProvider与创建的ServiceProvider将成为一种“父子”关系。

```csharp
internal class ServiceProvider : IServiceProvider, IDisposable
{
    private readonly ServiceProvider _root;
    internal ServiceProvider(ServiceProvider parent)
    {
        _root = parent._root;
    }
    //其他成员
}
```

虽然在ServiceProvider在创建过程中体现了ServiceProvider之间存在着一种树形化的层级结构，但是ServiceProvider对象本身并没有一个指向“父亲”的引用，它仅仅会保留针对根节点的引用。如上面的代码片段所示，针对根节点的引用体现为ServiceProvider类的字段_root。当我们根据作为“父亲”的ServiceProvider创建一个新的ServiceProvider的时候，父子均指向同一个“根”。我们可以将创建过程中体现的层级化关系称为“逻辑关系”，而将ServiceProvider对象自身的引用关系称为“物理关系”，下图清楚地揭示了这两种关系之间的转化。

![ServiceProvider层级关系](../img/ctorlifetime/serviceprovider.png)

由于ServiceProvider自身是一个内部类型，我们不能采用调用构造函数的方式根据一个作为“父亲”的ServiceProvider创建另一个作为“儿子”的ServiceProvider，但是这个目的可以间接地通过创建ServiceScope的方式来完成。如下面的代码片段所示，我们首先创建一个独立的ServiceProvider并调用其GetService<T>方法获得一个ServiceScopeFactory对象，然后调用后者的CreateScope方法创建一个新的ServiceScope，它的ServiceProvider就是前者的“儿子”。

```csharp
class Program
{
    static void Main(string[] args)
    {
        IServiceProvider serviceProvider1 = new ServiceCollection().BuildServiceProvider();
        IServiceProvider serviceProvider2 = serviceProvider1.GetService<IServiceScopeFactory>().CreateScope().ServiceProvider;
 
        object root = serviceProvider2.GetType().GetField("_root", BindingFlags.Instance| BindingFlags.NonPublic).GetValue(serviceProvider2);
        Debug.Assert(object.ReferenceEquals(serviceProvider1, root));        
    }
}
```

如果读者朋友们希望进一步了解ServiceScope的创建以及它和ServiceProvider之间的关系，我们不妨先来看看作为IServiceScope接口默认实现的内部类型ServiceScope的定义。如下面的代码片段所示，ServiceScope仅仅是对一个ServiceProvider对象的简单封装而已。值得一提的是，当ServiceScope的Dispose方法被调用的时候，这个被封装的ServiceProvider的同名方法同时被执行。

```csharp
internal class ServiceScope : IServiceScope
{
    private readonly ServiceProvider _scopedProvider;
    public ServiceScope(ServiceProvider scopedProvider)
    {
        this._scopedProvider = scopedProvider;
    }
 
    public void Dispose()
    {
        _scopedProvider.Dispose();
    }
 
    public IServiceProvider ServiceProvider
    {
        get {return _scopedProvider; }
    }
}
```

IServiceScopeFactory接口的默认实现类型是一个名为ServiceScopeFactory的内部类型。如下面的代码片段所示，ServiceScopeFactory的只读字段“_provider”表示当前的ServiceProvider。当CreateScope方法被调用的时候，这个ServiceProvider的“子ServiceProvider”被创建出来，并被封装成返回的ServiceScope对象。

```csharp
internal class ServiceScopeFactory : IServiceScopeFactory
{
    private readonly ServiceProvider _provider;
    public ServiceScopeFactory(ServiceProvider provider)
    {
        _provider = provider;
    }
 
    public IServiceScope CreateScope()
    {
        return new ServiceScope(new ServiceProvider(_provider));
    }
}
```

### 2.2 三种生命周期管理模式
只有在充分了解ServiceScope的创建过程以及它与ServiceProvider之间的关系之后，我们才会对ServiceProvider支持的三种生命周期管理模式（Singleton、Scope和Transient）具有深刻的认识。就服务实例的提供方式来说，它们之间具有如下的差异：

* Singleton：ServiceProvider创建的服务实例保存在作为根节点的ServiceProvider上，所有具有同一根节点的所有ServiceProvider提供的服务实例均是同一个对象。
* Scoped：ServiceProvider创建的服务实例由自己保存，所以同一个ServiceProvider对象提供的服务实例均是同一个对象。
* Transient：针对每一次服务提供请求，ServiceProvider总是创建一个新的服务实例。

在一个控制台应用中定义了如下三个服务接口（IFoo、IBar和IBaz）以及分别实现它们的三个服务类(Foo、Bar和Baz)。

```csharp
public interface IFoo {}
public interface IBar {}
public interface IBaz {}
 
public class Foo : IFoo {}
public class Bar : IBar {}
public class Baz : IBaz {}
```

现在我们在作为程序入口的Main方法中创建了一个ServiceCollection对象，并采用不同的生命周期管理模式完成了针对三个服务接口的注册(IFoo/Foo、IBar/Bar和IBaz/Baz分别Transient、Scoped和Singleton)。我们接下来针对这个ServiceCollection对象创建了一个ServiceProvider（root），并采用创建ServiceScope的方式创建了它的两个“子ServiceProvider”（child1和child2）。

```csharp
class Program
{
    static void Main(string[] args)
    {
        IServiceProvider root = new ServiceCollection()
            .AddTransient<IFoo, Foo>()
            .AddScoped<IBar, Bar>()
            .AddSingleton<IBaz, Baz>()
            .BuildServiceProvider();
        IServiceProvider child1 = root.GetService<IServiceScopeFactory>().CreateScope().ServiceProvider;
        IServiceProvider child2 = root.GetService<IServiceScopeFactory>().CreateScope().ServiceProvider;
 
        Console.WriteLine("ReferenceEquals(root.GetService<IFoo>(), root.GetService<IFoo>() = {0}",ReferenceEquals(root.GetService<IFoo>(), root.GetService<IFoo>()));
        Console.WriteLine("ReferenceEquals(child1.GetService<IBar>(), child1.GetService<IBar>() = {0}",ReferenceEquals(child1.GetService<IBar>(), child1.GetService<IBar>()));
        Console.WriteLine("ReferenceEquals(child1.GetService<IBar>(), child2.GetService<IBar>() = {0}",ReferenceEquals(child1.GetService<IBar>(), child2.GetService<IBar>()));
        Console.WriteLine("ReferenceEquals(child1.GetService<IBaz>(), child2.GetService<IBaz>() = {0}",ReferenceEquals(child1.GetService<IBaz>(), child2.GetService<IBaz>()));
    }
}
```
为了验证ServiceProvider针对Transient模式是否总是创建新的服务实例，我们利用同一个ServiceProvider（root）获取针对服务接口IFoo的实例并进行比较。为了验证ServiceProvider针对Scope模式是否仅仅在当前ServiceScope下具有“单例”的特性，我们先后比较了同一个ServiceProvider（child1）和不同ServiceProvider（child1和child2）两次针对服务接口IBar获取的实例。为了验证具有“同根”的所有ServiceProvider针对Singleton模式总是返回同一个服务实例，我们比较了两个不同child1和child2两次针对服务接口IBaz获取的服务实例。如下所示的输出结构印证了我们上面的论述。

```
ReferenceEquals(root.GetService<IFoo>(), root.GetService<IFoo>()         = False
ReferenceEquals(child1.GetService<IBar>(), child1.GetService<IBar>()     = True
ReferenceEquals(child1.GetService<IBar>(), child2.GetService<IBar>()     = False
ReferenceEquals(child1.GetService<IBaz>(), child2.GetService<IBaz>()     = True
```

### 2.3 服务实例的回收
ServiceProvider除了为我们提供所需的服务实例之外，对于由它提供的服务实例，它还肩负起回收之责。这里所说的回收与.NET自身的垃圾回收机制无关，仅仅针对于自身类型实现了IDisposable接口的服务实例，所谓的回收仅仅体现为调用它们的Dispose方法。ServiceProvider针对服务实例所采用的回收策略取决于服务注册时采用的生命周期管理模式，具体采用的服务回收策略主要体现为如下两点：

* 注册服务采用Singleton模式，由某个ServiceProvider提供的服务实例其回收工作由作为根的ServiceProvider负责，后者的Dispose方法被调用的时候，这些服务实例的Dispose方法会自动执行。
* 注册服务采用其他模式（Scope或者Transient），ServiceProvider自行承担由它提供的服务实例的回收工作，当它的Dispose方法被调用的时候，这些服务实例的Dispose方法会自动执行。

在一个控制台应用中定义了如下三个服务接口（IFoo、IBar和IBaz）以及三个实现它们的服务类（Foo、Bar和Baz），这些类型具有相同的基类Disposable。Disposable实现了IDisposable接口，我们在Dispose方法中输出相应的文字以确定对象回收的时机。

```csharp
public interface IFoo {}
public interface IBar {}
public interface IBaz {}
 
public class Foo : Disposable, IFoo {}
public class Bar : Disposable, IBar {}
public class Baz : Disposable, IBaz {}
 
public class Disposable : IDisposable
{
    public void Dispose()
    {
        Console.WriteLine("{0}.Dispose()", this.GetType());
    }
}
```

我们在作为程序入口的Main方法中创建了一个ServiceCollection对象，并在其中采用不同的生命周期管理模式注册了三个相应的服务（IFoo/Foo、IBar/Bar和IBaz/Baz分别采用Transient、Scoped和Singleton模式）。我们针对这个ServiceCollection创建了一个ServiceProvider（root），以及它的两个“儿子”（child1和child2）。在分别通过child1和child2提供了两个服务实例（child1：IFoo， child2：IBar/IBaz）之后，我们先后调用三个ServiceProvider（child1=>child2=>root）的Dispose方法。

```csharp
class Program
{
    static void Main(string[] args)
    {
        IServiceProvider root = new ServiceCollection()
            .AddTransient<IFoo, Foo>()
            .AddScoped<IBar, Bar>()
            .AddSingleton<IBaz, Baz>()
            .BuildServiceProvider();
        IServiceProvider child1 = root.GetService<IServiceScopeFactory>().CreateScope().ServiceProvider;
        IServiceProvider child2 = root.GetService<IServiceScopeFactory>().CreateScope().ServiceProvider;
 
        child1.GetService<IFoo>();
        child1.GetService<IFoo>();
        child2.GetService<IBar>();
        child2.GetService<IBaz>();
 
        Console.WriteLine("child1.Dispose()");
        ((IDisposable)child1).Dispose();
 
        Console.WriteLine("child2.Dispose()");
        ((IDisposable)child2).Dispose();
 
        Console.WriteLine("root.Dispose()");
        ((IDisposable)root).Dispose();
    }
}
```

该程序运行之后会在控制台上产生如下的输出结果。从这个结果我们不难看出由child1提供的两个采用Transient模式的服务实例的回收实在child1的Dispose方法执行之后自动完成的。当child2的Dispose方法被调用的时候，对于由它提供的两个服务对象来说，只有注册时采用Scope模式的Bar对象被自动回收了，至于采用Singleton模式的Baz对象的回收工作，是在root的Dispose方法被调用之后自动完成的。

```
child1.Dispose()
Foo.Dispose()
Foo.Dispose()
child2.Dispose()
Bar.Dispose()
root.Dispose()
Baz.Dispose()
```

了解ServiceProvider针对不同生命周期管理模式所采用的服务回收策略还会帮助我们正确的使用它。具体来说，当我们在使用一个现有的ServiceProvider的时候，由于我们并不能直接对它实施回收（因为它同时会在其它地方被使用），如果直接使用它来提供我们所需的服务实例，由于这些服务实例可能会在很长一段时间得不到回收，进而导致一些内存泄漏的问题。如果所用的是一个与当前应用具有相同生命周期（ServiceProvider在应用终止的时候才会被回收）的ServiceProvider，而且提供的服务采用Transient模式，这个问题就更加严重了，这意味着每次提供的服务实例都是一个全新的对象，但是它永远得不到回收。

为了解决这个问题，我想很多人会想到一种解决方案，那就是按照如下所示的方式显式地对提供的每个服务实例实施回收工作。实际上这并不是一种推荐的编程方式，因为这样的做法仅仅确保了服务实例对象的Dispose方法能够被及时调用，但是ServiceProvider依然保持着对服务实例的引用，后者依然不能及时地被GC回收。

```csharp
public void DoWork(IServiceProvider serviceProvider)
{
    using (IFoobar foobar = serviceProvider.GetService<IFoobar>())
    {
        // ...
    }
}
```

由于提供的服务实例总是被某个ServiceProvider引用着[[1]](#comment)（直接提供服务实例的ServiceProvider或者是它的根），所以服务实例能够被GC从内存及时回收的前提是引用它的ServiceProvider及时地变成垃圾对象。要让提供服务实例的ServiceProvider成为垃圾对象，我们就必须创建一个新的ServiceProvider，通过上面的介绍我们知道ServiceProvider的创建可以通过创建ServiceScope的方式来实现。除此之外，我们可以通过回收ServiceScope的方式来回收对应的ServiceProvider，进而进一步回收由它提供的服务实例（仅限Transient和Scoped模式）。下面的代码片段给出了正确的编程方式。

```csharp
public void DoWork(IServiceProvider serviceProvider)
{
    using (IServiceScope serviceScope = serviceProvider.GetService<IServiceScopeFactory>().CreateScope())
    {
        IFoobar foobar = serviceScope.ServiceProvider.GetService<IFoobar>();
        // ...
    }
}
```

接下来我们通过一个简单的实例演示上述这两种针对服务回收的编程方式之间的差异。我们在一个控制台应用中定义了一个继承自IDisposable的服务接口IFoobar和实现它的服务类Foobar。如下面的代码片段所示，为了确认对象真正被GC回收的时机，我们为Foobar定义了一个析构函数。在该析构函数和Dispose方法中，我们还会在控制台上输出相应的指导性文字。

```csharp
public interface IFoobar: IDisposable
{}
 
public class Foobar : IFoobar
{
    ~Foobar()
    {
        Console.WriteLine("Foobar.Finalize()");
    }
 
    public void Dispose()
    {
        Console.WriteLine("Foobar.Dispose()");
    }
}
```

在作为程序入口的Main方法中，我们创建了一个ServiceCollection对象并采用Transient模式将IFoobbar/Foobar注册其中。借助于通过该ServiceCollection创建的ServiceProvider，我们分别采用上述的两种方式获取服务实例并试图对它实施回收。为了强制GC试试垃圾回收，我们显式调用了GC的Collect方法。

```csharp
class Program
{
    static void Main(string[] args)
    {
        IServiceProvider serviceProvider = new ServiceCollection()
            .AddTransient<IFoobar, Foobar>()
            .BuildServiceProvider();
 
        serviceProvider.GetService<IFoobar>().Dispose();
        GC.Collect();
 
        Console.WriteLine("----------------");
        using (IServiceScope serviceScope = serviceProvider.GetService<IServiceScopeFactory>().CreateScope())
        {
            serviceScope.ServiceProvider.GetService<IFoobar>();
        }
        GC.Collect();
 
        Console.Read();
    }
}
```

该程序执行之后会在控制台上产生如下所示的输出结果。从这个结果我们可以看出，如果我们使用现有的ServiceProvider来提供所需的服务实例，后者在GC进行垃圾回收之前并不会从内存中释放。如果我们利用现有的ServiceProvider创建一个ServiceScope，并利用它所在的ServiceProvider来提供我们所需的服务实例，GC是可以将其从内存中释放出来的。

```
Foobar.Dispose()
----------------
Foobar.Dispose()
Foobar.Finalize()
```


<small id='comment'>
[1] 对于分别采用 Scoped和Singleton模式提供的服务实例，当前ServiceProvider和根ServiceProvider分别具有对它们的引用。如果采用Transient模式，只有服务类型实现了IDisposable接口，当前ServiceProvider才需要对它保持引用以完成对它们的回收，否则没有任何一个ServiceProvider保持对它们的引用。
<small>

> 参考文献
http://www.cnblogs.com/artech/p/asp-net-core-di-life-time.html