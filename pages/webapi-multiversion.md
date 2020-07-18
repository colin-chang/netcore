# WebAPI 多版本管理

## 1. 多版本API
如果我们为APP设计并提供API，当APP发布新本后可能早期APP没有内置升级机制，也可能有些用户不愿升级，造成多个版本的APP同时在运行。开发新版本App时,要给API增加新的功能或者修改以前接口的规范,这可能会造成旧版 App无法使用,因此在一定情况下会“保留旧接口的运行、新功能用新接口”,这样 就会存在多版本接口共存的问题。

## 2. 多版本管理

多版本管理常见技术实现方案有以下三种:
* 域名区分。不同版本用不同的域名。如 v1.api.xxx.com、v2.api.xxx.com、v3...
* 反代服务器转发。在url或报文头中携带版本信息,然后`Nginx`等反代服务器按照不同版本将请求转发到不同服务器。
* 路由匹配。多版本共处于同项目中,然后使用`[Route]`将请求路由到不同的`Controller`或`Action`中。

通过域名区分和Nginx转发来两种方式进行API多版本管理时，可以借助代码分支隔离多版本代码。旧版API做一个代码分支,除了进行 bug 修复外不再做改动;新接口代码继续演化升级。最后分别部署不同版本API服务，通过域名绑定或反代转发进行区分即可。推荐使用这两种方式。

通过路由匹配方式进行多版本管理在系统规模较小时可以在一定程度上节省资源配置消耗，但所有版本代码都共存在一个项目中，不易维护且不利于后期系统拓展。

前两种方式都是在运维阶段配置完成，不再赘述。最后路由匹配的方式则需要在开发阶段完成，下面我们来分析一下最后一种方式。

1) ControllerRoute
```csharp
[Route("api/v1/test")]
public class TestV1Controller:ControllerBase
{
    //GET api/v1/test/
    [HttpGet]
    public ActionResult<string> Get()
    {
        return "v1-get";
    }
}

[Route("api/v2/test")]
public class TestV2Controller:ControllerBase
{
    //GET api/v2/test/
    [HttpGet]
    public ActionResult<string> Get()
    {
        return "v2-get";
    }
}
```

2) ActionRoute
```csharp
[Route("api/test/{Action}")]
public class TestController : ControllerBase
{
    //GET api/test/getv1
    [HttpGet]
    public ActionResult<string> GetV1()
    {
        return "v1-get";
    }
    
    //GET api/test/getv2
    [HttpGet]
    public ActionResult<string> GetV2()
    {
        return "v2-get";
    }
}
```
