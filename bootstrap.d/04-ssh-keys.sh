#!/usr/bin/env sh

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