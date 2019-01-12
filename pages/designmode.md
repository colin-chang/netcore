# 基于IoC的设计模式
* [1. 模板方法（Template Method）](#1-模板方法（template-method）)
* [2. 工厂方法（Factory Method）](#2-工厂方法（factory-method）)
* [3. 抽象工厂（Abstract Factory）](#3-抽象工厂（abstract-factory）)

正如我们在[前面](ioc.md)提到过的，很多人将IoC理解为一种“面向对象的设计模式”，实际上IoC自身不仅与面向对象没有必然的联系，它也算不上是一种设计模式。一般来讲，设计模式提供了一种解决某种具体问题的方案，但是IoC既没有一个针对性的问题领域，其自身没有提供一种可实施的解决方案，所以我更加倾向于将IoC视为一种设计原则，实际上很多我们熟悉的设计模式背后采用了IoC原则。

## 1. 模板方法（Template Method）
提到IoC，很多人首先想到的是DI，但是在我看来与IoC思想最为接近的倒是另一种被称为“模板方法（Template  Method）”的设计模式。模板方法模式与IoC的意图可以说不谋而合，该模式主张将一个可复用的工作流程或者由多个步骤组成的算法定义成模板方法，组成这个流程或者算法的步骤实现在相应的虚方法之中，模板方法根据按照预先编排的流程去调用这些虚方法。所有这些方法均定义在同一个类中，我们可以通过派生该类并重写相应的虚方法达到对流程定制的目的。

对于[控制反转（IoC）](ioc.md)演示的这个MVC的例子，我们可以将整个请求处理流程实现在如下一个MvcEngine类中，请求的监听与接收、目标Controller的激活与执行以及View的呈现分别定义在5个受保护的虚方法中，模板方法StartAsync根据预定义的请求处理流程先后调用这5个方法。

 ```csharp
public class MvcEngine
{
    public async Task StartAsync(Uri address)
    {
        await ListenAsync(address);
        while (true)
        {
            var request = await ReceiveAsync();
            var controller = await CreateControllerAsync(request);
            var view = await ExecuteControllerAsync(controller);
            await RenderViewAsync(view);
        }
    }
    protected virtual Task ListenAsync(Uri address);
    protected virtual Task<Request> ReceiveAsync();
    protected virtual Task<Controller> CreateControllerAsync(Request request);
    protected virtual Task<View> ExecuteControllerAsync(Controller controller);
    protected virtual Task RenderViewAsync(View view);
}
 ```

对于具体的应用来说，如果定义在MvcEngine针对请求的处理方式完全符合它的要求，它只需要创建这个一个MvcEngine对象，然后指定一个对应的基地址调用模板方法StartAsync开启这个MVC引擎即可。如果该MVC引擎处理请求的某个环节不能满足它的要求，它可以创建MvcEngine的派生类，并重写实现该环节的相应虚方法即可。

比如说定义在某个应用程序中的Controller都是无状态的，它希望采用单例（Singleton）的方式重用已经激活的Controller以提高性能，那么它就可以按照如下的方式创建一个自定义的FoobarMvcEngine并按照自己的方式重写

```csharp
public class FoobarMvcEngine : MvcEngine
{
    protected override Task<View> CreateControllerAsync (Request request)
    {
        // <<省略实现>>
    }
}
```

## 2. 工厂方法（Factory Method）
对于一个复杂的流程来说，我们倾向于将组成该流程的各个环节实现在相对独立的组件之中，那么针对流程的定制就可以通过提供定制组件的方式来实现。我们知道23种设计模式之中有一种重要的类型，那就是“创建型模式”，比如常用的“工厂方法”和“抽象工厂”，IoC所体现的针对流程的共享与定制可以通过它们来完成。

所谓的工厂方法，说白了就是在某个类中定义用于提供依赖对象的方法，这个方法可以是一个单纯的虚方法，也可以是具有默认实现的虚方法，至于方法声明的返回类型，可以是一个接口或者抽象类，也可以是未被封闭（Sealed）的具体类型。作为它的派生类型，它可以实现或者重写工厂方法以提供所需的具体对象。

同样以我们的MVC框架为例，我们让独立的组件来完成组成整个请求处理流程的几个核心环节。具体来说，我们针对这些核心组件定义了如下这几个对应的接口。IWebLister接口用来监听、接收和响应请求（针对请求的响应由ReceiveAsync方法返回的HttpContext对象来完成，后者表示针对当前请求的上下文），IControllerActivator接口用于根据当前请求激活目标Controller对象，已经在后者执行完成后做一些释放回收工作。至于IControllerExecutor和IViewRender接口则分别用来完成针对Controller的执行和针对View的呈现。

```csharp
public interface IWebLister
{
    Task ListenAsync(Uri address);
    Task<HttpContext> ReceiveAsync();
}

public interface IControllerActivator
{
    Task<Controller> CreateControllerAsync(HttpContext httpContext);
    Task ReleaseAsync(Controller controller);
}

public interface IControllerExecutor
{
    Task<View> ExecuteAsync(Controller controller, HttpContext httpContext);
}

public interface IViewRender
{
    Task RendAsync(View view, HttpContext httpContext);
}
```

我们在作为MVC引擎的MvcEngine类中定义了四个工厂方法（GetWebListener、GetControllerActivator、GetControllerExecutor和GetViewRenderer）来提供上述这4种组件。这四个工厂方法均为具有默认实现的虚方法，我们可以利用它们提供默认的组件。在用于启动引擎的StartAsync方法中，我们利用这些工厂方法提供的对象来具体完成请求处理流程的各个核心环节。

```csharp
 public class MvcEngine
{
    public async Task StartAsync(Uri address)
    {
        var listener = GetWebLister();
        var activator = GetControllerActivator();
        var executor = GetControllerExecutor();
        var render = GetViewRender();
        await listener.ListenAsync(address);
        while (true)
        {
            var httpContext = await listener.ReceiveAsync();
            var controller = await activator.CreateControllerAsync(httpContext);
            try
            {
                var view = await executor.ExecuteAsync(controller, httpContext);
                await render.RendAsync(view, httpContext);
            }
            finally

            {
                await activator.ReleaseAsync(controller);
            }
        }
    }
    protected virtual IWebLister GetWebLister(); 
    protected virtual IControllerActivator GetControllerActivator();
    protected virtual IControllerExecutor GetControllerExecutor();
    protected virtual IViewRender GetViewRender();
}
  ```

对于具体的应用程序来说，如果需要对请求处理的某个环节进行定制，它需要将定制的操作实现在对应接口的实现类中。在MvcEngine的派生类中，我们需要重写对应的工厂方法来提供被定制的对象。 比如上面提及的以单例模式提供目标Controller对象的实现就定义在SingletonControllerActivator类中，我们在派生于MvcEngine的FoobarMvcEngine类中重写了工厂方法GetControllerActivator使其返回一个SingletonControllerActivator对象。

```csharp
public class SingletonControllerActivator : IControllerActivator
{         
    public Task<Controller> CreateControllerAsync(HttpContext httpContext)
    {
        // <<省略实现>>
    }
    public Task ReleaseAsync(Controller controller) => Task.CompletedTask;
}

public class FoobarMvcEngine : MvcEngine
{
    protected override ControllerActivator GetControllerActivator() => new SingletonControllerActivator();
}
```

## 3. 抽象工厂（Abstract Factory）
虽然工厂方法和抽象工厂均提供了一个“生产”对象实例的工厂，但是两者在设计上却有本质的不同。工厂方法利用定义在某个类型的抽象方法或者虚方法实现了针对单一对象提供方式的抽象，而抽象工厂则利用一个独立的接口或者抽象类来提供一组相关的对象。

具体来说，我们需要定义一个独立的工厂接口或者抽象工厂类，并在其中定义多个的工厂方法来提供“同一系列”的多个相关对象。如果希望抽象工厂具有一组默认的“产出”，我们也可以将一个未被封闭的具体类作为抽象工厂，以虚方法形式定义的工厂方法将默认的对象作为返回值。我们根据实际的需要通过实现工厂接口或者继承抽象工厂类（不一定是抽象类）定义具体工厂类来提供一组定制的系列对象。

现在我们采用抽象工厂模式来改造我们的MVC框架。如下面的代码片段所示，我们定义了一个名为IMvcEngineFactory的接口作为抽象工厂，定义在其中定义了四个方法来提供请求监听和处理过程使用到的4种核心对象。如果MVC提供了针对这四种核心组件的默认实现，我们可以按照如下的方式为这个抽象工厂提供一个默认实现（MvcEngineFactory）。

```csharp
public interface IMvcEngineFactory
{
    IWebLister GetWebLister();
    IControllerActivator GetControllerActivator();
    IControllerExecutor GetControllerExecutor();
    IViewRender GetViewRender();
}

public class MvcEngineFactory： IMvcEngineFactory
{
    IWebLister GetWebLister();
    IControllerActivator GetControllerActivator();
    IControllerExecutor GetControllerExecutor();
    IViewRender GetViewRender();
}
```

现在我们采用抽象工厂模式来改造我们的MVC框架。我们在创建MvcEngine对象可以提供一个具体的IMvcEngineFactory对象，如果没有显式指定，MvcEngine会使用默认的EngineFactory对象。在用于启动引擎的StartAsync方法中，MvcEngine利用IMvcEngineFactory来获取相应的对象协作完整对请求的处理流程。

```csharp
public class MvcEngine
{
    public IMvcEngineFactory EngineFactory { get; }
    public MvcEngine(IMvcEngineFactory engineFactory = null) 
    => EngineFactory = engineFactory??new MvcEngineFactory();
        
    public async Task StartAsync(Uri address)
    {
        var listener = EngineFactory.GetWebLister();
        var activator = EngineFactory.GetControllerActivator();
        var executor = EngineFactory.GetControllerExecutor();
        var render = EngineFactory.GetViewRender();
        await listener.ListenAsync(address);
        while (true)
        {
            var httpContext = await listener.ReceiveAsync();
            var controller = await activator.CreateControllerAsync(httpContext);
            try
            {
                var view = await executor.ExecuteAsync(controller, httpContext);
                await render.RendAsync(view, httpContext);
            }
            finally
            {
                await activator.ReleaseAsync(controller);
            }
        }
    }
}
```

如果具体的应用程序需要采用上面定义的SingletonControllerActivator以单例的模式来激活目标Controller，我们可以按照如下的方式定义一个具体的工厂类FoobarEngineFactory。最终的应用程序将这么一个FoobarEngineFactory对象作为MvcEngine的EngineFactory。

```csharp
public class FoobarEngineFactory : EngineFactory
{
    public override ControllerActivator GetControllerActivator()
    {
        return new SingletonControllerActivator();
    }
}

public class App
{
    static void Main(string[] args)
    {
        Uri address = new Uri("http://0.0.0.0:8080/mvcapp");
        MvcEngine engine     = new MvcEngine(new FoobarEngineFactory());
        engine.Start(address);
    }
}
```

除了上面介绍这三种典型的设计，还有很多其他的设计模式，比如策略模式、观察者模式等等，它们无一不是采用IoC的设计原则。

> 参考文献
https://www.cnblogs.com/artech/p/net-core-di-02.html