#!/usr/bin/env sh

os_flavor() {
    rawprint -- "%s" "$(uname -s | tr '[:upper:]' '[:lower:]')"
}

cpu_arch() {
    UNAME_MACHINE="$(uname -m)"
    case "$UNAME_MACHINE" in
    arm64 | aarch64_be | aarch64 | armv8b | armv8l)
        rawprint "arm64"
        ;;
    arm* | aarch*)
        rawprint "arm32"
        ;;
    amd64 | x86_64)
        rawprint "amd64"
        ;;
    *)
        abort "Unsupported architecture: '%s'" "$UNAME_MACHINE"
        ;;
    esac
}