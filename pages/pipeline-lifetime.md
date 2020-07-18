# 生命周期

在[管道模型](pipeline-diagram.md)中我们了解到了Asp.Net Core如何处理一个Http请求的过程及其管道构建过程。这一节我们将对声明周期中的诸多细节做一些简单讲解和补充。

## 1.IApplicationLifetime
在传统Asp.Net MVC中我们可以在Global的Application_Start等管道事件中做某些业务处理，Asp.Net Core的[管道模型](pipeline-diagram.md)已经发生了变化，但`IApplicationLifetime`服务允许我们响应`ApplicationStarted`,`ApplicationStopping`,`ApplicationStopped`三个事件。

```csharp
public void Configure(IApplicationBuilder app, IHostingEnvironment env,IApplicationLifetime lifetime)
{
    lifetime.ApplicationStarted.Register(() =>
    {
        Console.WriteLine("程序启动完成");
    });
    
    lifetime.ApplicationStopped.Register(() =>
    {
        Console.WriteLine("程序已停止");
    });

    //do something else ...
}
```