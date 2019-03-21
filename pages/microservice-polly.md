# 熔断降级

## 1. 熔断降级
熔断就是“保险丝”。当出现某些状况时,切断服务,从而防止应用程序不断地尝试执行可能会失败的操作给系统造成“雪崩”,或者大量的超时等待导致系统卡死。

熔断降级在这里只是一种统称，泛指微服务的异常处理策略。简单来将就是出现当服务出现某些故障时按照设定执行某些相应的操作，避免因局部服务故障对整体系统的影响。出现某种故障执行设定的动作，这称之为“策略”。

降级的目的是当某个服务提供者发生故障的时候,向调用方返回一个错误响应或者替代响应。例如，调用联通接口服务器发送短信失败之后,改用移动短信服务器发送,如果移动短信服务器也失败,则改用电信短信服务器,如果还失败,则返回“失败”响应;在从推荐商品服务器加载数据的时候,如果失败,则改用从缓存中加载,如果缓存中也加载失败,则返回一些本地替代数据。

## 2. Polly 简介
.Net Core 中有一个被.Net 基金会认可的库 [Polly](https://github.com/App-vNext/Polly),可以用来简化熔断降级的处理。主要功能:降级(FallBack);重试(Retry);断路器(Circuit-breaker);超时检测(Timeout);缓存(Cache);

Polly介绍参考 https://www.cnblogs.com/CreateMyself/p/7589397.html

Polly 的策略由“故障”和“动作”两部分组成。“故障”包括异常、超时、返回值错误等情况。“动作”包括 FallBack(降级)、重试(Retry)、熔断(Circuit-breaker)等。

策略用来执行可能会有有故障的业务代码,当业务代码出现“故障”中情况的时候就执行“动作”。

## 3. Polly 使用
[Polly](https://www.nuget.org/packages/Polly/)提供了Nuget包，执行`dotnet add package Polly`安装即可。

### 3.1 异常处理
常用的异常处理策略包括 FallBack(降级)、重试(Retry)、熔断(Circuit-breaker).
### 3.1.1 降级

降级处理允许服务出现指定故障时执行指定的降级操作。**故障被降级处理后不会再抛出异常。**

以下代码当发生`ArgumentException`异常的时候,执行`Fallback`代码。在`Execute()`中执行可能导致故障的业务代码。

```csharp
await policy.handle<argumentexception>() //故障
    .fallbackasync(async _ => // 动作
    {
        // 执行策略动作
        console.writeline("执行策略动作");
    }, async ex =>
    {
        // 记录异常信息
        console.writeline(ex.message);
    })
    .executeasync(() =>
    {
        //执行业务代码
        console.writeline("开始业务");
        throw new argumentexception("出现参数错误异常");
        console.writeline("结束业务");
    });
```
如果出现了`Handle`中未约定的异常，异常会被抛出，可以使用`Handle<Exception>`来处理所有类型的异常。也可以使用`Or`方法处理多种异常。
```csharp
await Policy.Handle<ArgumentOutOfRangeException>()
    .Or<ArgumentNullException>()
    .Or<NullReferenceException>()
    .FallbackAsync(async _ => Console.WriteLine("策略动作"))
    .ExecuteAsync( () =>
    {
        Console.WriteLine("开始业务");
        throw new NullReferenceException();
    });
```

如果策略的业务代码中有返回值。可以使用泛型的Policy&lt;T&gt;类。
```csharp
var value = await Policy<string>
    .Handle<Exception>()
    .FallbackAsync(async _ =>
    {
        Console.WriteLine("执行出错");
        return await Task.FromResult("降级返回值");
    })
    .ExecuteAsync(async () =>
    {
        Console.WriteLine("开始业务");
        throw new Exception();
        return await Task.FromResult("正常返回值");
    });

Console.WriteLine(value);
```


`Fallback`有很多重载，可根据不同策略灵活使用。如只处理异常信息中包含某些关键字异常。
```csharp
await Policy
    .Handle<Exception>(ex => ex.Message.Contains("haha")) //故障
    .FallbackAsync(async _ => Console.WriteLine("策略动作"))
    .ExecuteAsync(async () =>
    {
        Console.WriteLine("开始业务");
        throw new ArgumentException("haha");
        Console.WriteLine("结束业务");
    });
```

### 3.1.2 重试

重试处理允许服务出现指定故障时按照策略进行重试。**重试操作并不会处理异常，重试过程中会忽略异常，重试完成后会继续抛出异常。**

```csharp
await Policy
    .Handle<Exception>()
    .RetryAsync(3)
    .ExecuteAsync(async () =>
    {
        Console.WriteLine("开始任务");
        if (DateTime.Now.Second % 10 != 0)
            throw new Exception("出错");

        Console.WriteLine("完成任务");
    });
```

方法|含义
:-|:-
Retry(n)|不指定n则默认重试一次
RetryForever()|一直重试直到成功
WaitAndRetry()|等待指定时间后重试。可实现“如果出错等待100ms再试还不行再等150ms秒等效果
WaitAndRetryForever|等待指定时间重试，直到成功

### 3.1.3 熔断
出现N次**连续**错误,则把“熔断器”(保险丝)熔断,等待一段时间,等待这段时间内如果再`Execute`则直接抛出`BrokenCircuitException`异常,而不再去尝试调用业务代码。等待时间过去之后,再执行Execute的时候如果又错了(一次就够了),那么继续熔断一段时间,否则就恢复正常。跟iPhone的屏幕解锁密码错误重试机制类似，不同的是这里等待时间是固定的。

这样就避免一个服务已经不可用了,还是疯狂的对其进行请求给系统造成更大压力。**熔断操作并不会处理异常**。

```csharp
await Policy
    .Handle<Exception>()
    .CircuitBreakerAsync(5, TimeSpan.FromSeconds(5)) //连续出错5次之后熔断5秒
    .ExecuteAsync(async () =>
    {
        //... 业务代码
        throw new Exception("出错");
    });
```

## 3.2 超时处理

Timeout 定义超时故障策略。Execute 超过指定时间后就会抛出 TimeoutRejectedException。用于处理请求网络接口,避免接口长期没有响应造成系统卡死等情况。

一般超时策略需要结合异常处理策略使用。

```csharp
await Policy.TimeoutAsync(2, TimeoutStrategy.Pessimistic)
    .ExecuteAsync(async () =>
    {
        Console.WriteLine("开始业务");
        //异步方法中使用Thread.Sleep()不会触发超时
        await Task.Delay(3000); //将抛出 TimeoutRejectedException
    });
```

`TimeoutStrategy`指定超时处理方式，有悲观(`Pessimistic`)和乐观(`Optimistic`)两种处理方式。乐观处理会由系统决定如何进行后续操作，可能不会抛出超时异常，可控性较差，一般情况下多使用悲观方式。

## 3.3 组合策略

一般情况下我们会使用 Wrap 组合多种策略。Wrap方法组合策略顺序是由外而内，执行策略是由内而外。内层的故障如果没有被处理则会抛出到外层。

```csharp
//重试策略
var policyRetry = Policy
    .Handle<Exception>()
    .RetryAsync(5);

//熔断策略
var policyCb = Policy
    .Handle<Exception>()
    .CircuitBreakerAsync(3, TimeSpan.FromSeconds(5));//生产中熔断次数一般要大于重试策略次数，此处设定仅为测试策略顺序

//降级策略
var policyFb = Policy
    .Handle<Exception>()
    .FallbackAsync(
        async _ => Console.WriteLine("异常处理"),
        async ex => Console.WriteLine(ex.Message)
    );

//超时策略
var policyTimeout = Policy.TimeoutAsync(2, TimeoutStrategy.Pessimistic);

//组合以上策略
var policy = Policy.WrapAsync(policyFb, policyRetry, policyCb, policyTimeout);

await policy.ExecuteAsync(async () =>
{
    Console.WriteLine("开始业务");
    await Task.Delay(3000);
    Console.WriteLine("完成业务");// 超时异常被处理后不会阻止后续执行
});
```

上面代码策略组合发挥作用时顺序是 超时->熔断->重试->降级。代码执行到`Thread.Sleep(3000)`触发超时策略，抛出超时异常，异常会触发重试策略，重试策略忽略超时异常并重试执行，重试第三3次时会触发之前加入的熔断策略，抛出熔断异常，熔断异常则被外层的降级策略所捕捉处理，最终做降级处理。

**一般情况下熔断策略设定的熔断次数要大于重试策略设定的重试次数，否则重试策略会被熔断**。上面代码设定的熔断次数小于重试次数近为验证策略执行顺序。

## 4. 熔断降级框架
了解了Polly的基础知识之后，我们可以利用Polly来做服务的熔断降级处理，保证整体系统的稳定性。
我们可以在可能出现问题的API方法中使用Polly做相应的熔断降级处理，但直接使用 Polly,会造成业务代码中混杂大量的业务无关代码。

我们可以利用AOP思想，在需要做熔断降级处理的API方法上使用使用拦截器，API方法中只负责写业务代码，所有的熔断降级操作在拦截器中完成即可。这里可以直接使用一套开源的.NET平台的拦截器框架[`AspectCore`](https://www.nuget.org/packages/AspectCore.Core)。目前同时支持.NET Framework 4.5+和.NET Core。

### 4.1 AspectCore
我们简单演示一下AspectCore的使用。
#### 1) 创建拦截器
创建自定义拦截器继承`AbstractInterceptorAttribute`，并重写Invoke方法。

```csharp
public class MyInterceptorAttribute : AbstractInterceptorAttribute
{
    //被拦截方法触发invoke方法
    public override async Task Invoke(AspectContext context, AspectDelegate next)
    {
        try
        {
            Console.WriteLine("Before method call");
            await next(context); //执行被拦截的方法
        }

        catch
        {
            Console.WriteLine("Method threw an exception!");
        }

        finally
        {
            Console.WriteLine("After method call");
        }
    }
}
```

#### 2) 使用拦截器
在需要拦截的方法上打上拦截器标记即可。AspectCore要求拦截器使用方法所在类必须是public修饰的并且方法必须标记为虚方法。因为其运行时会动态创建拦截器使用类的子类并重写拦截的方法，原理与EF的实体模型处理方式类似。

```csharp
public class Person
{
    [MyInterceptor]
    public virtual void SayHi(string name)
    {
        Console.WriteLine($"Hi {name}");
    }
}
```

#### 3) 测试拦截器
```
using (var proxyGenerator = new ProxyGeneratorBuilder().Build())
{
    //创建代理类
    var person = proxyGenerator.CreateClassProxy<Person>();
    person.SayHi("Colin");
}
```
这里不能`new Person()`对象,而必须使用生成器创建对象才能使拦截器产生效，因为拦截器通过动态创建子类来实现。

### 4.2 封装熔断降级框架
熟悉了以上拦截器工作原理，我们就可以在拦截器的Invoke方法中使用Polly实现熔断降级了。

这里我们就仿照Spring Cloud 中的 Hystrix 来封装一个简单的熔断降级框架。具体实现参阅 https://github.com/yangzhongke/RuPeng.HystrixCore

#### 1) 创建拦截器
```csharp
[AttributeUsage(AttributeTargets.Method)]
public class HystrixCommandAttribute : AbstractInterceptorAttribute
{
    /// <summary>
    /// 最多重试几次，如果为0则不重试
    /// </summary>
    public int MaxRetryTimes { get; set; } = 0;

    /// <summary>
    /// 重试间隔的毫秒数
    /// </summary>
    public int RetryIntervalMilliseconds { get; set; } = 100;

    /// <summary>
    /// 是否启用熔断
    /// </summary>
    public bool EnableCircuitBreaker { get; set; } = false;

    /// <summary>
    /// 熔断前出现允许错误几次
    /// </summary>
    public int ExceptionsAllowedBeforeBreaking { get; set; } = 3;

    /// <summary>
    /// 熔断多长时间（毫秒）
    /// </summary>
    public int MillisecondsOfBreak { get; set; } = 1000;

    /// <summary>
    /// 执行超过多少毫秒则认为超时（0表示不检测超时）
    /// </summary>
    public int TimeOutMilliseconds { get; set; } = 0;

    /// <summary>
    /// 缓存多少毫秒（0表示不缓存），用“类名+方法名+所有参数ToString拼接”做缓存Key
    /// </summary>

    public int CacheTtlMilliseconds { get; set; } = 0;

    private static ConcurrentDictionary<MethodInfo, AsyncPolicy> policies =
        new ConcurrentDictionary<MethodInfo, AsyncPolicy>();

    private static readonly Microsoft.Extensions.Caching.Memory.IMemoryCache MemoryCache
        = new Microsoft.Extensions.Caching.Memory.MemoryCache(
            new Microsoft.Extensions.Caching.Memory.MemoryCacheOptions());

    /// <summary>
    /// 
    /// </summary>
    /// <param name="fallBackMethod">降级的方法名</param>
    public HystrixCommandAttribute(string fallBackMethod)
    {
        FallBackMethod = fallBackMethod;
    }

    public string FallBackMethod { get; set; }

    public override async Task Invoke(AspectContext context, AspectDelegate next)
    {
        //一个HystrixCommand中保持一个policy对象即可
        //其实主要是CircuitBreaker要求对于同一段代码要共享一个policy对象
        //根据反射原理，同一个方法的MethodInfo是同一个对象，但是对象上取出来的HystrixCommandAttribute
        //每次获取的都是不同的对象，因此以MethodInfo为Key保存到policies中，确保一个方法对应一个policy实例
        policies.TryGetValue(context.ServiceMethod, out var policy);
        lock (policies) //因为Invoke可能是并发调用，因此要确保policies赋值的线程安全
        {
            if (policy == null)
            {
                policy = Policy.NoOpAsync(); //创建一个空的Policy
                if (EnableCircuitBreaker)
                {
                    policy = policy.WrapAsync(Policy.Handle<Exception>()
                        .CircuitBreakerAsync(ExceptionsAllowedBeforeBreaking,
                            TimeSpan.FromMilliseconds(MillisecondsOfBreak)));
                }

                if (TimeOutMilliseconds > 0)
                {
                    policy = policy.WrapAsync(Policy.TimeoutAsync(
                        () => TimeSpan.FromMilliseconds(TimeOutMilliseconds),
                        Polly.Timeout.TimeoutStrategy.Pessimistic));
                }

                if (MaxRetryTimes > 0)
                {
                    policy = policy.WrapAsync(Policy.Handle<Exception>().WaitAndRetryAsync(MaxRetryTimes,
                        i => TimeSpan.FromMilliseconds(RetryIntervalMilliseconds)));
                }

                var policyFallBack = Policy
                    .Handle<Exception>()
                    .FallbackAsync(async (ctx, t) =>
                    {
                        var aspectContext = (AspectContext) ctx["aspectContext"];
                        var fallBackMethod = context.ImplementationMethod.DeclaringType?.GetMethod(FallBackMethod);
                        var fallBackResult = fallBackMethod?.Invoke(context.Implementation, context.Parameters);
                        //不能如下这样，因为这是闭包相关，如果这样写第二次调用Invoke的时候context指向的
                        //还是第一次的对象，所以要通过Polly的上下文来传递AspectContext
                        //context.ReturnValue = fallBackResult;
                        aspectContext.ReturnValue = fallBackResult;
                        await Task.CompletedTask;
                    }, async (ex, t) =>
                    {
                        //TODO:记录触发降级的异常信息
                    });

                policy = policyFallBack.WrapAsync(policy);
                //放入
                policies.TryAdd(context.ServiceMethod, policy);
            }
        }

        //把本地调用的AspectContext传递给Polly，主要给FallbackAsync中使用，避免闭包的坑
        var pollyCtx = new Context {["aspectContext"] = context};

        //Install-Package Microsoft.Extensions.Caching.Memory
        if (CacheTtlMilliseconds > 0)
        {
            //用类名+方法名+参数的下划线连接起来作为缓存key
            var cacheKey = "HystrixMethodCacheManager_Key_" + context.ImplementationMethod.DeclaringType
                                                            + "." + context.ImplementationMethod +
                                                            string.Join("_", context.Parameters);
            //尝试去缓存中获取。如果找到了，则直接用缓存中的值做返回值
            if (MemoryCache.TryGetValue(cacheKey, out var cacheValue))
            {
                context.ReturnValue = cacheValue;
            }
            else
            {
                //如果缓存中没有，则执行实际被拦截的方法
                await policy.ExecuteAsync(ctx => next(context), pollyCtx);
                //存入缓存中
                using (var cacheEntry = MemoryCache.CreateEntry(cacheKey))
                {
                    cacheEntry.Value = context.ReturnValue;
                    cacheEntry.AbsoluteExpiration = DateTime.Now + TimeSpan.FromMilliseconds(CacheTtlMilliseconds);
                }
            }
        }
        else //如果没有启用缓存，就直接执行业务方法
        {
            await policy.ExecuteAsync(ctx => next(context), pollyCtx);
        }
    }
}
```
#### 2) 使用拦截器

```csharp
public class Person //需要public类
{
    [HystrixCommand(nameof(Hello1FallBackAsync), MaxRetryTimes = 3, EnableCircuitBreaker = true)]
    public virtual async Task<string> HelloAsync(string name) //需要是虚方法
    {
        Console.WriteLine("尝试执行HelloAsync" + name);
        string s = null;
        s.ToString();
        return "ok" + name;
    }

    [HystrixCommand(nameof(Hello2FallBackAsync))]
    public virtual async Task<string> Hello1FallBackAsync(string name)
    {
        Console.WriteLine("Hello降级1" + name);
        String s = null;
        s.ToString();
        return "fail_1";
    }

    public virtual async Task<string> Hello2FallBackAsync(string name)
    {
        Console.WriteLine("Hello降级2" + name);

        return "fail_2";
    }

    [HystrixCommand(nameof(AddFall), EnableCircuitBreaker = true)]
    public virtual int Add(int i, int j)
    {
        string s = null;
        s.ToString();
        return i + j;
    }

    public int AddFall(int i, int j)
    {
        Console.WriteLine($"降级执行{nameof(AddFall)}");
        return 0;
    }

    [HystrixCommand(nameof(TestFallBackAsync), TimeOutMilliseconds = 1000)]
    public virtual async Task TestAsync(int i)
    {
        Console.WriteLine("Test" + i);
        await Task.Delay(2000);
    }

    public async virtual Task TestFallBackAsync(int i)
    {
        Console.WriteLine("超时降级");
    }
}
```

#### 3) 测试拦截器
```csharp
using (var proxyGenerator = new ProxyGeneratorBuilder().Build())
{
    var p = proxyGenerator.CreateClassProxy<Person>();
    //降级测试
    Console.WriteLine(p.Add(1, 2));

    //重试，连续降级测试
    Console.WriteLine(await p.HelloAsync("Colin"));

    //熔断测试
    while (true)
    {
        Console.WriteLine(p.Add(1, 2));
        await Task.Delay(500);
    }

    //超时测试
    await p.TestAsync(1);
}
```

### 4.3 熔断框架依赖注入
经过以上封装之后我们就可以方便的对API方法使用Polly熔断降级框架了。然而每次都要使用ProxyGenerator来创建对象依然比较繁琐,我们可以使用依赖注入来解决这些问题。

借助依赖注入,可以简化代理类对象的创建,不用再自己调用 `ProxyGenerator` 进行代理类对象创建。AspectCore为我们提供了[`AspectCore.Extensions.DependencyInjection`](https://www.nuget.org/packages/AspectCore.Extensions.DependencyInjection/)扩展来实现DI。

```csharp
public interface IPerson
{
    // 仅声明业务方法
    string SayHi(string name);
}

public class Person : IPerson
{
    // 业务实现
    [HystrixCommand(nameof(SayHiFallback))]
    public virtual string SayHi(string name)
    {
        return $"Hi {name.ToUpper()}";
    }

    // 降级处理
    public string SayHiFallback(string name)
    {
        return $"Hi new friend";
    }
}

// 返回值从 void 改为 IServiceProvider
public IServiceProvider ConfigureServices(IServiceCollection services)
{
    services.AddSingleton<IPerson,Person>(); //注册"熔断处理"过的安全服务
    return services.BuildAspectInjectorProvider(); //让aspectcore接管DI
}
```

AspectCore拦截器只能在`ProxyGenerator`创建的代理类中起作用，而WebAPI中Controller的创建是Asp.Net Core框架来负责的,所以在API接口中使用熔断拦截器无效。通常的做法是在API接口中接收用户请，然后交给业务逻辑层来处理，业务逻辑层对象则是由AspectCore的创建并注入到接口层的所以可以在业务逻辑层中启用熔断拦截器。

```csharp
[Route("api/[controller]")]
public class TestController : ControllerBase
{
    private readonly IPerson _person;

    public TestController(IPerson person)
    {
        _person = person;
    }

    [HttpGet("{name?}")]
    public ActionResult<string> Get(string name)
    {
        return _person.SayHi(name);
    }
}
```

每个"熔断处理"过的服务都要在`ConfigureServices`中注入，如果服务表数量较多，每次手动注入比较繁琐，而这些服务一般都在业务逻辑层中，我们可以自定义一个方法来反射遍历业务逻辑层程序集中使用了熔断拦截器的服务对象进行一次性注入。

```csharp
public IServiceProvider ConfigureServices(IServiceCollection services)
{
    RegisterServices(services, Assembly.Load("Xiaoyang.TemplateService.Bll.Implement"));// Bll程序集中所有熔断处理的服务一次性注入
    return services.BuildAspectInjectorProvider(); //让aspectcore接管DI
}

// 注册"熔断安全"服务
private void RegisterServices(IServiceCollection services, Assembly assembly, bool hystrixOnly = true)
{
    foreach (var type in assembly.GetExportedTypes())
    {
        //要求业务实现类的第一个接口实现必须是其业务接口。可以实际情况自行约定规则。
        var interfaceType = type.GetInterfaces().FirstOrDefault();
        if (interfaceType == null)
            continue;

        if (hystrixOnly)
        {
            var hasHystrix = type.GetMethods()
                .Any(m => m.GetCustomAttribute(typeof(HystrixCommandAttribute)) != null);

            if (!hasHystrix)
                continue;
        }

        services.AddSingleton(interfaceType, type);
    }
}
```
