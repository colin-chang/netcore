# Asp.Net Core 无处不在的“依赖注入”

ASP.NET Core的核心是通过一个Server和若干注册的Middleware构成的管道，不论是管道自身的构建，还是Server和Middleware自身的实现，以及构建在这个管道的应用，都需要相应的服务提供支持，ASP.NET Core自身提供了一个DI容器来实现针对服务的注册和消费。换句话说，不只是ASP.NET Core底层框架使用的服务是由这个DI容器来注册和提供，应用级别的服务注册和提供也需要依赖这个DI容器。学习ASP.NET Core，你必须了解无处不在的“依赖注入”。

说到依赖注入（Dependency Injection，以下简称DI），就必须说IoC（Inverse of Control），很多人将这两这混为一谈，其实这是两个完全不同的概念，或者是不同“层次”的两个概念。在本系列后续[控制反转（IoC）](#ioc.md)和[依赖注入（DI）](#di.md)中有详细讲解。

DI框架具有两个核心的功能，即服务的注册和提供，这两个功能分别由对应的对象来承载, 它们分别是ServiceCollection和ServiceProvider。如下图所示，我们将相应的服务以不同的生命周期模式（Transient、Scoped和Singleton）注册到ServiceCollection对象之上，在利用后者创建的ServiceProvider根据注册的服务类型提取相应的服务对象。

![ServiceCollection和ServiceProvider](https://s2.ax1x.com/2020/01/19/19o5wt.jpg)