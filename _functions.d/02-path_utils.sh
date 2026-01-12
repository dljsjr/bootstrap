#!/usr/bin/env sh

PATH="${PATH:-''}"

__report_path_update() {
    rawprint -- "\n"
    info "${BOLD}${MAGENTA}%s${RESET} ${BOLD}${WHITE}%s${RESET} to ${BOLD}${WHITE}\$PATH${RESET}" "$1" "$2"
    rawprint -- "       This only effects the duration of the bootstrap script; make sure your \$PATH is properly configured elsewhere.\n\n"
}

prepend_path() {
    if ! echo "$PATH" | grep -q ":\{0,1\}$1:\{0,1\}"
    then
        __report_path_update PREPENDING "$1"
        PATH="$1:$PATH"
    fi
}

append_path() {
    if ! echo "$PATH" | grep -q ":\{0,1\}$1:\{0,1\}"
    then
        __report_path_update APPENDING "$1"
        PATH="$PATH:$1"
    fi
}