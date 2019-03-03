# 缓存、Session

## 1. 缓存
Asp.Net Core不再支持`HttpContext.Cache`,转而使用[`MemoryCache`](https://docs.microsoft.com/zh-cn/aspnet/core/performance/caching/memory?view=aspnetcore-2.2),这是一种服务端内存缓存。使用方式方式非常简单，在`Startup`的`ConfigureServices`方法中注册服务，需要使用的位置注入`IMemoryCache`对象即可。

除了内存缓存，我们还可以使用Redis等[分布式缓存](https://docs.microsoft.com/zh-cn/aspnet/core/performance/caching/distributed?view=aspnetcore-2.2)

## 2. Session
在Asp.Net Core中使用Session需要首先添加对Session的支持,否则会报错`Session has not been configured for this application or request`。

Session使用步骤：
* 1) 注册服务。`ConfigureServices`中`services.AddSession()`;
* 2) 注册中间件。`Configure`中`app.UseSession()`;
* 3）使用Session

```csharp
HttpContext.Session.SetString("userName","Colin");
string userName = HttpContext.Session.GetString("userName")
```

目前Session默认仅支持存储`int`、`string`和`byte[]`类型，其他复杂类型可以使用json序列化后存储字符串。

TempData也依赖于 Session,所以也要配置 Session。

默认Session为服务器端进程内存储，我们也可以使用Redis做进程外Session。