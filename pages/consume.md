# .Net Core 服务消费

* [1. ServiceProvider](#1-serviceprovider)
* [2. 消费服务](#2-消费服务)
* [3. 服务集合](#3-服务集合)
* [4. 泛型支持](#4-泛型支持)
* [5. 构造函数选择](#5-构造函数选择)

## 1. ServiceProvider
在采用了依赖注入的应用中，我们总是直接利用DI容器直接获取所需的服务实例，换句话说，DI容器起到了一个服务提供者的角色，它能够根据我们提供的服务描述信息提供一个可用的服务对象。

作为一个服务的提供者，ASP.NET Core中的DI容器最终体现为一个IServiceProvider接口。此接口只声明了一个GetService方法以根据指定的服务类型来提供对应的服务实例。

```csharp
public interface IServiceProvider
{
    object GetService(Type serviceType);
}

public static class ServiceCollectionContainerBuilderExtensions
{
    public static ServiceProvider BuildServiceProvider(this IServiceCollection services);
}
```

ASP.NET Core内部真正使用的是一个实现了IServiceProvider接口的内部类型（该类型的名称为“ServiceProvider”），我们不能直接创建该对象，只能间接地通过调用IServiceCollection接口的扩展方法BuildServiceProvider得到它。

由于ASP.NET Core中的ServiceProvider是根据一个代表ServiceDescriptor集合的IServiceCollection对象创建的，当我们调用其GetService方法的时候，它会根据我们提供的服务类型找到对应的ServiceDecriptor对象。如果该ServiceDecriptor对象的ImplementationInstance属性返回一个具体的对象，该对象将直接用作被提供的服务实例。如果ServiceDecriptor对象的ImplementationFactory返回一个具体的委托，该委托对象将直接用作创建服务实例的工厂。如果这两个属性均为Null，ServiceProvider才会根据ImplementationType属性返回的类型调用相应的构造函数创建被提供的服务实例。**ServiceProvider仅仅支持构造器注入，属性注入和方法注入的支持并未提供。**

除了定义在IServiceProvider的这个GetService方法，DI框架为了该接口定了如下这些扩展方法。GetService&lt;T&gt;方法会泛型参数的形式指定了服务类型，返回的服务实例也会作对应的类型转换。如果指定服务类型的服务注册不存在，GetService方法会返回Null，如果调用GetRequiredService或者GetRequiredService&lt;T&gt;方法则会抛出一个InvalidOperationException类型的异常。如果所需的服务实例是必需的，我们一般会调用者两个扩展方法。

```csharp
public static class ServiceProviderServiceExtensions
{
    public static T GetService<T>(this IServiceProvider provider);

    public static T GetRequiredService<T>(this IServiceProvider provider);
    public static object GetRequiredService(this IServiceProvider provider, Type serviceType);
    
    public static IEnumerable<T> GetServices<T>(this IServiceProvider provider);
    public static IEnumerable<object> GetServices(this IServiceProvider provider, Type serviceType);
}
```

## 2. 消费服务
接下来采用实例演示的方式来介绍如何利用ServiceCollection进行服务注册，以及如何利用ServiceCollection创建对应的ServiceProvider来提供我们需要的服务实例。

定义四个服务接口（IFoo、IBar、IBaz和IGux）以及分别实现它们的四个服务类（Foo、Bar、Baz和Gux）如下面的代码片段所示，IGux具有三个只读属性（Foo、Bar和Baz）均为接口类型，并在构造函数中进行初始化。

```csharp
public interface IFoo {}
public interface IBar {}
public interface IBaz {}
public interface IGux
{
    IFoo Foo { get; }
    IBar Bar { get; }
    IBaz Baz { get; }
}
 
public class Foo : IFoo {}
public class Bar : IBar {}
public class Baz : IBaz {}
public class Gux : IGux
{
    public IFoo Foo { get; private set; }
    public IBar Bar { get; private set; }
    public IBaz Baz { get; private set; }
 
    public Gux(IFoo foo, IBar bar, IBaz baz)
    {
        this.Foo = foo;
        this.Bar = bar;
        this.Baz = baz;
    }
}   
```

现在我们在作为程序入口的Main方法中创建了一个ServiceCollection对象，并采用不同的方式完成了针对四个服务接口的注册。具体来说，对于服务接口IFoo和IGux的ServiceDescriptor来说，我们指定了代表服务真实类型的ImplementationType属性，而对于针对服务接口IBar和IBaz的ServiceDescriptor来说，我们初始化的则是分别代表服务实例和服务工厂的ImplementationInstance和ImplementationFactory属性。由于我们调用的是AddSingleton方法，所以四个ServiceDescriptor的Lifetime属性均为Singleton。

```csharp
class Program
{
    static void Main(string[] args)
    {
        IServiceCollection services = new ServiceCollection()
            .AddSingleton<IFoo, Foo>()
            .AddSingleton<IBar>(new Bar())
            .AddSingleton<IBaz>(_ => new Baz())
            .AddSingleton<IGux, Gux>();
 
        IServiceProvider serviceProvider = services.BuildServiceProvider();
        Console.WriteLine("serviceProvider.GetService<IFoo>(): {0}",serviceProvider.GetService<IFoo>());
        Console.WriteLine("serviceProvider.GetService<IBar>(): {0}", serviceProvider.GetService<IBar>());
        Console.WriteLine("serviceProvider.GetService<IBaz>(): {0}", serviceProvider.GetService<IBaz>());
        Console.WriteLine("serviceProvider.GetService<IGux>(): {0}", serviceProvider.GetService<IGux>());
    }
}
```

接下来我们调用ServiceCollection对象的扩展方法BuildServiceProvider得到对应的ServiceProvider对象，然后调用其扩展方法GetService<T>分别获得针对四个接口的服务实例对象并将类型名称其输出到控制台上。运行该程序之后，我们会在控制台上得到如下的输出结果，由此印证ServiceProvider为我们提供了我们期望的服务实例。

```csharp
serviceProvider.GetService<IFoo>(): Foo
serviceProvider.GetService<IBar>(): Bar
serviceProvider.GetService<IBaz>(): Baz
serviceProvider.GetService<IGux>(): Gux
```

## 3. 服务集合
如果我们在调用GetService方法的时候将服务类型指定为IEnumerable<T>，那么返回的结果将会是一个集合对象。除此之外， 我们可以直接调用IServiceProvider如下两个扩展方法GetServeces达到相同的目的。在这种情况下，ServiceProvider将会利用所有与指定服务类型相匹配的ServiceDescriptor来提供具体的服务实例，这些均会作为返回的集合对象的元素。如果所有的ServiceDescriptor均与指定的服务类型不匹配，那么最终返回的是一个空的集合对象。

```csharp
public static class ServiceProviderExtensions
{
    public static IEnumerable<T> GetServices<T>(this IServiceProvider provider);
    public static IEnumerable<object> GetServices(this IServiceProvider provider, Type serviceType);
}
```

值得一提的是，如果ServiceProvider所在的ServiceCollection包含多个具有相同服务类型（对应ServiceType属性）的ServiceDescriptor，当我们**调用GetService方法获取单个服务实例的时候，只有最后一个ServiceDescriptor才是有效的，至于其他的ServiceDescriptor，它们只有在获取服务集合的场景下才有意义。**

我们通过一个简单的实例来演示如何利用ServiceProvider得到一个包含多个服务实例的集合。我们在一个控制台应用中定义了如下一个服务接口IFoobar，两个服务类型Foo和Bar均实现了这个接口。在作为程序入口的Main方法中，我们将针针对服务类型Foo和Bar的两个ServiceDescriptor添加到创建的ServiceCollection对象中，这两个ServiceDescriptor对象的ServiceType属性均为IFoobar。

```csharp
class Program
{
    static void Main(string[] args)
    {
        IServiceCollection serviceCollection = new ServiceCollection()
             .AddSingleton<IFoobar, Foo>()
             .AddSingleton<IFoobar, Bar>();
 
        IServiceProvider serviceProvider = serviceCollection.BuildServiceProvider();
        Console.WriteLine("serviceProvider.GetService<IFoobar>(): {0}", serviceProvider.GetService<IFoobar>());
 
        IEnumerable<IFoobar> services = serviceProvider.GetServices<IFoobar>();
        int index = 1;
        Console.WriteLine("serviceProvider.GetServices<IFoobar>():");
        foreach (IFoobar foobar in services)
        {
            Console.WriteLine("{0}: {1}", index++, foobar);
        }
    }
}
 
public interface IFoobar {}
public class Foo : IFoobar {}
public class Bar : IFoobar {}
```

在调用ServiceCollection对象的扩展方法BuildServiceProvider得到对应的ServiceProvider对象之后，我们先调用其GetService<T>方法以确定针对服务接口IFoobar得到的服务实例的真实类型就是是Foo还是Bar。接下来我们调用ServiceProvider的扩展方法GetServices<T>获取一组针对服务接口IFoobar的服务实例并将它们的真是类型打印在控制台上。该程序运行后将会在控制台上生成如下的输出结果。

```
serviceProvider.GetService<IFoobar>(): Bar
serviceProvider.GetServices<IFoobar>():
Foo
Bar
```

## 4. 泛型支持
ServiceProvider提供的服务实例不仅限于普通的类型，它对泛型服务类型同样支持。在针对泛型服务进行注册的时候，我们可以将服务类型设定为携带具体泛型参数的“关闭泛型类型”（比如IFoobar&lt;IFoo,IBar&gt;），除此之外服务类型也可以是包含具体泛型参数的“开放泛型类型”（比如IFoo&lt;,&gt;）。前者实际上还是将其视为非泛型服务来对待，后者才真正体现了“泛型”的本质。

比如我们注册了某个泛型服务接口IFoobar&lt;,&gt;与它的实现类Foobar&lt;,&gt;之间的映射关系，当我们指定一个携带具体泛型参数的服务接口类型IFoobar&lt;IFoo,IBar&gt;并调用ServiceProvider的GetService方法获取对应的服务实例时，ServiceProvider会针对指定的泛型参数类型(IFoo和IBar)来解析与之匹配的实现类型（可能是Foo和Baz）并得到最终的实现类型（Foobar&lt;Foo,Baz&gt;）。

我们同样利用一个简单的控制台应用来演示基于泛型的服务注册与提供方式。如下面的代码片段所示，我们定义了三个服务接口（IFoo、IBar和IFoobar&lt;T1,T2&gt;）和实现它们的三个服务类（Foo、Bar个Foobar&lt;T1,T2&gt;）,泛型接口具有两个泛型参数类型的属性（Foo和Bar），它们在实现类中以构造器注入的方式被初始化。

```csharp
class Program
{
    static void Main(string[] args)
    {
        IServiceProvider serviceProvider = new ServiceCollection()
            .AddTransient<IFoo, Foo>()
            .AddTransient<IBar, Bar>()
            .AddTransient(typeof(IFoobar<,>), typeof(Foobar<,>))
            .BuildServiceProvider();
 
        Console.WriteLine("serviceProvider.GetService<IFoobar<IFoo, IBar>>().Foo: {0}", serviceProvider.GetService<IFoobar<IFoo, IBar>>().Foo);
        Console.WriteLine("serviceProvider.GetService<IFoobar<IFoo, IBar>>().Bar: {0}", serviceProvider.GetService<IFoobar<IFoo, IBar>>().Bar);
    }
}
 
public interface IFoobar<T1, T2>
{
    T1 Foo { get; }
    T2 Bar { get; }
}
public interface IFoo {}
public interface IBar {}
 
public class Foobar<T1, T2> : IFoobar<T1, T2>
{
    public T1 Foo { get; private set; }
    public T2 Bar { get; private set; }
    public Foobar(T1 foo, T2 bar)
    {
        this.Foo = foo;
        this.Bar = bar;
    }
}
public class Foo : IFoo {}
public class Bar : IBar {}
```

在作为入口程序的Main方法中，我们创建了一个ServiceCollection对象并采用Transient模式注册了上述三个服务接口与对应实现类型之间的映射关系，对于泛型服务IFoobar&lt;T1,T2&gt;/Foobar&lt;T1,T2&gt;来说，我们指定的是不携带具体泛型参数的开放泛型类型IFoobar&lt;,&gt;/Foobar&lt;,&gt;。利用此ServiceCollection创建出对应的ServiceProvider之后，我们调用后者的GetService方法并指定IFoobar&lt;IFoo,IBar&gt;为服务类型。得到的服务对象将会是一个Foobar&lt;Foo,Bar&gt;对象，我们将它的Foo和Bar属性类型输出于控制台上作为验证。该程序执行之后将会在控制台上产生下所示的输出结果。

```
serviceProvider.GetService<IFoobar<IFoo, IBar>>().Foo: Foo 
serviceProvider.GetService<IFoobar<IFoo, IBar>>().Bar: Bar 
```

## 5. 构造函数选择
当ServiceProvider利用ImplementationType属性返回的真实类型的构造函数来创建最终的服务实例时，如果服务的真实类型定义了多个构造函数，那么ServiceProvider针对构造函数的选择会采用怎样的策略呢？

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

> 参考文献
* http://www.cnblogs.com/artech/p/asp-net-core-di-register.html
* http://www.cnblogs.com/artech/p/asp-net-core-di-life-time.html
* https://www.cnblogs.com/artech/p/net-core-di-08.html