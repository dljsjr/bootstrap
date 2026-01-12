#!/usr/bin/env sh

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