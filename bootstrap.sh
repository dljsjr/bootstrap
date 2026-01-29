#!/usr/bin/env sh

set -eu

WORKDIR="$(/bin/pwd -P)"
export WORKDIR

SCRIPTDIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && /bin/pwd -P)"
export SCRIPTDIR

#-BEGIN:$SCRIPTDIR/_functions.sh
# source helper functions script
# shellcheck source=_functions.sh
. "$SCRIPTDIR/_functions.sh"
linebreak
#-END:_functions.sh

usage() {
    cat <<EOF
Bootstrap Script
Usage: bootstrap.sh [options]
    -h, --help                      Display this message.
    -p, --purge                     Pass '--purge' to 'chezmoi init'
    --purge-binary                  Pass '--purge-binary' to 'chezmoi init'
    -d, --dotfiles <DOTFILES_ARG>   Chezmoi Dotfiles Repo Argument, passed like so: 'chezmoi init --apply <DOTFILES_ARG>'
                                    If empty, then 'chezmoi init' is run bare, setting up new dotfiles with the default settings.
    -S, --source <SOURCE_DIR>       Directory to use as the source dir (where the dotfiles will be cloned), passed to chezmoi with the
                                    '-S|--source'.
    --no-apply                      Do not pass '--apply' to 'chezmoi init'

    --brew-mise                     Install mise from homebrew instead of its install script

    --op-cli-install-path           Directory to place the OP CLI binary when not using brew or the .pkg, defaults to \$HOME/.local/bin
    --brew-op-cli                   Install the 1Password CLI using brew
    --pkg-op-cli                    Install the 1Password CLI by downloading the .pkg file (${BOLD}macOS only${RESET})
    --op-sign-in-address            (Optional) 1Password URL to use for the CLI
    --op-email                      (Optional) Email Address for 1Password account
    --op-password                   (Optional) Password for 1Password account
    --op-secret-key                 (Optional) Secret Key for 1Password account
    --download-private-keys         (Optional) By default only public keys will be downloaded to the local disk from the
                                    configured 1Password vault. If this is set, the private keys will also be downloaded.

    --chezmoi-install-path          Directory to place the chezmoi binary when not using brew or mise, defaults to \$HOME/.local/bin
    --brew-chezmoi                  Install chezmoi from homebrew instead of its install script
    --mise-chezmoi                  Install chezmoi with 'mise use --global' instead of its install script
EOF
    exit "${1:-0}"
}

# chezmoi args
CHEZMOI_INSTALL_PATH="$HOME/.local/bin"
BREW_CHEZMOI=0
MISE_CHEZMOI=0
PURGE=0
PURGE_BINARY=0
CHEZMOI_DOTFILES_ARG=""
CHEZMOID_SOURCEDIR=""
CHEZMOI_APPLY=1

# mise setup args
BREW_MISE=0

# 1password CLI setup args
OP_CLI_INSTALL_PATH="$HOME/.local/bin"
BREW_OP_CLI=0
PKG_OP_CLI=0
OP_SIGN_IN_ADDRESS=""
OP_EMAIL=""
OP_PASSWORD=""
OP_SECRET_KEY=""

DOWNLOAD_PRIVATE_KEYS=0

while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help) usage ;;
    -d | --dotfiles)
        CHEZMOI_DOTFILES_ARG="$2"
        shift
        ;;
    -S | --source)
        CHEZMOID_SOURCEDIR="$2"
        shift
        ;;
    --no-apply)
        CHEZMOI_APPLY=0
        ;;
    -p | --purge)
        PURGE=1
        ;;
    --purge-binary)
        PURGE_BINARY=1
        ;;
    --chezmoi-install-path)
        CHEZMOI_INSTALL_PATH="$2"
        shift
        ;;
    --brew-mise)
        BREW_MISE=1
        ;;
    --brew-chezmoi)
        BREW_CHEZMOI=1
        ;;
    --mise-chezmoi)
        MISE_CHEZMOI=1
        ;;
    --op-cli-install-path)
        OP_CLI_INSTALL_PATH="$2"
        shift
        ;;
    --brew-op-cli)
        BREW_OP_CLI=1
        ;;
    --pkg-op-cli)
        PKG_OP_CLI=1
        ;;
    --op-sign-in-address)
        OP_SIGN_IN_ADDRESS="$2"
        shift
        ;;
    --op-email)
        OP_EMAIL="$2"
        shift
        ;;
    --op-password)
        OP_PASSWORD="$2"
        shift
        ;;
    --op-secret-key)
        OP_SECRET_KEY="$2"
        shift
        ;;
    --download-private-keys)
        DOWNLOAD_PRIVATE_KEYS=1
        ;;
    *)
        error "Unrecognized option: '%s'" "$1"
        usage 1
        ;;
    esac
    shift
done

if [ "$BREW_CHEZMOI" = 1 ] && [ "$MISE_CHEZMOI" = 1 ]; then
    error "--brew-chezmoi and --mise-chezmoi cannot be used together\n"
    usage 1
fi

if [ "$BREW_OP_CLI" = 1 ] && [ "$PKG_OP_CLI" = 1 ]; then
    error "--brew-op-cli and --pkg-op-cli cannot be used together\n"
    usage 1
fi

# create temporary directory for downloads
DLDIR="$(mktemp -d)"
if [ ! -d "$DLDIR" ]
then
    abort "Failed to create temporary download directory!"
fi

cleanup() {
    if [ -d "$DLDIR" ]
    then
        rm -rf "$DLDIR"
    fi
}
trap cleanup EXIT HUP INT QUIT ABRT TERM

export DLDIR
export CHEZMOI_DOTFILES_ARG
export CHEZMOI_INSTALL_PATH
export CHEZMOI_APPLY
export PURGE
export PURGE_BINARY
export BREW_MISE
export BREW_CHEZMOI
export MISE_CHEZMOI
export OP_CLI_INSTALL_PATH
export BREW_OP_CLI
export PKG_OP_CLI
export OP_SIGN_IN_ADDRESS
export OP_EMAIL
export OP_PASSWORD
export OP_SECRET_KEY
export DOWNLOAD_PRIVATE_KEYS

# ensure local bin:
if [ -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin" >/dev/null 2>&1 || exit
fi

prepend_path "$HOME/.local/bin"
export PATH

OS_FLAVOR="$(os_flavor)"
export OS_FLAVOR

if [ "$PKG_OP_CLI" = 1 ] && ! [ "$OS_FLAVOR" = "darwin" ]
then
    error "--pkg-op-cli is only supported on macOS"
    usage 1
fi

CPU_ARCH="$(cpu_arch)"
export CPU_ARCH

MACHINE="${OS_FLAVOR}_${CPU_ARCH}"
export MACHINE

#-BEGIN:${SCRIPTDIR}/bootstrap.d
## Beging sourcing of additional config files. Files are sourced in the following order:
##
## 1. bootstrap.d/*.sh (alphabetically)
## 2. $OS_FLAVOR_CONFDIR/boostrap.sh (if it exists)
## 3. $OS_FLAVOR_CONFDIR/bootstrap.d/*.sh (alphabetically)
if [ -d "${SCRIPTDIR}/bootstrap.d" ]
then
    for conf_file in "${SCRIPTDIR}"/bootstrap.d/*
    do
        debug "Sourcing config file ${BOLD}%s${RESET}" "$conf_file"
        # shellcheck disable=SC1090
        . "$conf_file"
        linebreak
        cd "$WORKDIR" || abort "Unexpected error"
    done
fi
#-END:${SCRIPTDIR}/bootstrap.d

OS_FLAVOR_CONFDIR="$SCRIPTDIR/${OS_FLAVOR}"
export OS_FLAVOR_CONFDIR

#-BEGIN:$OS_FLAVOR_CONFDIR
if [ -d "$OS_FLAVOR_CONFDIR" ]
then
    info "Found machine-specific boostrap configuration for ${BOLD}%s${RESET}" "$OS_FLAVOR"
    if [ -f "${OS_FLAVOR_CONFDIR}/bootstrap.sh" ]
    then
        debug "Sourcing bootstrap.sh for ${BOLD}%s${RESET}" "$OS_FLAVOR"
        # shellcheck disable=SC1090
        . "${OS_FLAVOR_CONFDIR}/bootstrap.sh"
        linebreak
        cd "$WORKDIR" || abort "Unexpected error"
    fi

    if [ -d "${OS_FLAVOR_CONFDIR}/bootstrap.d" ]
    then
        debug "Sourcing configurations in ${BOLD}%s${RESET}" "${OS_FLAVOR_CONFDIR}/bootstrap.d"

        for conf_file in "${OS_FLAVOR_CONFDIR}"/bootstrap.d/*
        do
            if [ -f "$conf_file" ]
            then
                debug "Sourcing config file ${BOLD}%s${RESET}" "$conf_file"
                # shellcheck disable=SC1090
                . "$conf_file"
                linebreak
                cd "$WORKDIR" || abort "Unexpected error"
            fi
        done
    fi
else
    warn "No machine-specific boostrap configuration for %s" "$OS_FLAVOR"
fi
#-END:$OS_FLAVOR_CONFDIR

cd "$WORKDIR" || abort "Unexpected error"

# at this point, we should have brew, mise, chezmoi, age, and 1password installed
# Our SSH keys should have been extracted from our 1P vault.
#
# We can now clone our dotfiles from GitHub and apply them with Chezmoi, or start up new dotfiles.
if [ -n "$CHEZMOID_SOURCEDIR" ]
then
    CHEZMOI_CMD="chezmoi --source $CHEZMOID_SOURCEDIR init"
else
    CHEZMOI_CMD="chezmoi init"
fi

if [ "$PURGE" = 1 ]
then
    CHEZMOI_CMD="$CHEZMOI_CMD --purge"
fi

if [ "$PURGE_BINARY" = 1 ]
then
    CHEZMOI_CMD="$CHEZMOI_CMD --purge-binary"
fi

if [ "$CHEZMOI_APPLY" = 1 ] && [ -n "$CHEZMOI_DOTFILES_ARG" ]
then
    CHEZMOI_CMD="$CHEZMOI_CMD --apply"
fi

if [ -n "$CHEZMOI_DOTFILES_ARG" ]
then
    CHEZMOI_CMD="$CHEZMOI_CMD $CHEZMOI_DOTFILES_ARG"
fi

info "Boostrapping dotfiles with command ${CYAN}[%s]${RESET}" "$CHEZMOI_CMD"
linebreak
eval "$CHEZMOI_CMD"
