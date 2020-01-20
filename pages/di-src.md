# Asp.Net Core 依赖注入源码分析

* [1. 程序启动DI源码解析](#1-程序启动di源码解析)
* [2. 配置文件DI](#2-配置文件di)
    * [2.1 配置文件DI基本使用](#21-配置文件di基本使用)
    * [2.2 配置文件DI源码解析](#22-配置文件di源码解析)

## 1. 程序启动DI源码解析
在[Asp.Net Core 依赖注入使用](#aspnetcoredi.md)之“依赖注入在管道构建过程中的使用”中我们简单的介绍了DI在程序启动中的使用过程，接下来让我们从Asp.Net Core源码角度来深入探讨这一过程。

> 以下分析源码分析基于Asp.Net Core 2.1 https://github.com/aspnet/AspNetCore/tree/release/2.1

1) 定位程序入口

```csharp
public static void Main(string[] args)
{
    CreateWebHostBuilder(args)
        .Build()
        .Run();
}

public static IWebHostBuilder CreateWebHostBuilder(string[] args) =>
    WebHost.CreateDefaultBuilder(args)
        .UseStartup<Startup>();
```
可以看到asp.net core程序实际上是一个控制台程序，运行一个Webhost对象从而启动一个一直运行的监听http请求的任务。

2) 定位IWebHostBuilder实现，路径为src/Hosting/Hosting/src/WebHostBuilder.cs

![IWebHostBuilder实现](https://s2.ax1x.com/2020/01/19/19oLlQ.png)

1) 通过上面的代码我们可以看到首先是通过BuildCommonServices来构建一个ServiceCollection。为什么说这么说呢，先让我们我们跳转到BuidCommonServices方法中看下吧。

![BuildCommonServices构建ServiceCollection](https://s2.ax1x.com/2020/01/19/19oTFf.png)

通过`var services = new ServiceCollection();`创建了一个ServiceCollection然后往services里面注入很多内容，如：WebHostOptions ，IHostingEnvironment ，IHttpContextFactory ，IMiddlewareFactory等。最后这个BuildCommonServices就返回了这个services对象。

4）UseStartup&lt;Startup&gt;()。 在上面的BuildCommonServices方法中也有对IStartup的注入。首先，判断Startup类是否继承于IStartup接口，如果是继承的，那么就可以直接加入在services 里面去，如果不是继承的话，就需要通过ConventionBasedStartup(methods)把method转换成IStartUp后注入到services里面去。结合上面我们的代码，貌似我们平时用的时候注入的方式都是采用后者。

5）回到build方法拿到了BuildCommonServices方法构建的ServiceCollection实例后，通过GetProviderFromFactory(hostingServices) 方法构造出了IServiceProvider 对象。到目前为止，IServiceCollection和IServiceProvider都拿到了。然后根据IServiceCollection和IServiceProvider对象构建WebHost对象。构造了WebHost实例还不能直接返回，还需要通过Initialize对WebHost实例进行初始化操作。那我们看看在初始化函数Initialize中，都做了什么事情吧。

![WebHost](https://s2.ax1x.com/2020/01/19/19T9YT.png)

1) 找到src/Hosting/Hosting/src/Internal/WebHost.cs的Initialize方法。如下图所示：主要就是一个EnsureApplicationServices方法。

![WebHost.Initialize](https://s2.ax1x.com/2020/01/19/1Cmb6S.png)

1) EnsureApplicationServices内容如下：拿到Startup 对象，然后把_applicationServiceCollection 中的对象注入进去。

![EnsureApplicationServices](https://s2.ax1x.com/2020/01/19/19oHfS.png)

1) 至此build中注册的对象以及StartUp中注册的对象都已经加入到依赖注入容器中了，接下来就是Run起来了。这个run的代码在src\Hosting\Hosting\src\WebHostExtensions.cs中，代码如下：

![WebHost.RunAsync](https://s2.ax1x.com/2020/01/19/19ozT0.png)

WebHost执行RunAsync运行web应用程序并返回一个只有在触发或关闭令牌时才完成的任务。这就是我们运行ASP.Net Core程序的时候，看到的那个命令行窗口了，如果不关闭窗口或者按Ctrl+C的话是无法结束的。

## 2. 配置文件DI
除了[Asp.Net Core 依赖注入使用](aspnetcoredi.html#2-依赖服务注册)中提到的服务注册方式。我们还可以通过配置文件进行对象注入。需要注意的是通过**读取配置文件注入的对象采用的是Singleton方式。**

### 2.1 配置文件DI基本使用
1）在appsettings.json里面加入如下内容
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning"
    }
  },
  "Author": {
    "Name":"Colin",
    "Nationality":"China"
  }
}
```
2) Startup类中ConfigureServices中注册TOptions对象
```csharp
services.Configure<Author>(Configuration.GetSection("Author"));//注册TOption实例对象
```
3）消费配置的服务对象,以Controller为例
```csharp
private readonly Author author;
public TestController(IOptions<Author> option)
{
    author = option.Value;
}
```

### 2.2 配置文件DI源码解析

1）在Main方法默认调用了WebHost.CreateDefaultBuilder方法创建了一个IWebHost对象，此方法加载了配置文件并使用一些默认的设置。

```csharp
public static void Main(string[] args)
{
    CreateWebHostBuilder(args)
        .Build()
        .Run();
}

public static IWebHostBuilder CreateWebHostBuilder(string[] args) =>
    WebHost.CreateDefaultBuilder(args)
        .UseStartup<Startup>();
```

2）在src\MetaPackages\src\Microsoft.AspNetCore\WebHost.cs 中查看CreateDefaultBuilder方法源码如下。可以看到这个方法会在ConfigureAppConfiguration 的时候默认加载appsetting文件，并做一些初始的设置，所以我们不需要任何操作，就能加载appsettings 的内容了。

![CreateDefaultBuilder](https://s2.ax1x.com/2020/01/19/19oITP.png)

1) **Asp.Net Core的配置文件是支持热更新的**，即不重启网站也能加载更新。如上图所示只需要在AddJsonFile方法中设置属性reloadOnChange:true即可。

> 参考文献：https://www.cnblogs.com/yilezhu/p/9998021.html