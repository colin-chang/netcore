# 进程、线程基础

# 1. 进程管理
.NET中使用`Process`类管理维护进程信息。`Process`常用成员如下。

成员|含义
:-|:-
`Threads`|获取当前进程的所有线程
`Kill()`|杀掉指定进程
`Process.GetCurrentProcess()`|拿到当前程序进程
`Process.GetProcesses()`|拿到系统当前所有进程
`Process.GetProcessById()`|拿到指定Id的进程
`Process.Start()`|启动一个进程。

```csharp
// 启动IE浏览器并访问百度
Process.Start("iexplore","https://www.baidu.com");
```

# 2. 线程基础
* 多线程可以让一个程序“同时”处理多个事情。后台运行程序，提高程序的运行效率，同时解决耗时操作时GUI出现无响应的情况。
* 一个进程的多个线程之间可以共享程序代码。每个线程会将共享的代码分别拷贝一份去执行，每个线程是单独执行的。
* 线程有前台线程和后台线程，创建一个线程默认为前台线程。
* 只有所有的前台线程都关闭时程序才能退出。只要所有前台线程都关闭后台线程自动关闭。
* 线程被释放时，线程中定义的内容都会自动被释放

.NET中使用`Thread`类管理维护线程信息。`Thread`常用成员如下。

成员|含义
:-|:-
`Name`|线程名
`IsBackground`|获取或设置是否是后台线程
`IsAlive`|表示当前线程的执行状态
`ManagedThreadId`|获取当前托管线程的唯一标示符Id
`Priority`|获取或设置线程的优先级，只是推荐给OS，并不一定执行
`Start()`|启动线程
`Interrupt()`|用于提前唤醒一个在Sleep的线程
`Abort()`|强制终止线程
`Join()`|等待指定线程执行完毕后再接着执行当前线程
`Thread.CurrentThread`|获得当前的线程引用
`Thread.Sleep()`|让当前线程休眠。只能当前线程自身主动休眠，不能被其他线程控制。 


* `Abort()`方法会引发线程内当前在执行的代码抛出`ThreadAbortException`，可能会造成线程占用资源无法释放，一般情况下不推荐使用。可以通过结束线程执行的方法来结束并释放线程。
* `Interrupt()`唤醒`Sleep`的线程时`Sleep`方法会抛出 `ThreadInterruptedException`，需要我们`catch`异常，否则异常会导致程序崩溃退出。

    ```csharp
    var t1 = new Thread(() =>
    {
        try
        {
            Thread.Sleep(5000);
        }
        catch (ThreadInterruptedException)
        {
            Console.WriteLine("t1线程被意外唤醒");
        }

        Console.WriteLine("Fuck");
    }) {IsBackground = true};

    t1.Start();
    t1.Interrupt();
    ```