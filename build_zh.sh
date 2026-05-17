#!/bin/sh
# CDE 中文编译脚本
# 放到 CDE 源码根目录下直接运行
# 默认只编译系统已安装 locale 的中文语言，可使用 --force-all 强制编译

set -e

# ── 颜色定义（使用 printf，兼容 dash） ──
R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' C='\033[1;36m' N='\033[0m'
ok()   { printf "${G}[✓]${N} %s\n" "$1"; }
warn() { printf "${Y}[!]${N} %s\n" "$1"; }
err()  { printf "${R}[✗]${N} %s\n" "$1"; }
info() { printf "${C}[*]${N} %s\n" "$1"; }
sep()  { printf "${C}%s${N}\n" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

cd "$(dirname "$0")"
[ -f configure.ac ] || { err "请在 CDE 源码根目录下运行"; exit 1; }

# ── 解析参数 ──
FORCE_CN=false; FORCE_TW=false; CONFIGURE_ARGS=""
for arg in "$@"; do
  case "$arg" in
    --force-all)       FORCE_CN=true;  FORCE_TW=true  ;;
    --force-zh_CN)     FORCE_CN=true                    ;;
    --force-zh_TW)                    FORCE_TW=true    ;;
    *)                 CONFIGURE_ARGS="$CONFIGURE_ARGS $arg" ;;
  esac
done

# ── 前置检查 ──
sep; info "检查构建工具..."
MISSING=""
for cmd in autoconf automake libtoolize make cc; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
  err "缺少构建工具:$MISSING"
  info "请安装: sudo apt install autoconf automake libtool build-essential"
  exit 1
fi
ok "所有构建工具已就绪"

# ── 检查 locale 可用性 ──
sep; info "检查系统 locale..."
locale_a=$(locale -a 2>/dev/null || true)

locale_avail() {
  local needle lang_entry
  needle=$(echo "$1" | sed 's/\..*//' | tr 'A-Z' 'a-z')
  for lang_entry in $locale_a; do
    lang_entry=$(echo "$lang_entry" | sed 's/\..*//' | tr 'A-Z' 'a-z')
    [ "$lang_entry" = "$needle" ] && return 0
  done
  return 1
}

ENABLE_CN=""; ENABLE_TW=""; NEED_LC_ALL_C=false
for pair in 'zh_CN.UTF-8:CN' 'zh_TW.UTF-8:TW'; do
  lang="${pair%:*}"; var="${pair#*:}"
  force_var="FORCE_$var"
  eval "force=\${$force_var}"

  if locale_avail "$lang"; then
    ok "$lang 已安装，将编译"
    eval "ENABLE_$var=yes"
  elif [ "$force" = true ]; then
    warn "$lang 未安装，--force-zh_$var 强制编译"
    warn "编译中可能出现 gencat 警告，不影响结果"
    eval "ENABLE_$var=yes"
    NEED_LC_ALL_C=true
  else
    warn "$lang 未安装，跳过编译（使用 --force-zh_$var 或 --force-all 强制编译）"
    eval "ENABLE_$var="
  fi
done

# ── 修改构建系统 ──
sep; info "添加中文编译支持..."

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
  ok "configure.ac: 添加 --enable-chinese / --enable-chinese-tw"
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
  ok "configure.ac: 添加 zh 输出目录"
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
  ok "programs/localized/Makefile.am: 添加 CHINESE / CHINESE_TW 条件"
fi

# ── 创建 LANG 模板 ──
sep; info "创建 LANG 模板..."
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
ok "LANG 模板已创建"

# ── 创建 Makefile.am ──
sep; info "创建中文构建文件..."
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
  ok "$base 构建文件已创建"
done

# ── 修复翻译文件 ──
sep; info "修复翻译文件..."
for base in zh_CN.UTF-8 zh_TW.UTF-8; do
  for f in Dtlogin Dtbuilder Dtudcfonted Dtinfo; do
    [ -f "programs/localized/$base/app-defaults/$f.tmsg" ] || printf '$set 1\n' > "programs/localized/$base/app-defaults/$f.tmsg"
  done
done

FWS=$(printf '\343\200\200')
[ -f "programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg" ] && \
  sed -i "s/ ${FWS}$/ \"/" programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg 2>/dev/null || true
[ -f "programs/localized/zh_TW.UTF-8/msg/dthello.msg" ] && \
  sed -i '84s/$/"/' programs/localized/zh_TW.UTF-8/msg/dthello.msg 2>/dev/null || true
ok "翻译文件修复完成"

# ── 清理 .tmsg 文件中的多字节字符（merge 工具的 gencat 调用 bug 需要） ──
for pair in 'zh_CN.UTF-8:CN' 'zh_TW.UTF-8:TW'; do
  lang="${pair%:*}"; var="${pair#*:}"
  force_var="FORCE_$var"
  eval "force=\${$force_var}"

  if ! locale_avail "$lang" && [ "$force" = true ]; then
    dir="programs/localized/$lang"
    if [ -d "$dir" ]; then
      warn "清理 $lang 的 .tmsg 文件中的多字节字符（locale 未安装，强制编译）"
      find "$dir" -name '*.tmsg' -exec \
        sh -c 'LC_ALL=C sed -i "/^[0-9][0-9]* /s/[^[:print:]\t]//g" "$1"' _ {} \; 2>/dev/null || true
    fi
  fi
done

# ── 生成 configure ──
sep; info "运行 autogen.sh..."
chmod +x autogen.sh
./autogen.sh
ok "autogen.sh 完成"

# ── configure ──
sep; info "运行 configure..."
CONFIGURE_FLAGS=""
[ -n "$ENABLE_CN" ] && CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-chinese"
[ -n "$ENABLE_TW" ] && CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-chinese-tw"
./configure $CONFIGURE_FLAGS $CONFIGURE_ARGS
ok "configure 完成"

# ── 编译 ──
sep; info "编译中..."
if [ "$NEED_LC_ALL_C" = true ]; then
  warn "有未安装的 locale 被强制编译，使用 LC_ALL=C 避免 gencat 错误"
  LC_ALL=C make -j$(nproc)
else
  make -j$(nproc)
fi
sep
ok "编译成功！"
info "安装: sudo make install"
info "启动: startx /usr/dt/bin/Xsession"
sep
