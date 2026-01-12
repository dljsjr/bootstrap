#!/usr/bin/env sh
# shellcheck disable=2034

if [ ! -t 0 ]; then
    __fmt() { :; }
else
    __fmt() {
        tput "$@"
    }
fi

PRINTED=false

BOLD=$(__fmt bold)
RED=$(__fmt setaf 1)
GREEN=$(__fmt setaf 2)
YELLOW=$(__fmt setaf 3)
BLUE=$(__fmt setaf 4)
MAGENTA=$(__fmt setaf 5)
CYAN=$(__fmt setaf 6)
WHITE=$(__fmt setaf 7)
RESET=$(__fmt sgr0)

rawprint() {
    command printf "$@"
}

# shellcheck disable=SC2059
debug() {
    if [ "${DEBUG_BOOTSTRAP:-0}" = 1 ]; then
        msg="$1"
        shift
        rawprint -- "${BOLD}${BLUE}[DEBUG]${RESET} $msg\n" "$@"
        PRINTED=true
    fi
}

# shellcheck disable=SC2059
info() {
    msg="$1"
    shift
    rawprint -- "${BOLD}${GREEN}[INFO]${RESET} $msg\n" "$@"
    PRINTED=true
}

# shellcheck disable=SC2059
warn() {
    msg="$1"
    shift
    rawprint -- "${BOLD}${YELLOW}[WARN]${RESET} $msg\n" "$@" 1>&2
    PRINTED=true
}

# shellcheck disable=SC2059
error() {
    msg="$1"
    shift
    rawprint -- "${BOLD}${MAGENTA}[ERROR]${RESET} $msg\n" "$@" 1>&2
    PRINTED=true
}

# shellcheck disable=SC2059
abort() {
    msg="$1"
    shift
    rawprint -- "${BOLD}${RED}[FATAL]${RESET} $msg\n" "$@" 1>&2
    exit 1
}

printf() {
    info "$@"
}

linebreak() {
    if [ "$PRINTED" = true ]
    then
        rawprint "\n"
    fi
    PRINTED=false
}

for funcdef in "${SCRIPTDIR}/_functions.d"/*
do
    if [ -f "$funcdef" ]
    then
        # shellcheck disable=1090
        . "$funcdef"
    fi
done