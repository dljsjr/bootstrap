#!/usr/bin/env sh
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
