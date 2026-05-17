#!/bin/sh
# CDE Chinese locale build preprocessor
# Adds zh_CN.UTF-8 / zh_TW.UTF-8 support to CDE build system
# Run from CDE source root; then do ./autogen.sh && ./configure --enable-chinese ...

set -e

cd "$(dirname "$0")"
[ -f configure.ac ] || { echo "ERROR: run from CDE source root"; exit 1; }

# -- pre-reqs --
for cmd in autoconf automake libtoolize; do
  command -v "$cmd" >/dev/null 2>&1 || echo "WARNING: $cmd not found (needed for autogen.sh later)"
done

# -- 1. check locale availability --
for l in zh_CN.utf8 zh_TW.utf8; do
  if locale -a 2>/dev/null | grep -qi "$l"; then
    echo "  locale $l: found"
  else
    echo "  locale $l: missing (benign warning at build)"
  fi
done

# -- 2. add --enable-chinese / --enable-chinese-tw to configure.ac --
if ! grep -q 'enable-chinese' configure.ac 2>/dev/null; then
  echo "  configure.ac: adding Chinese locale options"
  perl -i -0777 -pe \
    's/(AM_CONDITIONAL\(\[JAPANESE\],.*?\n\))/$1\n\nAC_ARG_ENABLE([chinese],\n        AS_HELP_STRING([--enable-chinese], [Build Chinese (zh_CN.UTF-8) locale (default=no)]),\n        [enable_zh="yes"], [enable_zh=""]\n)\nAM_CONDITIONAL([CHINESE], [test -n "\$enable_zh"])\n\nAC_ARG_ENABLE([chinese-tw],\n        AS_HELP_STRING([--enable-chinese-tw], [Build Chinese Traditional (zh_TW.UTF-8) locale (default=no)]),\n        [enable_zt="yes"], [enable_zt=""]\n)\nAM_CONDITIONAL([CHINESE_TW], [test -n "\$enable_zt"])/s' configure.ac
else
  echo "  configure.ac: Chinese options already present, skip"
fi

if ! grep -q 'zh_CN.UTF-8/Makefile' configure.ac 2>/dev/null; then
  echo "  configure.ac: adding zh_CN/zh_TW Makefile entries"
  perl -i -0777 -pe \
    's/(programs\/localized\/ja_JP\.UTF-8\/appmanager\/Makefile)/$1\nprograms\/localized\/zh_CN.UTF-8\/Makefile\nprograms\/localized\/zh_CN.UTF-8\/app-defaults\/Makefile\nprograms\/localized\/zh_CN.UTF-8\/config\/Makefile\nprograms\/localized\/zh_CN.UTF-8\/backdrops\/Makefile\nprograms\/localized\/zh_CN.UTF-8\/types\/Makefile\nprograms\/localized\/zh_CN.UTF-8\/palettes\/Makefile\nprograms\/localized\/zh_CN.UTF-8\/msg\/Makefile\nprograms\/localized\/zh_CN.UTF-8\/appmanager\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/app-defaults\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/config\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/backdrops\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/types\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/palettes\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/msg\/Makefile\nprograms\/localized\/zh_TW.UTF-8\/appmanager\/Makefile/' configure.ac
else
  echo "  configure.ac: zh_CN/zh_TW Makefile entries already present, skip"
fi

# -- 3. add CHINESE / CHINESE_TW conditionals to localized/Makefile.am --
if ! grep -q 'if CHINESE' programs/localized/Makefile.am 2>/dev/null; then
  echo "  localized/Makefile.am: adding CHINESE/CHINESE_TW conditionals"
  perl -i -0777 -pe \
    's/(if JAPANESE\nSUBDIRS \+= ja_JP\.UTF-8\nendif)/$1\n\nif CHINESE\nSUBDIRS += zh_CN.UTF-8\nendif\n\nif CHINESE_TW\nSUBDIRS += zh_TW.UTF-8\nendif/' programs/localized/Makefile.am
else
  echo "  localized/Makefile.am: conditionals already present, skip"
fi

# -- 4. create LANG template files --
echo "  creating LANG template files"
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

# -- 5. create Makefile.am for zh_CN.UTF-8 and zh_TW.UTF-8 --
echo "  creating zh_CN.UTF-8 / zh_TW.UTF-8 Makefile.am files"
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

# -- 6. fix missing/broken translation files --
echo "  fixing translation files"
for base in zh_CN.UTF-8 zh_TW.UTF-8; do
  for f in Dtlogin Dtbuilder Dtudcfonted Dtinfo; do
    fpath="programs/localized/$base/app-defaults/$f.tmsg"
    [ -f "$fpath" ] || { printf '$set 1\n' > "$fpath"; echo "    created $fpath"; }
  done
done

# fix unclosed quote in zh_TW dtbuilder.msg: replace trailing fullwidth space with double quote
if [ -f "programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg" ]; then
  perl -i -pe 's/\xe3\x80\x80$/\x22/' programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg
  echo "    fixed zh_TW dtbuilder.msg quote"
fi
if [ -f "programs/localized/zh_TW.UTF-8/msg/dthello.msg" ]; then
  perl -i -pe 's/$/\x22/ if $. == 84' programs/localized/zh_TW.UTF-8/msg/dthello.msg
  echo "    fixed zh_TW dthello.msg line 84"
fi

# -- 7. fix FreeBSD 14 compatibility issues --
if grep -q 'tzsetwall' programs/dtcm/libDtCmP/timeops.c 2>/dev/null; then
  perl -i -pe 's/tzsetwall\(\)/tzset()/g' programs/dtcm/libDtCmP/timeops.c
  echo "    fixed tzsetwall() -> tzset() in dtcm/libDtCmP/timeops.c"
fi

echo ""
echo "Preprocessing done. Next steps:"
echo "  ./autogen.sh"
echo "  ./configure --enable-chinese --enable-chinese-tw --disable-docs \\"
echo "    --with-tcl=/usr/local/lib/tcl8.6 \\"
echo '    CXXFLAGS="-Wno-register" CFLAGS="-Wno-incompatible-function-pointer-types"'
echo "  gmake -j\$(nproc)"
echo "  gmake install"
