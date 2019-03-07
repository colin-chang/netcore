# Docker 常用命令

命令|说明
:-|:-
[`docker run/creat`](#1docker-runcreat)|运行或创建容器
[`docker start/stop/restart`](#2-docker-startstoprestart)|启动/停止/重启容器
[`docker ps`](#3-docker-ps)|列出容器
[`docker images`](#4-docker-images)|列出本地镜像
[`docker build`](#5-docker-build)|列出本地镜像
[`docker rm/rmi`](#6-docker-rmrmi)|删除容器或镜像
[`docker exec/attach`](#7-docker-execattach)|进入容器

Docker操作的相关指令非常多，详细的使用方法可以参考[官方文档](https://docs.docker.com/engine/reference/run/)，此处我们只列举部分常用命令及其使用注意事项。

Docker命令格式一般形如： `docker [command] [OPTIONS]` ，例如
```sh
# 查看docker帮助文档
$ docker -h

# 查看docker版本信息
$ docker version

# 查看docker系统信息，如镜像和容器信息，docker版本，CPU/内存，系统架构等
$ docker info
```

## 1.docker run/creat
`docker run`命令用于创建并启动指定镜像的一个容器。容器进程是独立和相对封闭的，其拥有独立的文件系统，网络配置，进程树等，类似于一个微型的系统。详细使用方式参见[官方文档](https://docs.docker.com/engine/reference/commandline/run/)。`docker create`用于创建一个一个容器但不启动，语法与`docker run`相同。

```sh
# 命令格式
$ docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

options|含义
:-|:-
`-i`|以交互模式运行容器，通常与 -t 同时使用
`-t`|为容器重新分配一个伪输入终端，通常与 -i 同时使用
`-d`|后台运行容器，并返回容器ID
`-p`|端口映射。格式为：宿主端口(host port):容器端口(container port)
`-e`|设置环境变量
`-v`|挂载卷。如`docker run -p 80:80 -v /data:/data -d nginx`以后台模式启动一个容器,将容器的 80 端口映射到主机的 80 端口,主机的目录 /data 映射到容器的 /data
`--name`|指定容器名称，不指定则会由系统产生一个随机名字
`--link`|添加链接到另一个容器。如`docker run -p 80:80 --link lottery:web nginx`运行nginx容器并连链接lottery容器同时指定lottery容器链接别名为web。链接可以实现容器间相互访问。
`--restart`|容器退出后重启策略。默认为no。可选项`no,always,unless-stopped,on-failure[:max-retries]`

```sh
$ docker run \
-d \                                                        # 后台方式运行
--name my-mysql \                                           # 命名当前容器为mac-mysql
-e MYSQL_ROOT_PASSWORD=pwd \                                # 指定root用户密码为pwd
mysql                                                       # 运行mysql容器

$ docker run \
-it \                                                       # 前台终端交互方式运行
--name my-lottery \                                         # 命名当前容器为my-lottery
--link my-mysql:mysql                                       # 链接到名称为my-mysql的容器并指定别名为mysql
lottery                                                     # 运行lottery容器

$ docker run \
-d \                                                        # 后台方式运行
--name my-nginx \                                           # 命名当前容器为my-nginx
-p 8000:80 \                                                # 宿主机8000端口映射为容器80端口
-v ~/nginx/default.conf:/etc/nginx/conf.d/default.conf \    # 宿主机~/nginx/default.conf挂载到容器为/etc/nginx/conf.d/default.conf
--link my-lottery:web \                                     # 链接到名称为lottery的容器并指定别名为web
--restart always   \                                        # 退出后总是自动重启
nginx                                                       # 运行nginx容器
```

## 2. docker start/stop/restart
* docker start :启动一个或多个已经被停止的容器
* docker stop :停止一个运行中的容器
* docker restart :重启容器

```sh
# 命令格式
$ docker start [OPTIONS] CONTAINER [CONTAINER...]
```

```sh
# 启动容器 my_container
$ docker start my_container

# 停止容器 my_container
$ docker stop my_container

# 重启容器 my_container
$ docker restart my_container
```

## 3. docker ps
`docker ps`用于列出容器。

```sh
# 命令格式
docker ps [OPTIONS]
```

options|含义
:-|:-
`-a `|显示所有的容器。不指定则默认只显示正在运行的容器
`-f `|根据条件过滤显示的内容
`-l `|显示最近创建的一个容器
`-n `|列出最近创建的n个容器
`-q `|仅显示容器简短Id
`-s `|显示总的文件大小

*每个容器都有唯一的"CONTAINER ID"和NAME。ID有完整长ID和简短ID，两者都可以标识容器。*

```sh
# 显示所有容器ID
$ docker ps -aq

# 显示所有lottery镜像的容器
$ docker ps -a -f=ancestor=lottery
```

## 4. docker images
`docker images`用于列出本地镜像。

```sh
# 命令格式
$ docker images [OPTIONS] [REPOSITORY[:TAG]]
```

options|含义
:-|:-
`-a `|列出本地所有的镜像（含中间映像层，默认情况下，过滤掉中间映像层）
`-f `|显示满足条件的镜像
`-q `|只显示镜像ID

```sh
# 列出本地镜像
$ docker images
```

## 5. docker build
`docker build`命令可以使用Dockerfile构建镜像。Dockerfile相关内容参见[制作镜像](docker-dockerfile.md)。

```sh
# 命令格式
$ docker build [OPTIONS] PATH | URL | -
```

options|含义
:-|:-
`-t`|镜像的名字及标签，通常 name:tag 或者 name 格式；可以在一次构建中为一个镜像设置多个标签
`-f` |Dockerfile名称。(默认为 ‘PATH/Dockerfile’)
`--pull`|尝试去更新镜像的新版本

```sh
# 在当前目录下使用Dockerfile构建名为"colin/webapp"的镜像，tag为1.0
$ docker build -t colin/webapp:1.0 .
```

## 6. docker rm/rmi
### 6.1 docker rm
`docker rm`用于删除容器。删除容器之前需要先停止容器。

options|含义
:-|:-
`-f `|通过SIGKILL信号强制删除一个运行中的容器
`-l `|移除容器间的网络连接，而非容器本身
`-v `|-v 删除与容器关联的卷

```sh
# 删除my-nginx容器
$ docker rm my-nginx

# 删除所有容器
$ docker rm $(docker ps -aq)

# 删除所有ubuntu镜像的容器
$ docker rm $(docker ps -aq -f=ancestor=ubuntu)
```

### 6.2 docker rmi
`docker rmi`用于删除镜像。删除容器之前需要先停止容器。删除镜像之前必须把所有这个镜像的容器删除。使用`docker image rm`指令也可以删除镜像。

```sh
# 删除所有nginx镜像的容器
$ docker rm $(docker ps -aq -f=ancestor=nginx)
# 删除nginx镜像
$ docker rmi nginx
```

## 7. docker exec/attach
进入Docker容器有多种方式，这里我们介绍最简单的`docker attach`和`docker exec`两种方式
### 7.1 docker attach
`docker attach`用于附加本地终端输入输出及错误流信息到一个运行中的容器。如果容器创建时未指定交互式(-it)运行，可能无法通过`docker attach`进入到容器中。为了确保可以通过`docker attach`进入容器，执行`docker run`时需要指定`-it`，并在启动后执行`/bin/bash`。如
`docker run -itd --name mysql -e MYSQL_ROOT_PASSWORD=pwd mysql /bin/bash`

`docker attach`命令进入容器后，可以使用`Ctrl+C`，`Ctrl+D`,`exit`等方式退出，如果container当前在运行bash，CTRL-C自然是当前行的输入，没有退出；如果container当前正在前台运行进程，如输出nginx的access.log日志，CTRL-C不仅会导致退出容器，而且还stop了。退出还可能会导致容器关闭，在attach是可以带上--sig-proxy=false来确保CTRL-D或CTRL-C不会关闭容器。

docker attach有诸多不便之处，推荐使用`docker exec`方式进入容器替代。

```sh
$ docker attach --sig-proxy=false mysql
```

### 7.2 docker exec
`docker exec`可以进入容器内执行命令。使用方式比较简单，详见[官方文档](https://docs.docker.com/engine/reference/commandline/exec/)

```sh
# 进入my-nginx容器并开启一个交互式终端
$ docker exec -it my-nginx /bin/bash
```