#!/usr/bin/env sh

if [ "$OS_FLAVOR" = "darwin" ] && ! xcode-select -p >/dev/null 2>&1
then
    xcode-select --install
fi

case "$MACHINE" in
    darwin_amd64)
        ensure_brew "/usr/local"
        ;;
    darwin_arm64)
        ensure_brew "/opt/homebrew"
        ;;
    linux_*)
        ensure_brew "/home/linuxbrew/.linuxbrew"
        ;;
    *)
        warn "unsupported machine %s for homebrew!" "$MACHINE"
esac
