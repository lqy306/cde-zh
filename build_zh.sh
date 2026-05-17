#!/bin/sh
# CDE Chinese Prebuild Script (Linux/BSD Compatible)

set -e

# Basic output (English minimal)
info() { echo "[*] $1"; }
ok()   { echo "[+] $1"; }
err()  { echo "[!] $1"; }
sep()  { echo "----------------------------------------"; }

# Detect OS: Linux or BSD
detect_os() {
    if uname | grep -qi linux; then
        echo "linux"
    elif uname | grep -qi bsd; then
        echo "bsd"
    else
        echo "unknown"
    fi
}
OS=$(detect_os)
info "Detected OS: $OS"

# Go to script directory
cd "$(dirname "$0")"
[ -f configure.ac ] || { err "Run in CDE source root"; exit 1; }

sep
info "Starting preprocessing for Chinese locale..."

# --------------------------
# Step 1: Patch configure.ac
# --------------------------
info "Patching configure.ac..."

if ! grep -q 'enable-chinese' configure.ac; then
    if [ "$OS" = "bsd" ]; then
        sed -i.bak '/AM_CONDITIONAL(\[JAPANESE\]/a\

AC_ARG_ENABLE([chinese],\
        AS_HELP_STRING([--enable-chinese], [Build Chinese (zh_CN.UTF-8) locale]),\
        [enable_zh="yes"], [enable_zh=""]\
)\
AM_CONDITIONAL([CHINESE], [test -n "$enable_zh"])\

AC_ARG_ENABLE([chinese-tw],\
        AS_HELP_STRING([--enable-chinese-tw], [Build Traditional Chinese (zh_TW.UTF-8) locale]),\
        [enable_zt="yes"], [enable_zt=""]\
)\
AM_CONDITIONAL([CHINESE_TW], [test -n "$enable_zt"])' configure.ac
        rm -f configure.ac.bak
    else
        sed -i '/AM_CONDITIONAL(\[JAPANESE\]/a\

AC_ARG_ENABLE([chinese],\
        AS_HELP_STRING([--enable-chinese], [Build Chinese (zh_CN.UTF-8) locale]),\
        [enable_zh="yes"], [enable_zh=""]\
)\
AM_CONDITIONAL([CHINESE], [test -n "$enable_zh"])\

AC_ARG_ENABLE([chinese-tw],\
        AS_HELP_STRING([--enable-chinese-tw], [Build Traditional Chinese (zh_TW.UTF-8) locale]),\
        [enable_zt="yes"], [enable_zt=""]\
)\
AM_CONDITIONAL([CHINESE_TW], [test -n "$enable_zt"])' configure.ac
    fi
    ok "Added --enable-chinese / --enable-chinese-tw"
fi

if ! grep -q 'zh_CN.UTF-8/Makefile' configure.ac; then
    if [ "$OS" = "bsd" ]; then
        sed -i.bak '/ja_JP.UTF-8\/appmanager\/Makefile/a\
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
    else
        sed -i '/ja_JP.UTF-8\/appmanager\/Makefile/a\
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
    fi
    ok "Added Chinese output directories"
fi

# --------------------------
# Step 2: Patch Makefile.am
# --------------------------
info "Patching programs/localized/Makefile.am..."

if ! grep -q 'if CHINESE' programs/localized/Makefile.am; then
    if [ "$OS" = "bsd" ]; then
        sed -i.bak '/if JAPANESE/,/endif/a\

if CHINESE\
SUBDIRS += zh_CN.UTF-8\
endif\

if CHINESE_TW\
SUBDIRS += zh_TW.UTF-8\
endif' programs/localized/Makefile.am
        rm -f programs/localized/Makefile.am.bak
    else
        sed -i '/if JAPANESE/,/endif/a\

if CHINESE\
SUBDIRS += zh_CN.UTF-8\
endif\

if CHINESE_TW\
SUBDIRS += zh_TW.UTF-8\
endif' programs/localized/Makefile.am
    fi
    ok "Added CHINESE / CHINESE_TW conditionals"
fi

# --------------------------
# Step 3: Create templates
# --------------------------
info "Creating language templates..."
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
ok "Templates created"

# --------------------------
# Step 4: Create build files
# --------------------------
info "Generating Chinese build structure..."

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
ok "Build structure ready"

# --------------------------
# Step 5: Fix translation files
# --------------------------
info "Fixing translation files..."
for base in zh_CN.UTF-8 zh_TW.UTF-8; do
    for f in Dtlogin Dtbuilder Dtudcfonted Dtinfo; do
        [ -f "programs/localized/$base/app-defaults/$f.tmsg" ] || echo '$set 1' > "programs/localized/$base/app-defaults/$f.tmsg"
    done
done
ok "Translation files fixed"

# --------------------------
# Done
# --------------------------
sep
ok "Preprocessing completed successfully!"
info "Next steps:"
info "  ./autogen.sh"
info "  ./configure --enable-chinese --enable-chinese-tw"
sep
