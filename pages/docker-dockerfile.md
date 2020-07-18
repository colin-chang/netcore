# 制作镜像

* [1. 镜像简介](#1-镜像简介)
* [2. Dockerfile 指令](#2-dockerfile-指令)
* [3. 制作网站镜像](#3-制作网站镜像)

## 1. 镜像简介
Docker容器是一个相对独立运行的Linux服务器环境，在其中部署了我们需要的各种环境和服务，而这些都是在Docker镜像中定义的。

Docker容器最终多作为一个服务提供者角色（微服务）而存在，如MySQL,Nginx,Redis等镜像的容器。此外也有很多镜像只搭建一些特定的环境，并未直接提供服务，此种镜像多作为被继承者为其它镜像提供基础层，如microsoft/dotnet(.net core),python等。我们常在此类镜像基础上部署自己的网站或服务，打包成自定义镜像。

Docker 镜像是一个特殊的文件系统，除了提供容器运行时所需的程序、库、资源、配置等文件外，还包含了一些为运行时准备的一些配置参数（如匿名卷、环境变量、用户等）。我们通过`docker pull IMAGE`来获取使用他人公开的镜像。也可以通过Dockerfile来定制自己的镜像。

Dockerfile构建的镜像只能在本地使用，上传到DockerHub或者自己的搭建私服后才可以供别人使用。

如下是自定义mysql镜像Dockerfile示例(mysql官方有公开镜像，此处仅作示例之用)。

```sh
FROM ubuntu
RUN echo 'mysql-server mysql-server/root_password password root'|debconf-set-selections
RUN echo 'mysql-server root'|debconf-set-selections
RUN apt-get update
RUN apt-get install -y mysql-server
RUN /etc/init.d/mysql restart &&\
 mysql -uroot -proot -e "grant all privileges on *.* to 'root'@'%' identified by 'root'" &&\
 mysql -uroot -proot -e "show databases;"
EXPOSE 3306
CMD ["/etc/init.d/mysql","restart"]
```

## 2. Dockerfile 指令

options|含义
:-|:-
`FROM`|表示当前镜像继承自哪个镜像
`WORKDIR`|指定工作目录
`CP`|将宿主机文件或目录拷贝到容器中
`RUN`|**镜像构建时**执行命令。多用作预装软件修改配置等
`EXPOSE`|服务允许暴露端口
`CMD/ENTRYPOINT`|**镜像容器启动时**执行命令。多用于启动服务、运行程序等


每个Dockerfile只能有一条`CMD`命令，如果指定了多条,只有最后一条会被执行。

**如果容器启动时不指定参数,则`CMD`和`ENTRYPOINT`是一样的。否则`CMD`指定的命令会被`docker run` 的容器参数覆盖, 而`ENTRYPOINT`则会把容器参数传递给自身指定的命令。**

通过以下案例简单可以证明以上`CMD`和`ENTRYPOINT`的区别。

1) 有使用`CMD`的Dockerfile如下:
```sh
FROM ubuntu
CMD ["uname"]
```
创建并启动容器。
```sh
# 构建镜像
$ docker build -t cmd .

# 创建并启动容器
$ docker run -it cmd         # 输出 Linux
$ docker run -it cmd -a      # 错误输出。"-a": executable file not found in $PATH"
$ docker run -it cmd whoami  # 输出 root
```
以上案例中，容器启动时`-a`和`whoami`参数都将覆盖镜像中`CMD`指定的`uname`命令。所以最终运行的分别是`-a`和`whoami`指令。`-a`指令不存在所以运行报错，`whoami`指令则输出当前用户`root`。

2) 有使用`ENTRYPOINT`的Dockerfile如下:
```sh
FROM ubuntu
ENTRYPOINT ["uname"]
```
创建并启动容器。
```sh
# 构建镜像
$ docker build -t entrypoint .

# 创建并启动容器
$ docker run -it entrypoint         # 输出 Linux
$ docker run -it entrypoint -a      # 输出 Linux 06968e7efc5d 4.9.125-linuxkit #1 SMP Fri Sep 7 08:20:28 UTC 2018 x86_64 x86_64 x86_64 GNU/Linux
$ docker run -it entrypoint whoami  # 错误输出 uname: extra operand 'whoami'
```
以上案例中，容器启动时`-a`和`whoami`参数都将作为`ENTRYPOINT`指定的`uname`命令的参数。所以最终运行的分别是`uname -a`和`uname whoami`指令。`whoami`参数非法所以最后一条命令报错。

* `RUN` 是构建镜像时执行的指令,用于安装软件、修改配置等初始化的代码, 可以执行多条;
* `CMD` 相当于镜像的默认开机指令,只能指定一条 CMD,容器运行参数可以覆盖 CMD;
* `ENTRYPOINT` 用于把镜像容器打造成可执行程序,容器运行参数作为可执行程序的参数;

## 3. 制作网站镜像
此处我们简单演示制作一个基于asp.net core的网站镜像，其他镜像制作大同小异。

假定我们网站程序已经构建完成并发布，此Dockerfile位于网站发布目录中。
```sh
FROM microsoft/dotnet:2.2-aspnetcore-runtime    # 基于asp.net core 2.2 runtime官方镜像制作本镜像
COPY . /publish                                 # 将宿主机当前目录下所有内容拷贝到镜像的/publish目录中
WORKDIR /publish                                # 设定当前工作目录为/publish
EXPOSE 5000/tcp                                 # 暴露tcp协议5000端口
CMD ["dotnet","WebApp.dll"]                     # 容器启动执行 dotnet WebApp.dll命令
```
创建并启动网站容器。
```sh
$ docker build -t colin/webapp:1.0 .            # 在当前目录下使用Dockerfile构建镜像命名为colin/webapp，tag为1.0
$ docker run \
-d \
--name webapp \
-p 8000:5000 \
--restart always \
colin/webapp:1.0                                # 创建并启动容器
```
完成以上操作后在宿主机通过 http://127.0.0.1:8000 即可访问我们的网站，如果需要暴露到外网，根据微软建议最好使用nginx等服务器作反代。

除了以上使用网站已发布内容构建Docker镜像，我们也可以在镜像构建过程中完成源码编译、测试，发布，部署等过程。以[lottery](https://github.com/TechnologyGeeks/lottery)项目为例
```sh
FROM microsoft/dotnet:2.2-sdk AS build
WORKDIR /app

# copy csproj and restore as distinct layers
COPY *.sln .
COPY Colin.Lottery.WebApp/*.csproj ./Colin.Lottery.WebApp/
COPY Colin.Lottery.DataService/*.csproj ./Colin.Lottery.DataService/
COPY Colin.Lottery.Analyzers/*.csproj ./Colin.Lottery.Analyzers/
COPY Colin.Lottery.Collectors/*.csproj ./Colin.Lottery.Collectors/
COPY Colin.Lottery.Models/*.csproj ./Colin.Lottery.Models/
COPY Colin.Lottery.Common/*.csproj ./Colin.Lottery.Common/
COPY Colin.Lottery.Utils/*.csproj ./Colin.Lottery.Utils/
WORKDIR /app/Colin.Lottery.WebApp/
RUN dotnet restore

# copy and publish app and libraries
WORKDIR /app/
COPY Colin.Lottery.WebApp/. ./Colin.Lottery.WebApp/
COPY Colin.Lottery.DataService/. ./Colin.Lottery.DataService/
COPY Colin.Lottery.Analyzers/. ./Colin.Lottery.Analyzers/
COPY Colin.Lottery.Collectors/. ./Colin.Lottery.Collectors/
COPY Colin.Lottery.Models/. ./Colin.Lottery.Models/
COPY Colin.Lottery.Common/. ./Colin.Lottery.Common/
COPY Colin.Lottery.Utils/. ./Colin.Lottery.Utils/
WORKDIR /app/Colin.Lottery.WebApp/
RUN dotnet publish -c Release -o out

FROM build AS testcollector
WORKDIR /app/Colin.Lottery.Collectors.Test
COPY Colin.Lottery.Collectors.Test/. .
ENTRYPOINT ["dotnet", "test", "--logger:trx"]

FROM build AS testanalyzer
WORKDIR /app/Colin.Lottery.Analyzers.Test
COPY Colin.Lottery.Analyzers.Test/. .
ENTRYPOINT ["dotnet", "test", "--logger:trx"]

FROM microsoft/dotnet:2.2-aspnetcore-runtime AS runtime
WORKDIR /app
COPY --from=build /app/Colin.Lottery.WebApp/out ./
ENTRYPOINT ["dotnet", "Colin.Lottery.WebApp.dll"]
```

以上如果代码编译或测试出错则网站镜像构建通过，一定程度上避免了程序发布错误。