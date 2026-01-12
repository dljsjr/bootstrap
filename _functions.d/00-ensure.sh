#!/usr/bin/env sh

ensure() {
    cmd="$1"
    shift

    if ! command -v "$cmd" >/dev/null 2>&1
    then
        msg="Failed to configure/install/ensure ${BOLD}\`$cmd\`${RESET}"
        if [ -n "$*" ]
        then
            msg="$msg: $*"
        fi
        abort "%s" "$msg"
    fi
}
