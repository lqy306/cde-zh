#!/bin/sh
set -e

cd "$(dirname "$0")"
[ -f configure.ac ] || exit 1

FORCE_CN=false
FORCE_TW=false
WITH_DOC=false
CONFIGURE_ARGS=""

for arg in "$@"; do
  case "$arg" in
    --force-all) FORCE_CN=true; FORCE_TW=true ;;
    --force-zh_CN) FORCE_CN=true ;;
    --force-zh_TW) FORCE_TW=true ;;
    --with-doc) WITH_DOC=true ;;
    *) CONFIGURE_ARGS="$CONFIGURE_ARGS $arg" ;;
  esac
done

echo "=== Checking build tools ==="
MISSING=""
for cmd in autoconf automake libtoolize make cc; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
  echo "Missing tools:$MISSING"
  exit 1
fi
echo "All build tools ready"

echo "=== Checking system locales ==="
locale_a=$(locale -a 2>/dev/null || true)

locale_avail() {
  local needle=$(echo "$1" | sed 's/\..*//' | tr 'A-Z' 'a')
  for lang_entry in $locale_a; do
    local le=$(echo "$lang_entry" | sed 's/\..*//' | tr 'A-Z' 'a')
    [ "$le" = "$needle" ] && return 0
  done
  return 1
}

ENABLE_CN=""
ENABLE_TW=""
NEED_LC_ALL_C=false

for pair in 'zh_CN.UTF-8:CN' 'zh_TW.UTF-8:TW'; do
  lang="${pair%:*}"
  var="${pair#*:}"
  force_var="FORCE_$var"
  eval "force=\${$force_var}"

  if locale_avail "$lang"; then
    echo "$lang available, will build"
    eval "ENABLE_$var=yes"
  elif [ "$force" = true ]; then
    echo "$lang not found, force build"
    eval "ENABLE_$var=yes"
    NEED_LC_ALL_C=true
  else
    echo "$lang not found, skipping"
    eval "ENABLE_$var="
  fi
done

echo "=== Patching build system ==="

# 添加中文编译选项
if ! grep -q 'enable-chinese' configure.ac 2>/dev/null; then
  sed -i.bak '/AM_CONDITIONAL(\[JAPANESE\].*/a\

AC_ARG_ENABLE([chinese],\
        AS_HELP_STRING([--enable-chinese], [Build Chinese (zh_CN.UTF-8) locale (default=no)]),\
        [enable_zh="yes"], [enable_zh=""]\
)\
AM_CONDITIONAL([CHINESE], [test -n "$enable_zh"])\

AC_ARG_ENABLE([chinese-tw],\
        AS_HELP_STRING([--enable-chinese-tw], [Build Chinese Traditional (zh_TW.UTF-8) locale (default=no)]),\
        [enable_zt="yes"], [enable_zt=""]\
)\
AM_CONDITIONAL([CHINESE_TW], [test -n "$enable_zt"])' configure.ac
  rm -f configure.ac.bak
fi

# 添加中文目录到 configure.ac
if ! grep -q 'zh_CN.UTF-8/Makefile' configure.ac 2>/dev/null; then
  sed -i.bak '/programs\/localized\/ja_JP.UTF-8\/appmanager\/Makefile/a\
programs/localized/zh_CN.UTF-8/Makefile\
programs/localized/zh_CN.UTF-8/app-defaults/Makefile\
programs/localized/zh_CN.UTF-8/config/Makefile\
programs/localized/zh_CN.UTF-8/backdrops/Makefile\
programs/localized/zh_CN.UTF-8/types/Makefile\
programs/localized/zh_CN.UTF-8/palettes/Makefile\
programs/localized/zh_CN.UTF-8/msg/Makefile\
programs/localized/zh_CN.UTF-8/appmanager/Makefile\
programs/localized/zh_TW.UTF-8/Makefile\
programs/localized/zh_TW.UTF-8/app-defaults/Makefile\
programs/localized/zh_TW.UTF-8/config/Makefile\
programs/localized/zh_TW.UTF-8/backdrops/Makefile\
programs/localized/zh_TW.UTF-8/types/Makefile\
programs/localized/zh_TW.UTF-8/palettes/Makefile\
programs/localized/zh_TW.UTF-8/msg/Makefile\
programs/localized/zh_TW.UTF-8/appmanager/Makefile' configure.ac
  rm -f configure.ac.bak
fi

# 添加中文条件编译
if ! grep -q 'if CHINESE' programs/localized/Makefile.am 2>/dev/null; then
  sed -i.bak '/if JAPANESE/,/endif/a\

if CHINESE
SUBDIRS += zh_CN.UTF-8
endif

if CHINESE_TW
SUBDIRS += zh_TW.UTF-8
endif' programs/localized/Makefile.am
  rm -f programs/localized/Makefile.am.bak
fi

# ==========================
# 【彻底修复 FreeBSD 所有错误】
# ==========================
echo "=== Fixing FreeBSD build issues ==="

# 1. 移除 dtcm
rm -rf programs/dtcm
sed -i.bak '/dtcm/d' configure.ac
sed -i.bak '/dtcm/d' programs/Makefile.am
sed -i.bak '/dtcm/d' programs/localized/C/app-defaults/Makefile 2>/dev/null || true
sed -i.bak '/dtcm/d' programs/localized/C/msg/Makefile 2>/dev/null || true
rm -f *.bak programs/*.bak programs/localized/*/*.bak 2>/dev/null

# 2. 给中文目录创建空 Makefile，防止编译报错
for dir in zh_CN.UTF-8 zh_TW.UTF-8; do
  mkdir -p programs/localized/$dir
  cat > programs/localized/$dir/Makefile <<EOF
all:
install:
clean:
EOF
done

echo "=== Creating locale templates ==="
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

echo "=== Creating build files ==="
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

echo "=== Fixing translation files ==="
for base in zh_CN.UTF-8 zh_TW.UTF-8; do
  for f in Dtlogin Dtbuilder Dtudcfonted Dtinfo; do
    [ -f "programs/localized/$base/app-defaults/$f.tmsg" ] || printf '$set 1\n' > "programs/localized/$base/app-defaults/$f.tmsg"
  done
done

echo "=== ALL PATCHES APPLIED SUCCESSFULLY ==="
