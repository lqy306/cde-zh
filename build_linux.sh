#!/bin/sh
# CDE Chinese Locale Build Script
# Run from CDE source root directory

set -e

# Basic checks
cd "$(dirname "$0")"
[ -f configure.ac ] || { echo "ERROR: Must run from CDE source root"; exit 1; }

# Parse arguments
FORCE_CN=false; FORCE_TW=false; WITH_DOC=false; CONFIGURE_ARGS=""
for arg in "$@"; do
  case "$arg" in
    --force-all)       FORCE_CN=true;  FORCE_TW=true  ;;
    --force-zh_CN)     FORCE_CN=true                    ;;
    --force-zh_TW)                    FORCE_TW=true    ;;
    --with-doc)        WITH_DOC=true                    ;;
    *)                 CONFIGURE_ARGS="$CONFIGURE_ARGS $arg" ;;
  esac
done

# Check build tools
echo "[*] Checking build tools..."
MISSING=""
for cmd in autoconf automake libtoolize make cc; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
  echo "ERROR: Missing tools:$MISSING"
  exit 1
fi
echo "[+] All build tools ready"

# Check system locales
echo "[*] Checking system locales..."
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
    echo "[+] $lang available, enabling build"
    eval "ENABLE_$var=yes"
  elif [ "$force" = true ]; then
    echo "[!] $lang missing, force enabling build"
    eval "ENABLE_$var=yes"
    NEED_LC_ALL_C=true
  else
    echo "[!] $lang missing, skipping (use --force-$lang to override)"
    eval "ENABLE_$var="
  fi
done

# Modify configure.ac for Chinese support
echo "[*] Patching configure.ac..."
if ! grep -q 'enable-chinese' configure.ac 2>/dev/null; then
  sed -i '/AM_CONDITIONAL(\[JAPANESE\].*/a\

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

# Modify localized Makefile.am
echo "[*] Patching programs/localized/Makefile.am..."
if ! grep -q 'if CHINESE' programs/localized/Makefile.am 2>/dev/null; then
  sed -i '/if JAPANESE/,/endif/a\

if CHINESE\
SUBDIRS += zh_CN.UTF-8\
endif\

if CHINESE_TW\
SUBDIRS += zh_TW.UTF-8\
endif' programs/localized/Makefile.am
fi

# Create language templates
echo "[*] Creating locale templates..."
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

# Create locale build files
echo "[*] Creating zh_CN.UTF-8 / zh_TW.UTF-8 build files..."
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

# Fix translation files
echo "[*] Fixing translation files..."
for base in zh_CN.UTF-8 zh_TW.UTF-8; do
  for f in Dtlogin Dtbuilder Dtudcfonted Dtinfo; do
    [ -f "programs/localized/$base/app-defaults/$f.tmsg" ] || printf '$set 1\n' > "programs/localized/$base/app-defaults/$f.tmsg"
  done
done

FWS=$(printf '\343\200\200')
[ -f "programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg" ] && sed -i "s/ ${FWS}$/ \"/" programs/localized/zh_TW.UTF-8/msg/dtbuilder.msg 2>/dev/null || true
[ -f "programs/localized/zh_TW.UTF-8/msg/dthello.msg" ] && sed -i '84s/$/"/' programs/localized/zh_TW.UTF-8/msg/dthello.msg 2>/dev/null || true

# Clean multibyte characters for forced build
for pair in 'zh_CN.UTF-8:CN' 'zh_TW.UTF-8:TW'; do
  lang="${pair%:*}"; var="${pair#*:}"
  force_var="FORCE_$var"
  eval "force=\${$force_var}"

  if ! locale_avail "$lang" && [ "$force" = true ]; then
    dir="programs/localized/$lang"
    if [ -d "$dir" ]; then
      echo "[*] Cleaning multibyte chars in $lang .tmsg files"
      find "$dir" -name '*.tmsg' -exec sh -c 'LC_ALL=C sed -i "/^[0-9][0-9]* /s/[^[:print:]\t]//g" "$1"' _ {} \; 2>/dev/null || true
    fi
  fi
done

# Generate configure
echo "[*] Running autogen.sh..."
chmod +x autogen.sh
./autogen.sh

# Configure
echo "[*] Running configure..."
CONFIGURE_FLAGS=""
[ -n "$ENABLE_CN" ] && CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-chinese"
[ -n "$ENABLE_TW" ] && CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-chinese-tw"
[ "$WITH_DOC" = false ] && CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-docs"
./configure $CONFIGURE_FLAGS $CONFIGURE_ARGS

# Build
echo "[*] Starting build..."
if [ "$NEED_LC_ALL_C" = true ]; then
  echo "[!] Using LC_ALL=C for forced locale build"
  LC_ALL=C make -j$(nproc)
else
  make -j$(nproc)
fi

echo "[+] Build completed successfully!"

# Install prompt
echo ""
echo -n "[?] Install to /usr/dt and add CDE session? (Y/n) "
read -r answer
case "$answer" in
  n|N|no|NO)
    echo "[*] Installation skipped"
    echo "Manual install: sudo make install -C util && sudo make install -C include && sudo make install -C lib && sudo make install -C programs && sudo make install -C programs/localized && sudo cp contrib/desktopentry/cde.desktop /usr/share/xsessions/"
    exit 0
    ;;
  *)
    echo "[*] Installing..."
    sudo make install -C util
    sudo make install -C include
    sudo make install -C lib
    sudo make install -C programs
    sudo make install -C programs/localized

    if [ -f contrib/desktopentry/cde.desktop ]; then
      sudo mkdir -p /usr/share/xsessions
      sudo cp contrib/desktopentry/cde.desktop /usr/share/xsessions/
    fi

    echo "[+] Installation completed!"
    echo "[*] Login with CDE session or run: startx /usr/dt/bin/Xsession"
    ;;
esac
