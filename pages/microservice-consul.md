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

负载均衡策略在客户端，称为客户端负载均衡。当然也可以设置负载均衡服务器专门负责负载均衡任务。注册中心是在服务器机房环境，其消费者也是服务器机房环境内网的其他服务程序，不会对外网公开，所以这里说的客户端负载均衡中客户端消费程序是指服务器中的某个服务而非真正的用户端，所有客户端负载均衡也是但相对可靠的。

注册中心有很多实现，如Consul,Eureka、Zookeeper等。这里我们选择 [Consul](https://www.consul.io/)。

## 2. Consul 服务安装
这里我们直接通过Docker方式安装并部署Consul服务。
``` sh
# 此中配置仅用于开发。详细配置参见 https://hub.docker.com/_/consul

$ docker pull consul
$ docker run -d --name=consul-dev -e CONSUL_BIND_INTERFACE=eth0 -p 8500:8500 consul
```

这里只用一台Consul服务器做演示用，生产环境中为了保证注册中心可用性要做注册中心服务集群，至少一台 Server,多台 Agent。

Consul服务部署完成后直接通过 http://127.0.0.1:8500 即可访问其Web控制台。

## 3. 服务注册、注销、健康检查
连接 Consul 服务器需要借助 [Consul驱动](https://www.nuget.org/packages/Consul/)。

```sh
$ dotnet add package Consul
```

在.NET Core中微服务一般都体现为WebAPI项目，便于进行服务间通信。

生产环境中每个服务一般都会存在一个集群，互为备份，保证系统可用性。WebAPI项目默认启动监听 http://5000，单机启动多个服务实例时需要区别端口，我们可以在程序启动时动态指定端口。或者使用docker做端口映射。

#### 1) 服务启动设置

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

#### 2) appsettings.json
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

#### 3) 服务注册注销
```csharp
public async void Configure(IApplicationBuilder app, IHostingEnvironment env,
    IApplicationLifetime applicationLifetime)
{
    app.UseMvc();


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

![Consul服务注册](../img/microservice/smsservice.jpg)

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
我们可以按照实际需求自定义负载均衡策略，这里我们使用，如下面的代码使用当前`TickCount`与服务实例数取模的方式达到随机获取一台服务器实例的效果，当然在一个毫秒之类会所有请求都压给一台服务器。也可以自己写随机、轮询等客户端负载均衡算法,也可以自己实现按不同权重分配(注册时候 Tags 带上配置、权重等信息)等算法。

```csharp
using (var consulClient = new ConsulClient(c => c.Address = new Uri("http://127.0.0.1:8500")))
{
    //获取所有注册的"人脸识别"服务
    var faceRecogonitionServices = consulClient.Agent.Services().Result.Response.Values
        .Where(s => s.Service.Equals("Xiaoyang.FaceRecognition", StringComparison.OrdinalIgnoreCase));

    if (faceRecogonitionServices.Any())
    {
        //使用 当前时间毫秒数量%人脸服务实例树 随机获得一个服务实例，实现复杂均衡
        var frs = faceRecogonitionServices.ElementAt(Environment.TickCount % faceRecogonitionServices.Count());
        Console.WriteLine($"{frs.Address}:{frs.Port}");
    }
}
```

### 4.3 RestTemplate
注册中心可以把形如"http://ProductService/api/Product/"这样的虚拟地址请求按照客户端负载均衡算法解析为形如 http://192.168.1.10:8080/api/Product/ 这样的真实地址。虚拟地址转化和请求处理过程都是重复性的操作，我们可以仿照 Spring Cloud自己封装一个RestTemplate帮助类来处理客户端请求服务的过程。其主要功能包括：
* 服务发现。 根据url中服务名获取一个服务实例,把虚拟路径转换为实际连服务器路径; 服务消费者无需指定服务提供者,实现解耦。
* 负载均衡。这里用的是简单的随机负载均衡,
* 处理客户端请求响应内容。

服务的注册者、消费者都是网站内部服务器之间的事情,对于终端用户是不涉及这些的。终端用户是不能访问consul的。对终端用户来讲的Web服务器，在服务消费过程中则充当了客户端的角色。

```csharp
/// <summary>
/// 会自动到Consul中解析服务的Rest客户端，能把"http://ProductService/api/Product/"这样的虚拟地址
/// 按照客户端负载均衡算法解析为http://192.168.1.10:8080/api/Product/这样的真实地址
/// </summary>
public class RestTemplate
{
    private readonly HttpClient _httpClient;
    private readonly string _consulServerUrl;

    public RestTemplate(HttpClient httpClient, string consulClientAddress = null)
    {
        _httpClient = httpClient;

        if (string.IsNullOrWhiteSpace(consulClientAddress))
            _consulServerUrl = ConfigProvider.GetAppSettings("ConsulClient");
    }

    /// <summary>
    /// 获取服务的第一个实现地址
    /// </summary>
    /// <param name="serviceName"></param>
    /// <returns></returns>
    private async Task<string> ResolveRootUrlAsync(String serviceName)
    {
        using (var consulClient = new ConsulClient(c => c.Address = new Uri(_consulServerUrl)))
        {
            var services = (await consulClient.Agent.Services()).Response.Values
                .Where(s => s.Service.Equals(serviceName, StringComparison.OrdinalIgnoreCase));
            if (!services.Any())
            {
                throw new ArgumentException($"找不到服务{serviceName}的任何实例");
            }
            else
            {
                //根据当前时钟毫秒数对可用服务个数取模，取出一台机器使用
                var service = services.ElementAt(Environment.TickCount % services.Count());
                return $"{service.Address}:{service.Port}";
            }
        }
    }

    //把http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
    private async Task<string> ResolveUrlAsync(string url)
    {
        var uri = new Uri(url);
        var serviceName = uri.Host; //apiservice1
        var realRootUrl = await ResolveRootUrlAsync(serviceName); //查询出来apiservice1对应的服务器地址192.168.1.1:5000
        //uri.Scheme=http,realRootUrl =192.168.1.1:5000,PathAndQuery=/api/values
        return uri.Scheme + "://" + realRootUrl + uri.PathAndQuery;
    }

    /// <summary>
    /// 发出Get请求
    /// </summary>
    /// <typeparam name="T">响应报文反序列类型</typeparam>
    /// <param name="url">请求路径</param>
    /// <param name="requestHeaders">请求额外的报文头信息</param>
    /// <returns></returns>
    public async Task<RestResponseWithBody<T>> GetForEntityAsync<T>(string url,
        HttpRequestHeaders requestHeaders = null)
    {
        using (var requestMsg = new HttpRequestMessage())
        {
            if (requestHeaders != null)
            {
                foreach (var header in requestHeaders)
                {
                    requestMsg.Headers.Add(header.Key, header.Value);
                }
            }

            requestMsg.Method = HttpMethod.Get;
            //http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
            requestMsg.RequestUri = new Uri(await ResolveUrlAsync(url));
            RestResponseWithBody<T> respEntity = await SendForEntityAsync<T>(requestMsg);
            return respEntity;
        }
    }

    /// <summary>
    /// 发出Post请求
    /// </summary>
    /// <typeparam name="T">响应报文反序列类型</typeparam>
    /// <param name="url">请求路径</param>
    /// <param name="body">请求数据，将会被json序列化后放到请求报文体中</param>
    /// <param name="requestHeaders">请求额外的报文头信息</param>
    /// <returns></returns>
    public async Task<RestResponseWithBody<T>> PostForEntityAsync<T>(string url, object body = null,
        HttpRequestHeaders requestHeaders = null)
    {
        using (var requestMsg = new HttpRequestMessage())
        {
            if (requestHeaders != null)
            {
                foreach (var header in requestHeaders)
                {
                    requestMsg.Headers.Add(header.Key, header.Value);
                }
            }

            requestMsg.Method = HttpMethod.Post;
            //http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
            requestMsg.RequestUri = new Uri(await ResolveUrlAsync(url));
            requestMsg.Content = new StringContent(JsonConvert.SerializeObject(body));
            requestMsg.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

            RestResponseWithBody<T> respEntity = await SendForEntityAsync<T>(requestMsg);
            return respEntity;
        }
    }

    /// <summary>
    /// 发出Post请求
    /// </summary>
    /// <param name="url">请求路径</param>
    /// <param name="body">请求数据，将会被json序列化后放到请求报文体中</param>
    /// <param name="requestHeaders">请求额外的报文头信息</param>
    /// <returns></returns>
    public async Task<RestResponse> PostAsync(string url, object body = null,
        HttpRequestHeaders requestHeaders = null)
    {
        using (var requestMsg = new HttpRequestMessage())
        {
            if (requestHeaders != null)
            {
                foreach (var header in requestHeaders)
                {
                    requestMsg.Headers.Add(header.Key, header.Value);
                }
            }

            requestMsg.Method = HttpMethod.Post;
            //http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
            requestMsg.RequestUri = new Uri(await ResolveUrlAsync(url));
            requestMsg.Content = new StringContent(JsonConvert.SerializeObject(body));
            requestMsg.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

            var resp = await SendAsync(requestMsg);
            return resp;
        }
    }

    /// <summary>
    /// 发出Put请求
    /// </summary>
    /// <typeparam name="T">响应报文反序列类型</typeparam>
    /// <param name="url">请求路径</param>
    /// <param name="body">请求数据，将会被json序列化后放到请求报文体中</param>
    /// <param name="requestHeaders">请求额外的报文头信息</param>
    /// <returns></returns>
    public async Task<RestResponseWithBody<T>> PutForEntityAsync<T>(String url, object body = null,
        HttpRequestHeaders requestHeaders = null)
    {
        using (var requestMsg = new HttpRequestMessage())
        {
            if (requestHeaders != null)
            {
                foreach (var header in requestHeaders)
                {
                    requestMsg.Headers.Add(header.Key, header.Value);
                }
            }

            requestMsg.Method = HttpMethod.Put;
            //http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
            requestMsg.RequestUri = new Uri(await ResolveUrlAsync(url));
            requestMsg.Content = new StringContent(JsonConvert.SerializeObject(body));
            requestMsg.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

            RestResponseWithBody<T> respEntity = await SendForEntityAsync<T>(requestMsg);
            return respEntity;
        }
    }

    /// <summary>
    /// 发出Put请求
    /// </summary>
    /// <param name="url">请求路径</param>
    /// <param name="body">请求数据，将会被json序列化后放到请求报文体中</param>
    /// <param name="requestHeaders">请求额外的报文头信息</param>
    /// <returns></returns>
    public async Task<RestResponse> PutAsync(string url, object body = null,
        HttpRequestHeaders requestHeaders = null)
    {
        using (var requestMsg = new HttpRequestMessage())
        {
            if (requestHeaders != null)
            {
                foreach (var header in requestHeaders)
                {
                    requestMsg.Headers.Add(header.Key, header.Value);
                }
            }

            requestMsg.Method = HttpMethod.Put;
            //http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
            requestMsg.RequestUri = new Uri(await ResolveUrlAsync(url));
            requestMsg.Content = new StringContent(JsonConvert.SerializeObject(body));
            requestMsg.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

            var resp = await SendAsync(requestMsg);
            return resp;
        }
    }

    /// <summary>
    /// 发出Delete请求
    /// </summary>
    /// <typeparam name="T">响应报文反序列类型</typeparam>
    /// <param name="url">请求路径</param>
    /// <param name="requestHeaders">请求额外的报文头信息</param>
    /// <returns></returns>
    public async Task<RestResponseWithBody<T>> DeleteForEntityAsync<T>(string url,
        HttpRequestHeaders requestHeaders = null)
    {
        using (var requestMsg = new HttpRequestMessage())
        {
            if (requestHeaders != null)
            {
                foreach (var header in requestHeaders)
                {
                    requestMsg.Headers.Add(header.Key, header.Value);
                }
            }

            requestMsg.Method = HttpMethod.Delete;
            //http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
            requestMsg.RequestUri = new Uri(await ResolveUrlAsync(url));
            var respEntity = await SendForEntityAsync<T>(requestMsg);
            return respEntity;
        }
    }

    /// <summary>
    /// 发出Delete请求
    /// </summary>
    /// <param name="url">请求路径</param>
    /// <param name="requestHeaders">请求额外的报文头信息</param>
    /// <returns></returns>
    public async Task<RestResponse> DeleteAsync(string url, HttpRequestHeaders requestHeaders = null)
    {
        using (var requestMsg = new HttpRequestMessage())
        {
            if (requestHeaders != null)
            {
                foreach (var header in requestHeaders)
                {
                    requestMsg.Headers.Add(header.Key, header.Value);
                }
            }

            requestMsg.Method = System.Net.Http.HttpMethod.Delete;
            //http://apiservice1/api/values转换为http://192.168.1.1:5000/api/values
            requestMsg.RequestUri = new Uri(await ResolveUrlAsync(url));
            var resp = await SendAsync(requestMsg);
            return resp;
        }
    }

    /// <summary>
    /// 发出Http请求
    /// </summary>
    /// <typeparam name="T">响应报文反序列类型</typeparam>
    /// <param name="requestMsg">请求数据</param>
    /// <returns></returns>
    private async Task<RestResponseWithBody<T>> SendForEntityAsync<T>(HttpRequestMessage requestMsg)
    {
        var result = await _httpClient.SendAsync(requestMsg);
        var respEntity = new RestResponseWithBody<T> {StatusCode = result.StatusCode, Headers = result.Headers};
        var bodyStr = await result.Content.ReadAsStringAsync();
        if (!string.IsNullOrWhiteSpace(bodyStr))
        {
            respEntity.Body = JsonConvert.DeserializeObject<T>(bodyStr);
        }

        return respEntity;
    }

    /// <summary>
    /// 发出Http请求
    /// </summary>
    /// <param name="requestMsg">请求数据</param>
    /// <returns></returns>
    private async Task<RestResponse> SendAsync(HttpRequestMessage requestMsg)
    {
        var result = await _httpClient.SendAsync(requestMsg);
        var response = new RestResponse {StatusCode = result.StatusCode, Headers = result.Headers};
        return response;
    }
}

/// <summary>
/// Rest响应结果
/// </summary>
public class RestResponse
{
    /// <summary>
    /// 响应状态码
    /// </summary>
    public HttpStatusCode StatusCode { get; set; }

    /// <summary>
    /// 响应的报文头
    /// </summary>
    public HttpResponseHeaders Headers { get; set; }
}

/// <summary>
/// 带响应报文的Rest响应结果，而且json报文会被自动反序列化
/// </summary>
/// <typeparam name="T"></typeparam>
public class RestResponseWithBody<T> : RestResponse
{
    /// <summary>
    /// 响应报文体json反序列化的内容
    /// </summary>
    public T Body { get; set; }
}
```

Resttemplate 使用示例：
```csharp
using (var httpClient = new HttpClient())
{
    var rest = new RestTemplate(httpClient);
    var headers = new HttpRequestMessage().Headers;
    headers.Add("Authorization", "Bearer token");

    var ret1 = await rest.GetForEntityAsync<string[]>("http://Xiaoyang.FaceRecognition/api/values",
        headers);
    if (ret1.StatusCode == HttpStatusCode.OK)
        Console.WriteLine(string.Join(",", ret1.Body));
}
```