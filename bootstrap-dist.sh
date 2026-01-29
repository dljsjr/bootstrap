#!/usr/bin/env sh
#-DIST_IGNORE
set -eu

rawprint() {
    command printf "$@"
}

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

MACHINE="$(os_flavor)_$(cpu_arch)"
/bin/sh -c "$(curl -fsSL "https://raw.githubusercontent.com/dljsjr/bootstrap/refs/heads/main/dist/boostrap-${MACHINE}.sh")" -- "$@"
