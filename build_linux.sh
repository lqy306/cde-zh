#!/bin/sh
# CDE 中文编译脚本 - 全自动版
# 放到 CDE 源码根目录下直接运行，无需人为干预

set -e

cd "$(dirname "$0")"
[ -f configure.ac ] || { echo "错误: 请在 CDE 源码根目录下运行"; exit 1; }

# ── 前置检查 ──
MISSING=
for cmd in autoconf automake libtoolize make cc; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
  echo "缺少构建工具:$MISSING"
  echo "请先安装: sudo apt install autoconf automake libtool build-essential"
  exit 1
fi

# ── 步骤1: 检查 locale（不请求 sudo） ──
echo "============================================"
echo "  步骤1: 检查系统 locale"
echo "============================================"
for l in zh_CN.utf8 zh_TW.utf8 en_US.utf8; do
  locale -a 2>/dev/null | grep -qi "$l" && echo "  $l 已存在" || echo "  $l 不存在（编译可能警告，不影响）"
done

# ── 步骤2: 修改构建系统 ──
echo "============================================"
echo "  步骤2: 添加中文编译支持"
echo "============================================"

# 避免重复修改
if ! grep -q 'enable-chinese' configure.ac 2>/dev/null; then
  sed -i '/AM_CONDITIONAL(\[JAPANESE\].*/a\
\
AC_ARG_ENABLE([chinese],\
        AS_HELP_STRING([--enable-chinese], [Build Chinese (zh_CN.UTF-8) locale (default=no)]),\
        [enable_zh="yes"], [enable_zh=""]\
)\
AM_CONDITIONAL([CHINESE], [test -n "$enable_zh"])\
\
AC_ARG_ENABLE([chinese-tw],\
        AS_HELP_STRING([--enable-chinese-tw], [Build Chinese Traditional (zh_TW.UTF-8) locale (default=no)]),\
        [enable_zt="yes"], [enable_zt=""]\
)\
AM_CONDITIONAL([CHINESE_TW], [test -n "$enable_zt"])' configure.ac
fi

if ! grep -q 'zh_CN.UTF-8/Makefile' configure.ac 2>/dev/null; then
  sed -i '/programs\/localized\/ja_JP.UTF-8\/appmanager\/Makefile/a\
programs\/localized\/zh_CN.UTF-8\/Makefile\
programs\/localized\/zh_CN.UTF-8\/app-defaults\/Makefile\
programs\/localized\/zh_CN.UTF-8\/config\/Makefile\
programs\/localized\/zh_CN.UTF-8\/backdrops\/Makefile\
programs\/localized\/zh_CN.UTF-8\/types\/Makefile\
programs\/localized\/zh_CN.UTF-8\/palettes\/Makefile\
programs\/localized\/zh_CN.UTF-8\/msg\/Makefile\
programs\/localized\/zh_CN.UTF-8\/appmanager\/Makefile\
programs\/localized\/zh_TW.UTF-8\/Makefile\
programs\/localized\/zh_TW.UTF-8\/app-defaults\/Makefile\
programs\/localized\/zh_TW.UTF-8\/config\/Makefile\
programs\/localized\/zh_TW.UTF-8\/backdrops\/Makefile\
programs\/localized\/zh_TW.UTF-8\/types\/Makefile\
programs\/localized\/zh_TW.UTF-8\/palettes\/Makefile\
programs\/localized\/zh_TW.UTF-8\/msg\/Makefile\
programs\/localized\/zh_TW.UTF-8\/appmanager\/Makefile' configure.ac
fi

if ! grep -q 'if CHINESE' programs/localized/Makefile.am 2>/dev/null; then
  sed -i '/if JAPANESE/,/endif/a\
\
if CHINESE\
SUBDIRS += zh_CN.UTF-8\
endif\
\
if CHINESE_TW\
SUBDIRS += zh_TW.UTF-8\
endif' programs/localized/Makefile.am
fi

# ── 步骤3: 创建 LANG 模板 ──
echo "==> 创建 LANG 模板..."
mkdir -p programs/localized/templates
cat > programs/localized/templates/Chinese.am <<'TMPL'
if SOLARIS
LANG=zh
else
LANG=zh_CN.UTF-8
endif
TMPL

cat > programs/localized/templates/Chinese_TW.am <<'TMPL'
if SOLARIS
LANG=zh
else
LANG=zh_TW.UTF-8
endif
TMPL

# ── 步骤4: 创建 Makefile.am ──
echo "==> 创建 zh_CN.UTF-8 构建文件..."
for base in zh_CN.UTF-8 zh_TW.UTF-8; do
  case "$base" in
    zh_CN.UTF-8) tmpl=Chinese ;;
    zh_TW.UTF-8) tmpl=Chinese_TW ;;
  esac

  mkdir -p "programs/localized/$base"/{app-defaults,config,backdrops,palettes,types,msg,appmanager}

  cat > "programs/localized/$base/Makefile.am" <<EOF
SUBDIRS = types config msg app-defaults palettes backdrops appmanager
EOF

  for sub in app-defaults config backdrops palettes types msg; do
    cat > "programs/localized/$base/$sub/Makefile.am" <<EOF
MAINTAINERCLEANFILES = Makefile.in

include ../../templates/$tmpl.am
include ../../templates/$sub.am
EOF
  done

  for d in Desktop_Apps Desktop_Tools Education Games Graphics Information Internet Media_Tools Office System TeX; do
    mkdir -p "programs/localized/$base/appmanager/$d"
  done

  cat > "programs/localized/$base/appmanager/Makefile.am" <<EOF
MAINTAINERCLEANFILES = Makefile.in

include ../../templates/$tmpl.am
include ../../templates/appmgr.am
EOF
done

# ── 步骤5: 修复中文翻译文件缺失/损坏 ──
echo "==> 修复中文翻译文件..."
for base in zh_CN.UTF-8 zh_TW.UTF-8; do
  for f in Dtlogin Dtbuilder Dtudcfonted Dtinfo; do
    [ -f "programs/localized/$base/app-defaults/$f.tmsg" ] || printf '$set 1\n' > "programs/localized/$base/app-defaults/$f.tmsg"
  done
done

# 修复 zh_TW 翻译文件中未闭合的引号
FWS=$(printf '\343\200\200')
[ -f "programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg" ] && \
  sed -i "s/ ${FWS}$/ \"/" programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg 2>/dev/null || true
[ -f "programs/localized/zh_TW.UTF-8/msg/dthello.msg" ] && \
  sed -i '84s/$/"/' programs/localized/zh_TW.UTF-8/msg/dthello.msg 2>/dev/null || true

# ── 步骤6: autogen.sh ──
echo "============================================"
echo "  步骤6: 运行 autogen.sh"
echo "============================================"
chmod +x autogen.sh
./autogen.sh

# ── 步骤7: configure ──
echo "============================================"
echo "  步骤7: configure"
echo "============================================"
./configure --enable-chinese --enable-chinese-tw "$@"

# ── 步骤8: 编译 ──
echo "============================================"
echo "  步骤8: make -j$(nproc)"
echo "============================================"
make -j$(nproc)

echo ""
echo "============================================"
echo "  编译成功！"
echo "  安装: sudo make install"
echo "  启动: startx /usr/dt/bin/Xsession"
echo "============================================"
