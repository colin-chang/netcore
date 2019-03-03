# 线程同步

* [1. 线程同步](#1-线程同步)
    * [1.1 Join](#11-join)
    * [1.2 MethodImplAttribute](#12-methodimplattribute)
    * [1.3 对象互斥锁](#13-对象互斥锁)
    * [1.4 多线程版单例模式](#14-多线程版单例模式)
* [2. 生产者消费者模式](#2-生产者消费者模式)
* [3. WaitHandle](#3-waithandle)
    * [3.1 ManualResetEvent](#31-manualresetevent)
    * [3.2 AutoResetEvent](#32-autoresetevent)

## 1. 线程同步
当一个方法同时被多个线程调用并修改同一变量时就可能存在脏数据的问题，我们称之为“多线程方法重入”。我们可以通过以下方式来解决此问题。

### 1.1 Join

`Join()`方法可以让当前线程等待指定线程执行结束后再**接着**运行当前线程。

```csharp
var t1 = new Thread(() =>
{
    for (int i = 0; i < 20; i++)
    {
        Console.WriteLine("t1 " + i);
    }
});

var t2 = new Thread(() =>
{
    t1.Join(); //等着 t1 执行结束后接着执行以下代码

    for (int i = 0; i < 20; i++)
    {
        Console.WriteLine("t2 " + i);
    }
});

t1.Start();
t2.Start();
```

### 1.2 MethodImplAttribute
在线程不安全的方法上打上`[MethodImpl(MethodImplOptions.Synchronized)]`标记后，此方法同时只能被一个线程调用，变成了同步方法。

```csharp
[MethodImpl(MethodImplOptions.Synchronized)]
public void Count()
{
    // do something ...
}
```

### 1.3 对象互斥锁
```csharp
var locker = new object();
public void Count()
{
    lock (locker)
    {
        // do something ...
    }
}
```
同一时刻只能有一个线程进入同一个对象的 lock 代码块。必须是同一个对象才能起到 互斥的作用。lock 后必须是引用类型,不一定是 object,只要是对象就行。

锁对象选择很重要,选不对起不到同步的作用和可能会造成其他地方被锁,比如用字符串做锁(因为字符串拘留池导致可能用的是其他地方也在用的锁)。

*lock是对`Monitor`类的简化调用，此处我们就不在讲Monitor的相关使用了。*

### 1.4 多线程版单例模式
```csharp
class God
{
    private static God _instance = null;
    private static readonly object Locker = new object();

    private God(){}

    public static God GetInstance()
    {
        if (_instance == null)
        {
            lock (Locker)
            {
                if (_instance == null)
                    _instance = new God();
            }
        }

        return _instance;
    }
}
```
以上方式保证线程安全，但是书写较为繁琐，日常开发中推荐使用静态单例方式。
```csharp
class God
{
    private God(){}

    private static readonly God Instance = new God();
    public static God GetInstance() => Instance;
}
```

## 2. 生产者消费者模式
多个线程同时修改共享数据可能会发生错误，此时我们常用生产者消费者模式来处理此问题。

在生成者和消费者关系中，生产者线程负责产生数据，并把数据存到公共数据区，消费者线程使用数据，从公共数据去中取出数据。我们使用资源加锁的方式来解决线程并发引起的方法重入问题。

```csharp
class Program
{
    static void Main(string[] args)
    {
        List<Product> list = new List<Product>();//创建产品池
        //创建5个生产者
        for (int i = 0; i < 5; i++)
        {
            new Thread(() =>
            {
                while (true)
                    lock (list)//锁定对象解决线程并发引起的方法重入问题
                    {
                        //生产一个产品
                        list.Add(new Product());
                        Console.WriteLine("生产产品{0}", list.Count - 1);
                        Thread.Sleep(500);
                    }
            }) { IsBackground = true }.Start();
        }

        //创建10个消费者
        for (int i = 0; i < 10; i++)
        {
            new Thread(() =>
            {
                while (true)
                    lock (list)
                    {
                        if (list.Count > 0)
                        {
                            //消费一个产品
                            list.RemoveAt(list.Count - 1);
                            Console.WriteLine("消费产品{0}", list.Count);
                            Thread.Sleep(200);
                        }
                    }
            }) { IsBackground = true }.Start();
        }
        Console.ReadKey();
    }
}
class Product {}
```

## 3. WaitHandle
除了前面提到的“锁”机制外，.NET中WaitHandle还提供了一些线程间协同的方法，使得线程可以通过“信号”进行通讯。

WaitHandle是一个抽象类，`EventWaitHandle`是其实现类，我们常用`EventWaitHandle`两个子类`ManualResetEvent`和`AutoResetEvent`。

信号通讯在`EventWaitHandle`中被通俗的比喻为“门”，主要体现为以下三个方法：

```csharp
Set();      // 开门
WaitOne();  // 等待开门
Reset();    // 关门
```

等待开门除了`WaitOne()`之外还有以下用法。
```csharp
//等待所有信号都变为“开门状态”
WaitHandle.WaitAll(WaitHandle[] waitHandles);

//等待任意一个信号变为“开门状态”
WaitHandle.WaitAny(WaitHandle[] waitHandles);
```

### 3.1 ManualResetEvent
`ManualResetEvent`被比喻为手动门，一旦开门后就保持开门状态，除非手动关门，如同“城门”。

```csharp
var mre = new ManualResetEvent(false); //创建"手动门"，默认状态为"关门"
new Thread(() =>
{
    mre.WaitOne(); //等待开门。开门之后后续代码方可执行，否则该线程一直阻塞在此处
    Console.WriteLine("开门了...");

    while (true)
    {
        Console.WriteLine(DateTime.Now);
        Thread.Sleep(1000);
    }
}){IsBackground = true}.Start();

Console.WriteLine("按任意键开门...");
Console.ReadKey();

mre.Set(); //开门

Thread.Sleep(5000);
mre.Reset(); //关门
Console.WriteLine("关门了...");
```

`WaitOne(5000); //最长等待5s`。

### 3.2 AutoResetEvent
`AutoResetEvent`被比喻为自动门，一次开门完成后自动关门，如同“地铁的闸机口”。

```csharp
var are = new AutoResetEvent(false); //创建"手动门"，默认状态为"关门"
new Thread(() =>
{
    are.WaitOne(); //等待开门。开门之后后续代码方可执行，否则该线程一直阻塞在此处
    Console.WriteLine("开门了...");
    
    //do something ...
}){IsBackground = true}.Start();

Console.WriteLine("按任意键开门...");
Console.ReadKey();

are.Set(); //开门
```

WaitHandle现在.NET中较少使用了，但它们更多作为简单易用的多线程语法的底层实现。