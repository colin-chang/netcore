# 异步编程模型
* [1. EAP](#1-eap)
* [2. APM](#2-apm)
    * [2.1 简单使用](#21-简单使用)
    * [2.2 同步调用](#22-同步调用)
    * [2.3 委托异步调用](#23-委托异步调用)
* [3. TPL](#3-tpl)
    * [3.1 简单使用](#31-简单使用)
    * [3.2 同步调用](#32-同步调用)
    * [3.3 并行异步](#33-并行异步)
    * [3.4 自定义异步方法](#34-自定义异步方法)
    * [3.5 异常处理](#35-异常处理)

.Net 中很多的类接口设计的时候都考虑了多线程问题,简化了多线程程序的开发。不用自己去写`WaitHandler`等这些底层的代码。随着历史的发展,这些类的接口设计演化经历过三种不同的风格:`EAP`、`APM`和`TPL`。

## 1. EAP
`EAP`是`Event-based Asynchronous Pattern`(基于事件的异步模型)的简写。

```csharp
// 注：WebClient类在.Net Core中不被支持，推荐使用HttpClient替代
var wc = new WebClient();
wc.DownloadStringCompleted += (s,e)=>{
    MessageBox.Show(e.Result);
};

wc.DownloadStringAsync(new Uri("https://www.baidu.com"));
```

`EAP`特点是一个异步方法配一个`***Completed`事件。使用简单，但业务复杂的时比较麻烦,比如下载 A 成功后再下载 B,如果下载 B 成功再下载 C,否则就下载 D,会出现类似JS的多层回调函数嵌套的问题。

## 2. APM
`APM`是`Asynchronous Programming Model`(异步编程模型)的缩写。是.Net 旧版本中广泛使用的异步编程模型。

`APM`方法名字以 `BeginXXX` 开头,调用结束后需要 `EndXXX`回收资源。

.Net 中有如下的常用类支持`APM`:`Stream`、`SqlCommand`、`Socket` 等。

### 2.1 简单使用

```csharp
//异步非阻塞方式
var fs = File.OpenRead("/Users/zhangcheng/test.txt");
var buffer = new byte[10 * 1024];
fs.BeginRead(buffer, 0, buffer.Length, ar =>
{
    using (fs)
    {
        fs.EndRead(ar);
        Console.WriteLine(Encoding.UTF8.GetString(buffer));
    }
}, fs);
```

### 2.2 同步调用
`APM`方法名字以 `BeginXXX` 开头,返回类型为`IAsyncResult`的对象，该对象有一个`AsyncWaitHandle`属性是用来等待异步任务执行结束的一个同步信号。如果等待`AsyncWaitHandle`则，异步会阻塞并转为同步执行。

```csharp
// 同步阻塞方式
using(var fs = File.OpenRead("/Users/zhangcheng/test.txt"))
{
    var buffer = new byte[10*1024];
    var aResult =
        fs.BeginRead(buffer, 0, buffer.Length, null, null);
    aResult.AsyncWaitHandle.WaitOne(); //同步等待任务执行结束
    fs.EndRead(aResult);

    Console.WriteLine(Encoding.UTF8.GetString(buffer));
}
```

### 2.3 委托异步调用
旧版.NET中,委托类型具有`Invoke`和`BeginInvoke`两个方法分别用于同步和异步调用委托。其中`BeginInvoke`使用的就是APL风格。

**通过`BeginInvoke`异步调用委托在.NET Core中不被支持。**

```csharp
var addDel = new Func<int, int, string>((a, b) =>
{
    Thread.Sleep(500); //模拟耗时操作
    return (a + b).ToString();
});


//委托同步调用
var res = addDel.Invoke(1, 2);
res = addDel(1, 2); //简化写法


//委托异步调用
addDel.BeginInvoke(1, 2, ar =>
{
    var result = addDel.EndInvoke(ar);
    Console.WriteLine(result);
}, addDel);
```

## 3. TPL
### 3.1 简单使用

`TPL`是`Task Parallel Library`(并行任务库存)是.Net 4.0 之后带来的新特性,更简洁,更方便。现在.Net 平台下已经广泛使用。

```csharp
static async Task Test()
{
    using (var fs = File.OpenRead("/Users/zhangcheng/test.txt"))
    {
        var buffer = new byte[10 * 1024];
        await fs.ReadAsync(buffer, 0, buffer.Length);
        Console.WriteLine(Encoding.UTF8.GetString(buffer));
    }
}
```

* **`TPL`风格运行我们用线性方式编写异步程序。** .NET中目前大多数耗时操作都提供了TPL风格的方法。
* **`TPL`风格编程可以大幅提升系统吞吐量**，B/S程序效果更为显著，可以使用异步编程的地方尽量不要使用同步。
* `await`会确保异步结果返回后再执行后续代码，不会阻塞主线程。
* `TPL`风格方法都习惯以 `Async`结尾。
*  使用`await`关键字方法必须使用`async`修饰
*  接口中声明方法时不能使用`async`关键字，在其实现类中可以。

###### `TPL`风格方法允许以下三种类型的返回值：
* `Task`。异步Task做返回类型，相当于无返回值。方法被调用时支持`await`等待。
* `Task`&lt;T&gt;。`T`为异步方法内部实际返回类型。
* `void`。使用`void`做返回类型的异步方法，被调用时不支持`await`等待。


### 3.2 同步调用

返回`Task`或`Task`&lt;T&gt的`TPL`方法可以同步调用。调用`Task`对象的`Wait()`方法会同步阻塞线程直到任务执行完成，然后可以通过其`Result`属性拿到最终执行结果。

在同步方法中不使用`await`而直接使用`Task`对象的`Result`属性也会导致等待阻塞。

```csharp
Task<string> task = TestAsync();
task.Wait(); //同步等待
Console.Writeline(task.Result); //拿到执行结果
```

**使用APL风格编程，一定要全程使用异步，中间任何环节使用同步，不仅不会提升程序性能，而且容易造成死锁。**

### 3.3 并行异步

如果存在多个相互无关联的异步任务，使用`await`语法会让多个任务顺序执行，如果想实现并发执行，我们可以使用`Task.WhenAll()`方式。

```csharp
static async Task GetWeatherAsync()
{
    using (var hc = new HttpClient())
    {
        //三个顺序执行
        Console.WriteLine(await hc.GetStringAsync("https://baidu.com/getweather"));
        Console.WriteLine(await hc.GetStringAsync("https://google.com/getweather"));
        Console.WriteLine(await hc.GetStringAsync("https://bing.com/getweather"));
    }
}
```
使用`Task.WhenAll()`改造后如下：<span id="whenall" />
``` csharp
static async Task GetWeatherAsync()
{
    using (var hc = new HttpClient())
    {
        var task1 = hc.GetStringAsync("https://baidu.com/getweather");
        var task2 = hc.GetStringAsync("https://google.com/getweather");
        var task3 = hc.GetStringAsync("https://bing.com/getweather");

        // 三个任务并行执行
        var results = await Task.WhenAll(task1, task2, task3);
        foreach (var result in results)
            Console.WriteLine(result);
    }
}
```

### 3.4 自定义异步方法

```csharp
Task DoAsync()
{
    return Task.Run(() =>
    {
        // do something 
    });
}

Task<string> DoAsync()
{
    return Task.Run(() =>
    {
        //do something
        return "Hello";
    });
}

Task<DateTime> GetDate()
{
    // 从简单对象Task 可以使用 Task.FromResult()
    return Task.FromResult(DateTime.Today);
}
```

### 3.5 异常处理
**TPL风格编程中,有些情况下程序出现异常而不会抛出，也不会导致程序异常退出，此时会导致一些莫名的错误**。但是显式的使用`try...catch`可以捕获到这些异常，这就要求开发者在代码编写过程中谨慎权衡，在可能出现的异常的地方进行手动异常处理。

TPL编程有时会抛出`AggregateException`,这通常发生在并行有多个任务执行的情况下,如上面[并行异步](#whenall)案例的情况。多个并行任务可能有多个异常, 因此`AggregateException`是一个聚合型异常类型，通过其`InnerExceptions` 属性可以获得多个异常对象信息，逐个解析即可。