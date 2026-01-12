#!/usr/bin/env sh

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
