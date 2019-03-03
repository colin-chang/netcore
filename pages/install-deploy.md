# .Net Core 部署

* [1. Linux(Kestrel+Nginx)](#1-linuxkestrelnginx)
* [2. Windows(Kestrel+IIS)](#2-windowskestreliis)
* [3. Docker](#3-docker)

.Net Core程序可以部署在Windows/Linux/mac平台上。Mac较多的用于开发，鲜少用做服务器环境。下面我们以Asp.Net Core为例，简单梳理一下。

.net core程序无论是调试还是发布版本，都**建议在程序目录下运行命令，否则可能会出现静态资源文件无法访问的问题**。

> 发布命令 `dotnet publish -c Release`

## 1. Linux(Kestrel+Nginx)
在Linux中也可以使用 `dotnet ./your_app.dll` 方式在终端中运行.Net Core程序，但是退出终端后，程序就停止了。我们可以将运行命令封装到一个Linux服务中，服务器启动后就可以在后台静默运行了。

systemd 可用于创建服务文件以启动和监视基础 Web 应用。 systemd 是一个 init 系统，可以提供用于启动、停止和管理进程的许多强大的功能。

* 创建服务文件

    ```sh
    $ sudo vi /etc/systemd/system/lottery.service
    ```

* 服务文件示例

    ```sh
    [Unit]
    # 服务描述
    Description=Lottery

    [Service]
    # 工作目录，此处为.net core程序目录
    WorkingDirectory=/home/colin/apps/content/lottery
    # dotnet核心命令
    ExecStart=/usr/bin/dotnet /home/colin/apps/content/lottery/Lottery.WebApp.dll
    # 重启策略
    Restart=always
    RestartSec=10
    # 日志标识
    SyslogIdentifier=dotnet-lottery
    # 用户
    User=colin
    # 环境变量
    Environment=ASPNETCORE_ENVIRONMENT=Production
    Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

    [Install]
    WantedBy=multi-user.target
    ```

* 服务管理

    ```sh
    # 启用服务
    $ sudo systemctl enable lottery.service

    # 启动服务
    $ sudo systemctl start lottery.service

    # 查看服务状态
    $ sudo systemctl status lottery.service

    # 停止服务
    $ sudo systemctl stop lottery.service

    # 重启服务
    $ sudo systemctl restart lottery.service
    ```

完成以上步骤之后，Asp.Net Core程序已经挂载到了Kestrel服务器上并以Linux服务方式后台静默运行。虽然Kestrel服务器对Asp.Net支持非常好，但微软不建议其作为对外服务器，而是建议使用IIS/Nginx/Apache等作为代理服务器对外开放。

关于Linux下Nginx部署，参阅：

https://colin-chang.site/linux/part2/nginx.html

https://docs.microsoft.com/zh-cn/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-2.2

Apache配置，参阅：

https://docs.microsoft.com/zh-cn/aspnet/core/host-and-deploy/linux-apache?view=aspnetcore-2.2

## 2. Windows(Kestrel+IIS)
Asp.Net Core应用程序部署要求Windows系统环境为：
* Windows 7 或更高版本
* Windows Server 2008 R2 或更高版本

整体部署于传统Asp.Net MVC部署方式相似。使用Kestrel+IIS的进程外承载模型时，需要为IIS安装[`AspNetCoreModule`](https://docs.microsoft.com/zh-cn/aspnet/core/host-and-deploy/aspnet-core-module?view=aspnetcore-2.2)，然后将应用程序池的.NET CLR版本设置为无托管代码即可。

Windows 下.Net Core部署流程参阅：
https://docs.microsoft.com/zh-cn/aspnet/core/host-and-deploy/iis/?view=aspnetcore-2.2

## 3. Docker

.Net Core可以使用Docker技术实现跨平台的容器部署。
* .Net Core应用程序Docker部署参阅[制作网站镜像](docker-dockerfile.md)
* Nginx反代服务器Docker部署参阅https://colin-chang.site/linux/part2/nginx.html。

可以参阅[lottery](https://github.com/TechnologyGeeks/lottery)项目的部署过程。