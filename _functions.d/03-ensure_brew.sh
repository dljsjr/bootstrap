#!/usr/bin/env sh

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