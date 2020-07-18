# 页面静态化和SSI

## 1. 页面静态化
即使使用缓存,只是降低数据库服务器压力,web 服务器仍然是“每次来访都要跑 一遍代码”,如果所有人访问的结果都一样,就可以直接要响应的内容保存成 html 文件,让用户访问 html 文件。

缓存和静态页的区别:静态页的性能比缓存好,能用静态页就用静态页。什么情况下不能用静态页:相同的地址不同的人看的不一样、有的页面有的人不能看。
 
### 1.1 MVC
之前都是用户请求 Action,获取 html 响应去显示,那么怎么样通过程序去请求 Action 获取响应呢?

首先定义如下的方法:
```csharp
static string RenderViewToString(ControllerContext context, string viewPath, object model = null)
{
    var viewEngineResult = ViewEngines.Engines.FindView(context, viewPath, null);
    if (viewEngineResult == null)
        throw new FileNotFoundException("View" + viewPath + "cannot be found.");

    var view = viewEngineResult.View;
    context.Controller.ViewData.Model = model;
    using (var sw = new StringWriter())
    {
        var ctx = new ViewContext(context, view,
            context.Controller.ViewData,
            context.Controller.TempData,
            sw);
        view.Render(ctx, sw);
        return sw.ToString();
    }
}

然后如下调用:
```csharp
string html = RenderViewToString(this.ControllerContext, "~/Views/Home/Index.cshtml", person);

File.WriteAllText("home_index.html",html);
```

静态化之后可以将用户对`/Home/Index`的请求转为`/home_index.html`。既可以在生成客户端链接的时候直接使用静态地址，也可以在服务端通过路由重定项等处理。
 
我们通常只对**读多写少**的内容进行页面静态化处理，当静态化的页面内容发生“增删改”操作时，重新生成对应的静态页面即可。

### 1.2 WebAPI
目前Web开发中[前后端分离](/distribution/separatefontend.md)技术逐渐成为趋势。前后端分离之后项目架构可以简单抽象为`UI + WebAPI`。那么如何在前后端分离架构中进行页面静态化呢。

页面静态化本质是在HTML组装完成之后将其保存为静态文件，用户请求时直接返回保存的静态文件而不用再次动态组装。那在前后端分离之后，HTML的组装工作都是在`UI`完成，所以直接在`UI`层编写静态化逻辑即可。新增需要静态化的资源时，请求`API`数据组装HTML并使用JS将组装完成的HTML页面另存下来，其内容发生`增删改`操作时再次请求`API`重新组装即可。

## 2. SSI

https://www.jianshu.com/p/3898780ac1c9
https://www.cnblogs.com/dehigher/p/10127380.html
