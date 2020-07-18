# API 网关

## 1. API GateWay
原则上微服务体系中所有在注册中心注册的服务都属于内部服务，不对用户直接开放，生产环境中这些服务多部署于一个局域网中，不能被外网直接访问到。

实际应用中我们常需要开放一些服务给用户，比如用户通过手机端或Web端请求文件服务器以加载资源文件，Web用户端直接请求Web应用服务器等。那对于客户端这些请求，我们不可能直接开放所有的服务，客户端记忆所有的服务地址和端口也非常繁琐，一旦服务端配置发生变化，可能会导致客户端无法正常工作，增强了系统之间耦合度。如果服务需要授权访问或者进行限流收费等，那每个服务都需要提供以上功能也导致重复工作。

API网关就是为了解决以上这些问题。API网关的角色是作为客户端访问服务的统一入口。所有用户请求都首先经过API网关，然后再转发给具体服务。正是“一夫当关”的位置，也在一定程度上体现了AOP的思想。我们可以在网关中进行统一的认证授权、限流收费等。

.Net微服务体系中目前比较流行的API网管是Ocelot，Nginx进行定制后也可以作为网关使用。

* 官网:https://github.com/ThreeMammals/Ocelot
* 资料:http://www.csharpkit.com/apigateway.html
* Ocelot 中文文档:http://www.jessetalk.cn/2018/03/19/net-core-apigateway-ocelot-docs/

![多路网关架构](https://i.loli.net/2020/02/26/CE2UqAMKmQzxg7y.jpg)

## 2. Ocelot 基本使用
Ocelot 就是一个提供了请求路由、安全验证等功能的 API 网关微服务。在Asp.Net Core中一般表现为一个WebAPI项目，但是我们不需要MVC功能，所以删除MVC服务和中间件以及Controller。

### 2.1 基本使用

1) 配置文件
Ocelot使用方式比较简单，基本不需要Coding，只要按照其语法规范定义和修改配置文件即可。通过配置文件可以完成对Ocelot的功能配置：路由、服务聚合、服务发现、认证、鉴权、限流、熔断、缓存、Header头传递等。
以下是最基本的配置信息，在配置文件中包含两个根节点：ReRoutes和GlobalConfiguration。

```json
{
    "ReRoutes": [],
    "GlobalConfiguration": {
        "BaseUrl": "https://api.mybusiness.com"
    }
}
```
要特别注意一下BaseUrl是我们外部暴露的Url。

2) 配置依赖注入与中间件

```csharp
public void ConfigureServices(IServiceCollection services)
{
    services.AddOcelot();
}
public async void Configure(IApplicationBuilder app, IHostingEnvironment env)
{
    if (env.IsDevelopment())
    {
        app.UseDeveloperExceptionPage();
    }

    await app.UseOcelot();
}
```

### 2.1 路由
Ocelot的最基本的功能就是路由，也就是请求转发。路由规则定义在ReRoutes配置节点中，ReRoutes是一个数组，其中的每一个元素代表了一个路由。

```json
"ReRoutes": [
    {
      "DownstreamPathTemplate": "/api/test/{url}",
      "DownstreamScheme": "http",
      "DownstreamHostAndPorts": [
        {
          "Host": "localhost",
          "Port": 8000
        }
      ],
      "UpstreamPathTemplate": "/test/{url}",
      "UpstreamHttpMethod": [
        "Get",
        "Post"
      ]
    }
]
```
以上路由规则会将会对该Ocelot服务器的`/test/{url}`请求转发给`http://localhost:8000/api/test/{url}`。允许`Get`和`Post`请求

配置项|含义
:-|:-
Downstream|下游服务配置
UpStream|上游服务配置
Aggregates|服务聚合配置
ServiceName, LoadBalancer, UseServiceDiscovery|配置服务发现
AuthenticationOptions|配置服务认证
RouteClaimsRequirement|配置Claims鉴权
RateLimitOptions|限流配置
FileCacheOptions|缓存配置
QosOptions|服务质量与熔断
DownstreamHeaderTransform|Headers信息转发

#### 2.1.1 万能模板
上游Host也是路由用来判断的条件之一，由客户端访问时的Host来进行区别。比如当a.jesetalk.cn/users/{userid}和b.jessetalk.cn/users/{userid}两个请求的时候可以进行区别对待。
```json
{
    "UpstreamPathTemplate": "/",
    "UpstreamHttpMethod": [ "Get" ],
    "UpstreamHost": "ccstudio.org",
    "DownstreamPathTemplate": "/",
    "DownstreamScheme": "https",
    "DownstreamHostAndPorts": [
            {
                "Host": "10.0.10.1",
                "Port": 80,
            }
        ]
}
```

#### 2.1.2 优先级
对多个产生冲突的路由设置Prioirty。
```json
{
    "UpstreamPathTemplate": "/goods/{catchAll}"
    "Priority": 0
}
{
    "UpstreamPathTemplate": "/goods/delete"
    "Priority": 1
}
```
当请求/goods/delete的时候，则下面那个会生效。也就是说Prority是大的会被优先选择。

### 2.2 负载均衡
当下游服务有多个结点的时候，我们可以在DownstreamHostAndPorts中进行配置。通常也结合Consul来实现负载均衡。
```json
{
    "DownstreamPathTemplate": "/api/posts/{postId}",
    "DownstreamScheme": "https",
    "DownstreamHostAndPorts": [
            {
                "Host": "10.0.1.10",
                "Port": 5000,
            },
            {
                "Host": "10.0.1.11",
                "Port": 5000,
            }
        ],
    "UpstreamPathTemplate": "/posts/{postId}",
    "LoadBalancer": "LeastConnection",
    "UpstreamHttpMethod": [ "Put", "Delete" ]
}
```
LoadBalancer将决定负载均衡的算法。

负载方式|含义
:-|:-
LeastConnection | 将请求发往最空闲的那个服务器
RoundRobin | 轮流发送
NoLoadBalance | 总是发往第一个请求或者是服务发现



### 2.3 Work with Consul
上面的案例中转发规则是硬编码的，我们知道实际下游服务之间访问都是通过注册中心来映射的，Ocelet也可以完美的和Consul一起合作。

以下用法基于`Consul v1.4.3`和`Ocelot 13.0.0`，如果更新版本方法不可用，请参与官方文档。

添加Consul服务提供程序
```sh
dotnet add package Ocelot.Provider.Consul
```

注册Consul服务
```csharp
public void configureservices(iservicecollection services)
{
    services.AddOcelot().AddConsul();
}
```

修改配置文件如下
```json
"ReRoutes": [
  {
    "UpstreamPathTemplate": "/test/{url}",
    "UpstreamHttpMethod": [
      "Get",
      "Post"
    ],
    "DownstreamPathTemplate": "/api/test/{url}",
    "DownstreamScheme": "http",
    "ServiceName": "Xiaoyang.TemplateService",
    "LoadBalancerOptions": {
      "Type": "LeastConnection"
    },
    "UseServiceDiscovery": true
  }
],
"GlobalConfiguration": {
  "ServiceDiscoveryProvider": {
    "Host": "localhost",
    "Port": 8500,
    "Type": "Consul"
  },
  "BaseUrl": "http://localhost:5000"
}
```

以上路由规则会将对该 Ocelot 服务器的`/test/{url}`请求按照最少连接优先的负载均衡策略转发给下游应用服务群，转发格路径格式为`/api/test/{url}`，服务发现与健康检查工作交由地址为`http://localhost:8500`的Consul注册中心处理。`BaseUrl`为当前Ocelot服务地址。

## 3. 其他功能
### 3.1 限流

### 3.2 QOS(熔断器)

### 3.3 请求缓存