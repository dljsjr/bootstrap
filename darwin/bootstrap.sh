#!/usr/bin/env sh

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
