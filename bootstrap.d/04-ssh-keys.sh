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
mkdir -p "$HOME"/.ssh

# Item titles can contain spaces, so the tabular `op item list` output can't
# be split on whitespace reliably; use JSON output instead. python3 keeps us
# jq-free (present on macOS once the CLT are installed, and on Ubuntu by
# default). Items are addressed by ID in the secret references, with the
# snake_cased title used only for the on-disk filename.
ensure python3 "needed to parse 'op item list' JSON output"

op item list --categories 'SSH Key' --format=json | python3 -c '
import json, sys
for item in json.load(sys.stdin):
    title = "_".join(item["title"].split())
    print("\t".join((item["id"], title, item["vault"]["id"])))
' | while IFS="$(rawprint '\t')" read -r item_id title vault_id
do
    if [ ! -f "$HOME/.ssh/${title}.pub" ]
    then
        op read --out-file "$HOME/.ssh/${title}.pub" "op://${vault_id}/${item_id}/public key"
    fi

    if [ ! -f "$HOME/.ssh/${title}" ] && [ "$DOWNLOAD_PRIVATE_KEYS" = 1 ]
    then
        op read --out-file "$HOME/.ssh/${title}" "op://${vault_id}/${item_id}/private key"
    fi

done

export OP_BIOMETRIC_UNLOCK_ENABLED="${OLD_BIOMETRIC_VAR}"
