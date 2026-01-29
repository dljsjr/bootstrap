#!/usr/bin/env sh

set -eu

WORKDIR="$(/bin/pwd -P)"
export WORKDIR

SCRIPTDIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && /bin/pwd -P)"
export SCRIPTDIR


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

debug() {
    if [ "${DEBUG_BOOTSTRAP:-0}" = 1 ]; then
        msg="$1"
        shift
        rawprint -- "${BOLD}${BLUE}[DEBUG]${RESET} $msg\n" "$@"
        PRINTED=true
    fi
}

info() {
    msg="$1"
    shift
    rawprint -- "${BOLD}${GREEN}[INFO]${RESET} $msg\n" "$@"
    PRINTED=true
}

warn() {
    msg="$1"
    shift
    rawprint -- "${BOLD}${YELLOW}[WARN]${RESET} $msg\n" "$@" 1>&2
    PRINTED=true
}

error() {
    msg="$1"
    shift
    rawprint -- "${BOLD}${MAGENTA}[ERROR]${RESET} $msg\n" "$@" 1>&2
    PRINTED=true
}

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

# first argument is the homebrew basedir
ensure_brew() {
    # homebrew's shellenv setup is idempotent
    if [ -x "$1"/bin/brew ]
    then
        info "found existing Homebrew installation, ensuring shellenv"
        eval "$("$1"/bin/brew shellenv)"
    fi

    if ! command -v brew >/dev/null 2>&1
    then
        info "Installing ${BOLD}Homebrew${RESET}"
        cd "$DLDIR" || exit
        mkdir -p brew
        cd brew || exit

        info "download homebrew install script"
        curl -OfsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh || abort "Failed to download homebrew installer"
        chmod +x install.sh

        # cache sudo credentials for non-interactive use
        info "executing homebrew install script"
        printf "\n"
        sudo -v
        NONINTERACTIVE=1 ./install.sh || abort "Failed to run homebrew installer"
        eval "$("$1"/bin/brew shellenv)"
    fi

    cd "$WORKDIR" || exit

    ensure brew
}

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

MISE_INSTALL_PATH="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}"
MISE_DATA_DIR="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
prepend_path "$(dirname "$MISE_INSTALL_PATH")"

if ! command -v mise >/dev/null 2>&1
then
    info "Installing ${BOLD}mise${RESET}"

    if [ "$BREW_MISE" = 1 ];
    then
        brew install mise
        
    else
        cd "$DLDIR" || abort "failed to change directory to tmp download dir"
        mkdir -p mise
        cd mise || abort "unexpected error"

        info "download mise install script"
        curl -s https://mise.run > install.sh || abort "failed to download mise install script"
        chmod +x install.sh

        info "running mise install script"
        printf "\n"
        MISE_INSTALL_PATH="$MISE_INSTALL_PATH" ./install.sh || abort "failed to run mise installer"
        eval "$("$MISE_INSTALL_PATH" activate --shims)"
        cd "$WORKDIR" || abort "unexpected error"
    fi
fi

ensure mise

# activating shims is idempotent
eval "$(mise activate --shims)"

prepend_path "$OP_CLI_INSTALL_PATH"

if ! command -v op >/dev/null 2>&1
then
    info "installing ${BOLD}1Password CLI${RESET}"

    if [ "$BREW_OP_CLI" = 1 ]
    then
        debug "installing 1Password CLI via Homebrew"
        brew install 1password-cli
    else
        LATEST_CLI_VERSION="$(curl -s https://app-updates.agilebits.com/latest | sed -e 's/^.*"CLI2":{"release":{"version":"\([^"]*\)".*$/\1/g')"

        if ! echo "$LATEST_CLI_VERSION" | grep -q '[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}'
        then
            abort "Malformed OP CLI version: '%s'" "$LATEST_CLI_VERSION"
        fi

        OP_CLI_URL_BASE="https://cache.agilebits.com/dist/1P/op2/pkg/v${LATEST_CLI_VERSION}"
        cd "$DLDIR" || abort "Unexpected error"
        mkdir -p "1p"
        cd 1p || abort "Unexpected error"

        if [ "$PKG_OP_CLI" = 1 ]
        then
            debug "installing 1Password CLI via PKG"
            info "downloading op cli .pkg"

            INSTALL_FILE="op_apple_universal_v${LATEST_CLI_VERSION}.pkg"
            curl -sLJO "${OP_CLI_URL_BASE}/${INSTALL_FILE}"

            info "Running 1Password CLI Package Installer"
            open -W "${DLDIR}/${INSTALL_FILE}"
        else
            debug "installing 1Password CLI from .zip"
            info "downloading op cli .zip"

            INSTALL_FILE="op_${MACHINE}_v${LATEST_CLI_VERSION}.zip"
            curl -sLJO "${OP_CLI_URL_BASE}/${INSTALL_FILE}"

            info "Unzipping 1Password CLI files"
            unzip "$INSTALL_FILE"

            if [ "$OS_FLAVOR" = "darwin" ]
            then
                TARGET_FILE="$(find . -name 'op' -perm +111 | tail -n 1)"
            else
                TARGET_FILE="$(find . -name 'op' -perm /111 | tail -n 1)"
            fi

            if [ -z "$TARGET_FILE" ] || [ ! -x "$TARGET_FILE" ]
            then
                abort "Unexpected error locating unzipped binary to install"
            fi
            info "Moving ${BOLD}'op'${RESET} binary to ${BOLD}%s${RESET}" "$OP_CLI_INSTALL_PATH"
            mv "$TARGET_FILE" "$OP_CLI_INSTALL_PATH"
        fi
        cd "$WORKDIR" || abort "Unexpected error"
    fi
fi

ensure op

if ! command -v age >/dev/null 2>&1
then
    info "Installing ${BOLD}age${RESET} from homebrew"
    brew install age
fi

# disable the app integration for this part
OP_BIOMETRIC_UNLOCK_ENABLED="${OP_BIOMETRIC_UNLOCK_ENABLED:-''}"
OLD_BIOMETRIC_VAR="${OP_BIOMETRIC_UNLOCK_ENABLED}"
export OP_BIOMETRIC_UNLOCK_ENABLED=false

if [ -z "$(op account list)" ]
then
    info "No accounts configured in 1Password CLI, running ${BOLD}op account add${RESET}"
    ADD_ACCOUNT_CMD="op account add"

    if [ -n "$OP_SIGN_IN_ADDRESS" ]
    then
        ADD_ACCOUNT_CMD="$ADD_ACCOUNT_CMD --address \"$OP_SIGN_IN_ADDRESS\""
    fi

    if [ -n "$OP_EMAIL" ]
    then
        ADD_ACCOUNT_CMD="$ADD_ACCOUNT_CMD --email \"$OP_EMAIL\""
    fi

    if [ -n "$OP_SECRET_KEY" ]
    then
        ADD_ACCOUNT_CMD="$ADD_ACCOUNT_CMD --secret-key \"$OP_SECRET_KEY\""
    fi

    if [ -n "$OP_PASSWORD" ]
    then
        ADD_ACCOUNT_CMD="echo '$OP_PASSWORD' | $ADD_ACCOUNT_CMD"
    fi

    eval "$ADD_ACCOUNT_CMD"
fi

info "Signing in to 1Password CLI"
if [ -n "$OP_PASSWORD" ]
then
    eval "$(echo "$OP_PASSWORD" | op signin)"
    
else
    eval "$(op signin)"
fi

info "Downloading SSH Keys to ${BOLD}\$HOME/.ssh${RESET}"
# we don't use JSON output because we're trying to avoid installing JQ during
# bootstrap, so we use cut and tr instead.
op --no-color item list --categories 'SSH Key' | tail -n +2 | while IFS= read -r item
do
    title="$(echo "$item" | tr -s ' ' | cut -d ' ' -f2 | tr -s '[:blank:]' '_')"
    vault="$(echo "$item" | tr -s ' ' | cut -d ' ' -f3)"

    mkdir -p "$HOME"/.ssh
    if [ ! -f "$HOME/.ssh/${title}.pub" ]
    then
        op read --out-file "$HOME/.ssh/${title}.pub" "op://${vault}/${title}/public key"
    fi
    
    if [ ! -f "$HOME/.ssh/${title}" ] && [ "$DOWNLOAD_PRIVATE_KEYS" = 1 ]
    then
        op read --out-file "$HOME/.ssh/${title}" "op://${vault}/${title}/private key"
    fi

done

export OP_BIOMETRIC_UNLOCK_ENABLED="${OLD_BIOMETRIC_VAR}"

if ! command -v chezmoi >/dev/null 2>&1
then
    info "Installing ${BOLD}chezmoi${RESET}"
    if [ "$BREW_CHEZMOI" = 1 ]
    then
        info "Installing chezmoi from homebrew\n"
        brew install chezmoi
    elif [ "$MISE_CHEZMOI" = 1 ]
    then
        info "Installing chezmoi from mise\n"
        mise use -g chezmoi
    else
        prepend_path "$CHEZMOI_INSTALL_PATH"
        cd "$DLDIR" || abort "Unexpected error"
        mkdir -p chezmoi
        cd chezmoi || abort "Unexpected error"

        info "Downloading Chezmoi install script"
        curl -fsLS get.chezmoi.io > install.sh || abort "Failed to download chezmoi install script"
        chmod +x install.sh

        info "Running chezmoi install script"
        ./install.sh -b "$CHEZMOI_INSTALL_PATH"

        cd "$WORKDIR" || abort "Unexpected error"
    fi
fi

ensure chezmoi

OS_FLAVOR_CONFDIR="$SCRIPTDIR/${OS_FLAVOR}"
export OS_FLAVOR_CONFDIR


OP_APP_BUNDLE="$(mdfind 'kMDItemCFBundleIdentifier == "com.1password.1password"')"

if [ -z "$OP_APP_BUNDLE" ]; then
    cd "$DLDIR" || abort "Unexpected error"
    mkdir -p "1p"
    cd 1p || abort "Unexpected error"

    info "installing 1Password App"
    info "Downloading 1Password Installer app .zip"
    curl -sLJO "https://downloads.1password.com/mac/1Password.zip"

    info "Unzipping 1Password Installer"
    unzip 1Password.zip

    info "Running 1Password Installer"
    open -W "1Password Installer.app"
    cd "$WORKDIR" || abort "Unexpected error"
fi
## Create a temporary config file for using the 1P SSH Agent

mkdir -p "$HOME/.ssh"
touch "$HOME/.ssh/config"
chmod 700 "$HOME/.ssh"

cat - "$HOME/.ssh/config" <<'EOF' > "$HOME/.ssh/config_new"
Host *.github.com
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
EOF

mv "$HOME/.ssh/config_new" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

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
