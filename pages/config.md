# 配置管理

.Net Core项目配置使用方式与.Net Framework程序不同。

.Net Core配置依赖于[`Microsoft.Extensions.Configuration`](https://www.nuget.org/packages/Microsoft.Extensions.Configuration/)和[`Microsoft.Extensions.Configuration.Json`](https://www.nuget.org/packages/Microsoft.Extensions.Configuration.Json)(使用Json配置文件时需要)。新版`Microsoft.AspNetCore.App`包中默认包含了以上两个Nuget包，所以Asp.Net Core应用管理配置不需要再额外引用相关Nuget包。

.Net Core 配置内容都是以 key-value 对形式存在的。

## 1. 命令行和内存配置
.Net Core程序读取命令行配置依赖于[`Microsoft.Extensions.Configuration.CommandLine`](https://www.nuget.org/packages/Microsoft.Extensions.Configuration.CommandLine)Nuget包(Asp.Net Core默认已安装)。

我们可以通过以下语法读取命令行和内存配置数据。
```csharp
static void Main(string[] args)
{
    var settings = new Dictionary<string, string>
    {
        {"name", "Colin"},
        {"age", "18"}
    };

    var config = new ConfigurationBuilder() //实例化配置对象工厂
        .AddInMemoryCollection(settings) //使用内存集合配置
        .AddCommandLine(args) //使用命令行配置
        .Build(); //获取配置根对象

    //获取配置
    Console.WriteLine($"name:{config["name"]} \t age:{config["age"]}");
}
```

运行以上程序。
```sh
$ dotnet run cmddemo                        # 输出 name:Colin   age:18
$ dotnet run cmddemo name=Robin age=20      # 输出 name:Robin   age:20
$ dotnet run cmddemo --name Robin --age 20    # 输出 name:Robin   age:20
```

由于`AddCommandLine()`在`AddInMemoryCollection()`之后，所以当命令行有参数时会覆盖内存配置信息。

## 2. Json文件配置
相比与命令行和内存配置，我们更常用Json文件来存储配置信息。这Json文件内容没有任何要求，只要符合Json格式即可。

假定项目目录下有名为`appsettings.json`的配置文件，内容如下：
```json
{
  "AppName": "配置测试",
  "Class": {
    "ClassName": "三年二班",
    "Master": {
      "Name": "Colin",
      "Age": 25
    },
    "Students": [
      {
        "Name": "Robin",
        "Age": 20
      },
      {
        "Name": "Sean",
        "Age": 23
      }
    ]
  }
}
```

```csharp
static void Main(string[] args)
{
    var config = new ConfigurationBuilder()
        .AddJsonFile("appsettings.json")
        .Build();

        Console.WriteLine($"AppName:{config["AppName"]}");
        Console.WriteLine($"ClassName:{config["Class:ClassName"]}");
        Console.WriteLine($"Master:\r\nName:{config["Class:Master:Name"]}\tAge:{config["Class:Master:Age"]}");
        Console.WriteLine("Students:");
        Console.WriteLine($"Name:{config["Class:Students:0:Name"]}\tAge:{config["Class:Students:0:Age"]}");
        Console.WriteLine($"Name:{config["Class:Students:1:Name"]}\tAge:{config["Class:Students:1:Age"]}");
}
```

除了可以使用IConfiguration类型的索引器方式读取配置，还可以通过其`GetSection(string key)`方法读取配置。`GetSection()`方法返回类型为`IConfigurationSection`，可以链式编程方式读取多层配置。

```csharp
var clsName = config.GetSection("Class").GetSection("ClassName").Value; //clsName="三年二班"
```

## 3. 配置对象映射

前面提到的配置读取方式只能读取到配置项的字符串格式的内容，遇到较为复杂的配置我们更期望配置信息可以映射为C#当中的一个对象。

我们为前面使用的配置文件定义实体类内容如下:
```csharp
public class Class
{
    public string ClassName { get; set; }
    public Master Master { get; set; }
    public IEnumerable<Student> Students { get; set; }
}
public abstract class Person
{
    public string Name { get; set; }
    public int Age { get; set; }
}
public class Master : Person{}
public class Student : Person{}
```

### 3.1 Bind
[Microsoft.Extensions.Configuration.Binder](https://www.nuget.org/packages/Microsoft.Extensions.Configuration.Binder)为IConfiguration扩展了三个`Bind()`方法，其作用是尝试将给定的配置信息映射为一个对象。

1) .Net Core

```csharp
var cls = new Class();
config.Bind("Class",cls); // 执行完成后配置文件内容将映射到cls对象中
```

2) Asp.Net Core

Asp.Net Core中默认包含了需要的Nuget包，在`Startup.cs`中直接使用`Configuration.Bind()`即可获得配置映射的Class对象，如需在其他位置使用此配置对象，需要手动将其注册到服务列表中。
```csharp
public void ConfigureServices(IServiceCollection services)
{
    // other services ...

    var cls = new Class();
    Configuration.Bind("Class",cls);
    services.AddSingleton<Class>(cls); //服务注册
}
```

### 3.2 Config&lt;T&gt;

[Microsoft.Extensions.Options.ConfigurationExtensions](https://www.nuget.org/packages/Microsoft.Extensions.Options.ConfigurationExtensions)包为`IServiceCollection`扩展了Configure&lt;T&gt;方法，其作用是注册一个配置对象并绑定为IOptions&lt;T&gt;对象。该种方式配合DI使用，DI的详细介绍参阅[依赖注入](di-intro.md)。

1) .Net Core

普通.Net Core项目使用DI需要引入[`Microsoft.Extensions.DependencyInjection`](https://www.nuget.org/packages/Microsoft.Extensions.DependencyInjection) Nuget包。

```csharp
//注册服务
var serviceCollection = new ServiceCollection();
serviceCollection.Configure<Class>(config.GetSection("Class"));

//消费服务
var cls = serviceCollection.BuildServiceProvider().GetService<IOptions<Class>>().Value;
```

2) Asp.Net Core

在Asp.Net Core中配置使用十分简便，在`Startup.cs`中作如下配置：
```csharp
public void ConfigureServices(IServiceCollection services)
{
    // other services ...

    services.Configure<Class>(Configuration.GetSection("Class")); //注册配置服务
}
```

在控制器等位置消费服务与普通IOptions服务一样。
```csharp
private readonly Class _cls;

public HomeController(IOptions<Class> classAccesser)
{
    _cls = classAccesser.Value;
}
```

## 4. 配置文件热更新
.Net Core中配置文件是支持热更新的。在`ConfigurationBuilder`的`AddJsonFile()`方法中`reloadOnChange`参数表示配置文件变更后是否自动重新加载(热更新)。

```csharp
new ConfigurationBuilder().AddJsonFile("appsettings.json", true, true)
```

[3.1 Bind](#31-bind)方式配置文件读取方式并不支持热更新。[Config&lt;T&gt;](#32-configt)方式支持配置文件热更新但是需要使用 IOptionsSnapshot&lt;T&gt; 替换 IOptions&lt;T&gt;。

```csharp
private readonly Class _cls;

public HomeController(IOptionsSnapshot<Class> classAccesser)
{
    _cls = classAccesser.Value;
}
```

在Asp.Net Core中不指定配置文件时默认使用应用根目录下的`appsettings.json`文件作为配置文件并且启用了热更新，这在`WebHost.CreateDefaultBuilder(args)`过程中完成，若要使用自定义配置文件名称可以通过以下方式修改。

```csharp
WebHost.CreateDefaultBuilder(args)
    .ConfigureAppConfiguration(config => config.AddJsonFile("myconfig.json",true,false))
```

开启配置文件热更新后程序会启动一个后台线程监听配置文件是否变动，如果配置文件不需要经常改动可以关闭配置文件热更新以减少系统开支，关闭方式同上。

## 5. 配置管理工具类封装
在Asp.Net Core程序中我们可以方便的通过以上[Config&lt;T&gt;](#32-configt)方式使用配置，但在其它.Net Core应用中DI并未默认被引入，我们可以考虑配置文件读取操作封装为一个工具类。考虑到配置文件热更新问题对象映射我们采用Config&lt;T&gt;方式处理。

代码已上传到Github，这里不再展开。
https://github.com/colin-chang/ConfigurationManager.Core

具体使用方式可以查看示例项目。
https://github.com/colin-chang/ConfigurationManager.Core/tree/master/ColinChang.ConfigurationManager.Sample

> 该帮助类已发布到Nuget

```sh
# Package Manager
Install-Package ColinChang.ConfigurationManager.Core 

# .NET CLI
dotnet add package ColinChang.ConfigurationManager.Core
```

## 6. Configuration框架解析

![Configuration框架解析](https://i.loli.net/2020/02/26/gjoYkJf2PiR83LO.jpg)