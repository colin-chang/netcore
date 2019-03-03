# WebAPI和Restful

本文中如果不做说明，本章所有内容均基于Asp.Net Core WebAPI (2.2)。

## 1.  WebAPI
`WebAPI`是一种用来开发系统间接口、设备接口`API`的技术,基于`Http`协议,请求和返回格式结果默认是`json`格式。比`WCF`更简单、更通用,比 `WebService`更节省流量、更简洁。

普通`ASP.Net MVC`甚至`HttpHandler`也可以开发`API`,但 `WebAPI`是更加专注于此的技术，更专业。

`Asp.Net WebAPI`和`Asp.Net MVC`有着非常密切的联系，`WebAPI`中可以复用`MVC`的路由、`ModelBinder`、`Filter` 等知识,但是只是相仿, 类名、命名空间等一般都不一样,用法也有一些差别。

Asp.Net WebAPI 具有以下特点：
* `Action`方法更专注于数据处理
* 更适合于`Restful`风格 
* 不依赖于`Web服务器 `,可以`selfhost`,或者寄宿于控制台或服务程序等
* 没有界面。`WebAPI`是接口开发技术,普通用户不会直接和`WebAPI`打交道

## 2. Restful
`Http`设计之初是有 **“谓词语义”** 的。这里谓词是指`HttpMethod`,常用的包括`Get`、`Post`、`Put`、`Delete` 等。

通常情况下，使用`Get`获取数据，使用`Post`新增数据，使用`Put`修改数据，使用`Delete`删除数据。使用`Http`状态码表示处理结果。如 找不到资源使用`404`，没有权限使用`401`。此设计倾向于把所有业务操作抽象成对资源的CRUD操作。

如果`API`设计符合`Http`谓词语义规则，那么就可以称其符合`Restful`风格。Asp.Net WebAPI 设计之初就符合`Restful`风格。

`Restful`风格设计具有以下优势：
* 方便按类型操作做权限控制，如设置`Delete`权限只需处理`Delete`请求方式即可。
* 不需要复杂的`Action`方法名，转而根据`HttpMethod`匹配请求
* 充分利用`Http`状态码,不需要另做约定
* 浏览器可以自动缓存`Get`请求,有利于系统优化

`Restful`风格设计同时也有许多弊端。仅通过谓词语义和参数匹配请求理论性太强，许多业务很难完全拆分为CRUD操作，如用户登录同时更新最后登录时间。另外，`Http`状态码有限，在很多业务场景中不足以表述处理结果，如“密码错误”和“AppKey错误”。

由于以上问题，导致`Restful`设计在很多业务场景中使用不便，很多大公司`API`也鲜少都能满足`Restful`规范。因此我们的原则是，尽可能遵守`Restful`规范，灵活变通，不追求极端。