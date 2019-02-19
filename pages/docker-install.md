# Docker 安装配置

* [1. 安装Docker](#1-安装docker)
* [2. 加速器和镜像市场](#2-加速器和镜像市场)

## 1. 安装Docker
Docker安装方法可以参考[官网步骤](https://docs.docker.com/install/)。
Windows和MacOS中可以都可以使用[Docker Desktop](https://www.docker.com/products/docker-desktop)，界面化操作表简单，此处不作介绍。下面我们以Ubuntu 18.04为例讲解安装步骤。

```sh
# 安装docker
$ sudo apt-get install docker.io

# 查看docker版本
$ sudo docker version

# 查看 docker 系统信息
$ sudo docker info

# 下载镜像，如mysql
$ sudo docker pull mysql
```

## 2. 加速器和镜像市场
国内访问Docker Hub可能速度比较慢。我们可以考虑使用加速器和镜像市场。加速器是代理服务器,最终还是访问官方网站,和官网一致和镜像市场的区别，如阿里云或者 DaoCloud 等加速器。镜像市场是私服,不和官网一致，如[DaoCloud 镜像市场](https://hub.daocloud.io/)等。

### 1）镜像市场
如果使用国内镜像市场镜像直接使用`docker pull`命令拉取即可，一般镜像市场都用使用说明。如

```sh
# 拉取DaoCloud镜像市场的MySQL
$ docker pull daocloud.io/library/mysql
```

### 2）加速器
使用镜像加速器可以按照第三方加速器说明配置即可，如 [DaoCloud加速器](https://www.daocloud.io/mirror)

## 3. 配置docker用户组
Linux中每次执行docker指令都需要`sudo`比较麻烦，我们可以把操作用户加入docker用户组来解决。
```sh
# 添加docker用户组
$ sudo groupadd docker

# 将当前操作用户添加到docker组
$ sudo gpasswd -a CurrentUserName docker # CurrentUserName为当前操作的用户名

# 重启docker服务
$ sudo service docker restart

# 注销用户后重新登录即可
$ logout
```