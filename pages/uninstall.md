# .Net Core 安装卸载

作为新一代微软高效跨平台技术，.Net Core自诞生以来就是跨平台的，目前支持Windows/mac OS/Linux平台。

Linux发行版众多，截止到写这篇文档时，.Net Core 2.2支持的Linux发行版如下：

* RHEL
* Ubuntu 18.04
* Ubuntu 16.04
* Ubuntu 14.04
* Debian 9
* Debian 8
* Fedora 28
* Fedora 27
* CentOS / Oracle
* openSUSE Leap
* SLES

## 1. 安装
.Net Core的安装异常简单。到[官网下载](https://dotnet.microsoft.com/download)安装即可。Windows和Mac中都是下载安装包，双击运行安装，不再赘述。Linux选择对应的发行版本，执行官方的安装命令即可。

如果想体验最新版的.Net Core的特性，则可以到.Net Core的Github项目中下载。这里有.Net Core所有版本，包括历史版本和预览版本。
https://github.com/dotnet/core/tree/master/release-notes

.Net Core安装包分为`Runtime`和`SDK`。如果只期望在平台上运行.Net Core程序，安装`Runtime`包即可。如果希望在平台上使用.Net Core的高级功能，如开发调试等，则需要安装`SDK`包。`SDK`包含了`Runtime`。

## 2. 卸载
.Net Core在Windows卸载非常简单，直接在控制面板中卸载即可。至于Mac和Linux环境下卸载就比较麻烦了。由于安装文件比较分散，所以删除和清理工作也比较繁琐，幸好.NET Foundation提供了卸载脚本。

```sh
#!/usr/bin/env bash
#
# Copyright (c) .NET Foundation and contributors. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

current_userid=$(id -u)
if [ $current_userid -ne 0 ]; then
    echo "$(basename "$0") uninstallation script requires superuser privileges to run" >&2
    exit 1
fi

# this is the common suffix for all the dotnet pkgs
dotnet_pkg_name_suffix="com.microsoft.dotnet"
dotnet_install_root="/usr/local/share/dotnet"
dotnet_path_file="/etc/paths.d/dotnet"

remove_dotnet_pkgs(){
    installed_pkgs=($(pkgutil --pkgs | grep $dotnet_pkg_name_suffix))
    
    for i in "${installed_pkgs[@]}"
    do
        echo "Removing dotnet component - \"$i\"" >&2
        pkgutil --force --forget "$i"
    done
}

remove_dotnet_pkgs
[ "$?" -ne 0 ] && echo "Failed to remove dotnet packages." >&2 && exit 1

echo "Deleting install root - $dotnet_install_root" >&2
rm -rf "$dotnet_install_root"
rm -f "$dotnet_path_file"

echo "dotnet packages removal succeeded." >&2
exit 0
```
使用以上脚本卸载即可。

如果对shell脚本不熟悉的小伙伴也可以使用以下命令快速卸载，以mac为例，
```sh
$ curl -o uninstall.sh https://gist.githubusercontent.com/colin-chang/1d8da588f399165924dc62dad42598d8/raw/50444ab4db30ab8d6205216dec0c3983333a5d6b/dotnet-uninstall-pkgs.sh
$ chmod -R 740 uninstall.sh
$ sudo sh uninstall.sh
$ rm uninstall.sh
```