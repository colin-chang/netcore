# Consul 服务治理

* [1. 服务治理简介](#1-服务治理简介)
* [2. Consul 服务安装](#2-consul-服务安装)
* [3. 服务注册、注销、健康检查](#3-服务注册、注销、健康检查)
* [4. 服务发现](#4-服务发现)
    * [4.1 服务发现和消费](#41-服务发现和消费)
    * [4.2 客户端负载均衡](#42-客户端负载均衡)
    * [4.3 RestTemplate](#43-resttemplate)

## 1. 服务治理简介

服务治理包括，服务注册、注销、健康检查、服务发现等过程。

微服务架构中，所有服务都会注册到注册中心，客户端需要消费服务时，需要先到注册中心查询对应服务集群，然后按照一定的负载均衡策略消费服务即可。注册中心除了提供服务注册，服务查询工作外，还会按照一定机制对所有注册的服务进行健康检查，以维护服务的可用性。

负载均衡策略在客户端，称为客户端负载均衡。当然也可以设置负载均衡服务器专门负责负载均衡任务。注册中心是在服务器机房环境，其消费者也是服务器机房环境内网的其他服务程序，不会对外网公开，所以这里说的客户端负载均衡中客户端消费程序是指服务器中的某个服务而非真正的用户端，所以这里所说客户端负载均衡也是相对可靠的。

注册中心有很多实现，如Consul,Eureka,Zookeeper等。这里我们选择 [Consul](https://www.consul.io/)。

## 2. Consul 服务安装
这里我们直接通过Docker方式安装并部署Consul服务。
``` sh
# 此中配置仅用于开发。详细配置参见 https://hub.docker.com/_/consul

$ docker pull consul
$ docker run -d --name=consul-dev -e CONSUL_BIND_INTERFACE=eth0 -p 8500:8500 consul
```

这里暂且只用一台Consul服务器做演示用，生产环境中为了保证注册中心可用性要做注册中心服务集群,每个集群节点至少有一个（通常会有3到5个）Server，和若干Client组成。

Consul服务部署完成后直接通过 http://127.0.0.1:8500 即可访问其Web控制台。

## 3. 服务注册、注销、健康检查
连接 Consul 服务器需要借助 [Consul驱动](https://www.nuget.org/packages/Consul/)。

```sh
$ dotnet add package Consul
```

在.NET Core中微服务一般体现为WebAPI项目，可以方便地使用HTTP协议进行服务间通信。

生产环境中每个服务一般都会存在一个集群，互为备份，保证系统可用性。WebAPI项目默认启动监听 http://5000，
单机启动多个服务实例时需要区别端口，我们可以在程序启动时动态指定端口，或者使用docker做端口映射。

#### 1) 配置文件
使用默认配置文件 `appsettings.json`,`Build Action`为`Content`,`Copy to output directory`为`Copy always`

在`appsettings.json`中添加如下配置。配置内容根据实际环境修改即可。

```json
{
  "BindHosts": [
    "192.168.31.191"
  ],
  "ConsulClient": {
    "Address": "http://127.0.0.1:8500",
    "Datacenter": "dc1"
  }
}
```

#### 2) 添加健康检查API
```csharp
[Route("api/[controller]")]
[ApiController]
public class HealthController : ControllerBase
{
    [HttpGet]
    public ActionResult Get()
    {
        return Ok();
    }
}
```

#### 3) 修改启动配置

```csharp
public class Program
{
    public static void Main(string[] args)
    {
        /*
        * 程序启动时必须指定端口号，命令格式为 dotnet run --port 5000
        * 
        * 通过docker方式运行时要显式指定 ENTRYPOINT 参数。 形如 docker run xxx --port 5000
        */

        var config = new ConfigProvider(args);

        // 端口
        var portStr = config["port"];
        if (string.IsNullOrWhiteSpace(portStr))
            throw new ArgumentNullException("port", "Please choose a port for current service");
        if (!int.TryParse(args[1], out var port))
            throw new ArgumentException("porn must be a number");
        if (port < 1024 || port > 65535)
            throw new ArgumentOutOfRangeException("port", "Invalid port,it must between 1024 and 65535");

        // IP
        var bindHosts = ConfigProvider.GetAppSettings<List<string>>("BindHosts");
        var urls = bindHosts.Select(host => $"http://{host}:{port}").ToList();

        CreateWebHostBuilder(args, urls.ToArray()).Build().Run();
    }

    public static IWebHostBuilder CreateWebHostBuilder(string[] args, string[] urls) =>
        WebHost.CreateDefaultBuilder(args)
            .UseUrls(urls)
            .UseStartup<Startup>();
```



#### 4) 服务注册注销
```csharp
public async void Configure(IApplicationBuilder app, IHostingEnvironment env,
    IApplicationLifetime applicationLifetime)
{
    app.UseMvc();
    
    await Register2Consul(applicationLifetime);
}

private async Task Register2Consul(IApplicationLifetime applicationLifetime)
{
    var serviceName = Assembly.GetEntryAssembly().GetName().Name;
    var serviceId = $"{serviceName}_{Guid.NewGuid()}";

    //Consul 配置
    void ConsulConfig(ConsulClientConfiguration ccc)
    {
        ccc.Address = new Uri(Configuration["ConsulClient:Address"]);
        ccc.Datacenter = Configuration["ConsulClient:Datacenter"];
    }

    //注册服务到Consul
    using (var client = new ConsulClient(ConsulConfig))
    {
        var hosts = new List<string>();
        Configuration.Bind("BindHosts", hosts);
        var ip = hosts.LastOrDefault();
        var port = Convert.ToInt32(Configuration["port"]);

        await client.Agent.ServiceRegister(new AgentServiceRegistration
        {
            ID = serviceId, //服务编号
            Name = serviceName, //服务名称
            Address = ip, //服务地址，一般绑定本机内网地址
            Port = port, // 服务端口
            Check = new AgentServiceCheck
            {
                DeregisterCriticalServiceAfter = TimeSpan.FromSeconds(5), // 服务停止多久后从Consul中注销
                Interval = TimeSpan.FromSeconds(10), //健康检查间隔(心跳时间)
                HTTP = $"http://{ip}:{port}/api/health", //健康检查地址
                Timeout = TimeSpan.FromSeconds(5) //检查超时时间
            }
        });
    }

    //程序退出时候 从Consul注销服务
    applicationLifetime.ApplicationStopped.Register(async () =>
    {
        using (var client = new ConsulClient(ConsulConfig))
        {
            await client.Agent.ServiceDeregister(serviceId);
        }
    });
}
```

启动两个服务实例后，在Consul中可以看到这个服务信息。
```sh
$ dotnet SmsService.dll --port 8000
$ dotnet SmsService.dll --port 8001
```

![Consul服务注册](https://s2.ax1x.com/2020/01/19/19j7tA.jpg)

服务刚启动时会有短暂的 Failing 状态。服务正常结束(Ctrl+C)会触发 ApplicationStopped,正常注销。即使非正常结束也没关系,Consul 健康检查过一会发现服务器死掉后也会主动注销。如果服务器刚刚崩溃,但是还买来得及注销,消费的使用者可能就会拿到已经崩溃的实 例,这个问题通过后面讲的重试等策略解决。

服务只会注册 ip、端口,consul 只会保存服务名、ip、端口这些信息,至于服务提供什么接口、方法、参数,consul 不管,需要消费者知道服务的这些细节。

## 4. 服务发现
这里用控制台测试,真实项目中服务消费者同时也可能是另外一个 Web 应用(比如 Web 服务器调用短信服务器发短信)。

### 4.1 服务发现和消费
```csharp
using (var consulClient = new ConsulClient(c => c.Address = new Uri("http://127.0.0.1:8500")))
{
    //获取所有注册的服务实例
    var services = await consulClient.Agent.Services();
    
    //遍历并消费服务
    foreach (var service in services.Response.Values)
        Console.WriteLine($"id={service.ID},name={service.Service},ip={service.Address},port={service.Port}");
}
```

### 4.2 客户端负载均衡
我们可以按照实际需求自定义负载均衡策略，这里我们使用当前`TickCount`与服务实例数取模的方式达到随机获取一台服务器实例的效果，当然在一个毫秒之类会所有请求都压给一台服务器。也可以自己写随机、轮询等客户端负载均衡算法,也可以自己实现按不同权重分配(注册时候 Tags 带上配置、权重等信息)等算法。

```csharp
using (var consulClient = new ConsulClient(c => c.Address = new Uri("http://127.0.0.1:8500")))
{
    //获取所有注册的"人脸识别"服务
    var faceRecogonitionServices = consulClient.Agent.Services().Result.Response.Values
        .Where(s => s.Service.Equals("Xiaoyang.FaceRecognition", StringComparison.OrdinalIgnoreCase));

    if (faceRecogonitionServices.Any())
    {
        //使用 当前时间毫秒数量%人脸服务实例数 随机获得一个服务实例，实现复杂均衡
        var frs = faceRecogonitionServices.ElementAt(Environment.TickCount % faceRecogonitionServices.Count());
        Console.WriteLine($"{frs.Address}:{frs.Port}");
    }
}
```

### 4.3 ConsulRestHelper
注册中心可以把形如"http://ProductService/api/Product/"
的虚拟地址请求按照客户端负载均衡算法解析为形如 
http://192.168.1.10:8080/api/Product/ 
的真实地址。虚拟地址转化和请求处理过程都是重复性的操作，我们可以仿照 Spring Cloud自己封装一个[ConsulRestHelper](https://github.com/colin-chang/ConsulRestHelper) 帮助类来处理客户端请求服务的过程。其主要功能包括：
* 服务发现。 根据url中服务名获取一个服务实例,把虚拟路径转换为实际连服务器路径; 服务消费者无需指定服务提供者,实现解耦。
* 负载均衡。这里用的是简单的随机负载均衡,
* 处理客户端请求响应内容。

ConsulRestHelper 已经发布到[Nuget](https://www.nuget.org/packages/ColinChang.ConsulRestHelper/).


服务的注册、消费都是在系统内部服务器之间的进行,终端用户无法访问到Consul。如Web服务器对终端用户来讲的是否服务端，而其在服务治理中的角色则是作为客户端消费者。

使用示例：
```csharp
using (var httpClient = new HttpClient())
{
    var rest = new ConsulRestHelper(httpClient,"http://127.0.0.1:8500");
    var headers = new HttpRequestMessage().Headers;
    headers.Add("Authorization", "Bearer token");

    var ret1 = await rest.GetForEntityAsync<string[]>("http://Xiaoyang.FaceRecognition/api/values",
        headers);
    if (ret1.StatusCode == HttpStatusCode.OK)
        Console.WriteLine(string.Join(",", ret1.Body));
}
```