# AutoMappper

* [1. 简介](#1-简介)
* [2. 基础应用](#2-基础应用)
    * [2.1 简单映射](#21-简单映射)
    * [2.2 扁平化映射](#22-扁平化映射)
    * [2.3 忽略成员](#23-忽略成员)
    * [2.4 自定义映射](#24-自定义映射)
    * [2.5 自定义多层映射](#25-自定义多层映射)
* [3. 高级应用](#3-高级应用)
    * [3.1 自定义值解析](#31-自定义值解析)
    * [3.2 动态类型映射](#32-动态类型映射)
    * [3.3 其他](#33-其他)

## 1. 简介

[Automapper](https://automapper.org/) 是一个简单而强大的工具库帮助我们处理对象之间的映射。这些工作通常是枯燥乏味的。目前该项目已被.NET基金会所支持。

问AutoMapper有多强大，一句话总结，AutoMapper可以处理几乎所有对象间映射的复杂场景。

## 2. 基础应用
AutoMapper 支持:

* .NET 4.6.1+
* .NET Standard 2.0+

通过[Nuget](https://www.nuget.org/packages/AutoMapper/)获取AutoMappper即可使用。

### 2.1 简单映射
```csharp
public class User
{
    public int Id { get; set; }
    public int Age { get; set; }
    public string Name { get; set; }
}

public class UserDTO
{
    public int Id { get; set; }
    public int Age { get; set; }
    public string Name { get; set; }
}

void BasicMap()
{
    //初始化映射关系
    Mapper.Initialize(cfg => cfg.CreateMap<User, UserDto>());

    var user = new User {Id = 1, Age = 18, Name = "Colin"};
    var userDto = Mapper.Map<User, UserDto>(user);//对象映射
}
```

AutoMapper中存在以下常用特性：
* AutoMapper将自动**忽略空引用**异常
* 对象成员映射**不区分大小写**
* 继承对象支持映射。

### 2.2 扁平化映射
遵守AutoMapper映射约定命名规范，可以实现对象扁平化映射。目标类属性必须是 源类型中 复杂属性名称+复杂属性类型的内部属性名称。AutoMapper会深度搜索目标类，直到找到匹配的属性为止。

```csharp
public class Employee
{
    public string Name { get; set; }
    public Company Company { get; set; }
}

public class Company
{
    public string Name { get; set; }
    public string Address { get; set; }
}

public class EmployeeDto
{
    public string Name { get; set; }
    public string CompanyName { get; set; }
    public string CompanyAddress { get; set; }
}

void FlatMap()
{
    Mapper.Initialize(cfg => cfg.CreateMap<Employee, EmployeeDto>());

    var employee = new Employee
    {
        Name = "Colin",
        Company = new Company
        {
            Name = "Chanyi",
            Address = "Beijing"
        }
    };
    var employeeDto = Mapper.Map<Employee, EmployeeDto>(employee);
}
```

### 2.3 忽略成员
对象映射过程中有些属性可能用不到，我们通过Ignore方法指定忽略映射属性，以减少映射开支和传输流量。

```csharp
Mapper.Initialize(cfg => cfg.CreateMap<User, UserDto>()
    .ForMember(d => d.Age, o => o.Ignore()));//忽略Age属性映射

var user = new User {Id = 1, Age = 18, Name = "Colin"};
var userDto = Mapper.Map<User, UserDto>(user);
```

### 2.4 自定义映射
当源对象和目标对象的存在不同名或不同级的对应关系时，就需要在初始化映射时手动配置自定义映射关系。

```csharp
public class Article
{
    public int Id { get; set; }
    public string Content { get; set; }
    public string TypeName { get; set; }
    public IEnumerable<string> Messages { get; set; }
}

public class ArticleDto
{
    public int Id { get; set; }
    public string Content { get; set; }
    public string Category { get; set; }
    public IEnumerable<string> Comments { get; set; }
}

void CustomMap()
{
    Mapper.Initialize(cfg => cfg.CreateMap<Article, ArticleDto>()
        .ForMember(d => d.Category, o => o.MapFrom(s => s.TypeName))
        .ForMember(d => d.Comments, o => o.MapFrom(s => s.Messages))
    );

    var article = new Article
        {Id = 0, Content = "content", TypeName = "fiction", Messages = new[] {"Good"}};
    var articleDto = Mapper.Map<Article, ArticleDto>(article);
}
```

### 2.5 自定义多层映射
自定义复杂对象映射中集合子元素或成员复杂类型又需要自定义映射关系时，姑且称为自定义多层映射，此时我们就需要手动逐个配置映射关系。

```csharp
public class Customer
{
    public int Id { get; set; }
    public string Name { get; set; }
    public IEnumerable<Order> Orders { get; set; }
}

public class Order
{
    public int Id { get; set; }
    public string TradeNo { get; set; }
    public int TotalFee { get; set; }
}

public class CustomerDto
{
    public int Id { get; set; }
    public string Name { get; set; }
    public IEnumerable<OrderDto> OrderDtos { get; set; }
}

public class OrderDto
{
    public int Id { get; set; }
    public string TradeNo { get; set; }
    public int TotalFee { get; set; }
}

void MultilayerMap()
{
    Mapper.Initialize(cfg =>
    {
        //多层映射配置
        cfg.CreateMap<Order, OrderDto>();
        cfg.CreateMap<Customer, CustomerDto>()
            .ForMember(d => d.OrderDtos, o => o.MapFrom(s => s.Orders));//子成员属性映射
    });

    var customer = new Customer()
    {
        Id = 0,
        Name = "Colin",
        Orders = new List<Order>
        {
            new Order()
            {
                Id = 0,
                TotalFee = 10,
                TradeNo = "123456"
            }
        }
    };
    var customerDto = Mapper.Map<Customer, CustomerDto>(customer);
}
```

## 3. 高级应用
### 3.1 自定义值解析
AutoMapper支持自定义解析，需要提供IValueResolver对象。

```csharp
public class Student
{
    public string Name { get; set; }
    public int Score { get; set; }
}

public class StudentDto
{
    public string Name { get; set; }
    public Grade Score { get; set; }
}

public enum Grade { A, B, C }

//自定义解析器
public class ScoreResolver : IValueResolver<Student, StudentDto, Grade>
{
    public Grade Resolve(Student source, StudentDto destination, Grade destMember, ResolutionContext context)
    {
        var score = source.Score;
        if (score >= 90)
            return Grade.A;
        else if (score >= 80)
            return Grade.B;
        else
            return Grade.C;
    }
}

void ValueResolverMap()
{
    Mapper.Initialize(cfg =>
        cfg.CreateMap<Student, StudentDto>().ForMember(d => d.Score, o => o.MapFrom<ScoreResolver>()));

    var student = new Student {Name = "Colin", Score = 95};
    var studentDto = Mapper.Map<Student, StudentDto>(student);
}
```

### 3.2 动态类型映射
AutoMapper支持.Net动态对象映射。
```csharp
private static void DynamicMap()
{
    Mapper.Initialize(cfg => { });//动态类型映射不需要初始化配置内容

    dynamic user = new ExpandoObject();
    user.Id = 1;
    user.Name = "Colin";
    user.Age = 18;

    var u = Mapper.Map<User>(user);
}
```

### 3.3 其他
AutoMapper支持依赖注入，支持ORM等。如对EF的支持示例如下：

```csharp
IQueryable<Customer> customers = null;
var customersDTO = customers.ProjectTo<CustomerDTO>();
```

**结束语：**

以上只是简单列举了AutoMapper的常用情景，其功能远不止如此，AutoMapper功能异常强大，几乎覆盖了对象映射的所有场景。更多更详尽的AutoMapper使用可以查阅其[官方文档](https://automapper.readthedocs.io/en/latest/)。

本文档中所有示例代码已共享到Github。

代码下载地址：https://github.com/colin-chang/AutoMapperSample

> 参考文档

* https://yq.aliyun.com/articles/318075/
* https://automapper.readthedocs.io/en/latest/