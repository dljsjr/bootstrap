#!/usr/bin/env sh

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