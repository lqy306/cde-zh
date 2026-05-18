# cde-zh

## 效果展示：

<img width="1718" height="921" alt="image" src="https://github.com/user-attachments/assets/2279def7-06b2-4ebf-886a-f656e7b47176" />

<img width="1280" height="720" alt="FreeBSD-2026-05-18-18-27-59" src="https://github.com/user-attachments/assets/34028766-f0ad-4210-921e-933b8f1ebff9" />

## 介绍

这是一个Common Desktop Environment的快速汉化编译安装工具。

这是一个很简单的脚本。事实上，CDE原版的源码已经包含了中文（programs/localized），所以脚本只是修改了编译参数开启了默认编译中文语言支持。

将脚本复制到CDE源码下即可安装。安装前，请确认你的系统安装了你目标语言的local（比如zh_CN或zh_TW）。

Linux用户使用build_linux.sh，FreeBSD用户使用preprocessing_freebsd.sh（预处理）。

## 依赖说明

顺便补充一下官方关于安装依赖的说明：

### Debina（Ubuntu）

```sh
sudo apt-get -y install autoconf automake libtool git build-essential g++ libxt-dev libxmu-dev \
libxft-dev libxinerama-dev libxpm-dev libpam0g-dev libmotif-dev libssl-dev libxaw7-dev libx11-dev \
libxss-dev libtirpc-dev libjpeg-dev libfreetype-dev libutempter-dev libxrender-dev tcl-dev ksh m4 \
ncompress xfonts-100dpi xfonts-75dpi xfonts-100dpi-transcoded xfonts-75dpi-transcoded rpcbind bison \
patch xbitmaps x11proto-fonts-dev flex opensp x11-xserver-utils liblmdb-dev
```

### RHEL（Fedora）

```sh
sudo dnf group install c-development development-tools
sudo dnf install pam-devel libutempter-devel libXp-devel libXt-devel libXmu-devel libXft-devel libXinerama-devel libXpm-devel \
motif motif-devel libXaw-devel libX11-devel libXScrnSaver libtirpc-devel xset sessreg xrdb \
libjpeg-turbo-devel freetype-devel openssl-devel tcl-devel ksh m4 ncompress patch \
rpcbind bison xorg-x11-xbitmaps xorg-x11-proto-devel flex opensp libXrender-devel \
xorg-x11-fonts-100dpi rpcgen bdftopcf libXdmcp-devel
```

### OpenSUSE

```sh
sudo zypper install git autoconf automake libtool gcc-c++ motif motif-devel make \
m4 ksh libXinerama-devel libXdmcp-devel libXScrnSaver-devel libXmu-devel libXaw-devel \
libXft-devel xset libtirpc-devel libjpeg-devel tcl-devel ncompress bison rpcbind \
freetype-devel libopenssl-devel pam-devel patch bdftopcf libutempter-devel opensp \
libXrender-devel sessreg lmdb-dev
```

### FreeBSD

```sh
portmaster -C -D --no-confirm -y \
  x11/xorg \
  devel/git \
  converters/iconv \
  shells/ksh93 \
  x11-toolkits/open-motif \
  lang/tcl86
  textproc/opensp
```
