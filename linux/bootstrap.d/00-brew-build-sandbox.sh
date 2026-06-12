#!/usr/bin/env sh

# Homebrew (since June 2026) isolates Linux from-source builds in a rootless
# Bubblewrap sandbox, which requires unprivileged user namespaces. Bottled
# installs don't need this, but any tap that doesn't ship bottles does.
# Persist the knobs via sysctl.d and apply them immediately; the leading '-'
# tells sysctl to skip keys this kernel doesn't provide
# (kernel.unprivileged_userns_clone is a Debian patch knob, and the AppArmor
# restriction only exists on newer AppArmor-enabled kernels like Ubuntu 24.04,
# where it defaults to 1 and is the actual blocker).
SYSCTL_DROPIN="/etc/sysctl.d/99-homebrew-bubblewrap.conf"

if ! command -v sysctl >/dev/null 2>&1
then
    warn "No sysctl on this Linux; Homebrew's Bubblewrap build sandbox may not work without unprivileged user namespaces"
elif [ -f "$SYSCTL_DROPIN" ]
then
    debug "Homebrew Bubblewrap sysctls already configured"
else
    info "Enabling unprivileged user namespaces for Homebrew's Bubblewrap build sandbox"
    # 28633 is the floor brew asks for; the kernel default scales with RAM and
    # is often far higher (e.g. 256860 on a stock Ubuntu 24.04 VM), so only
    # pin it when the current value falls short.
    MAX_USERNS_LINE=""
    CURRENT_MAX_USERNS="$(sysctl -n user.max_user_namespaces 2>/dev/null || echo 0)"
    if [ "$CURRENT_MAX_USERNS" -lt 28633 ] 2>/dev/null
    then
        MAX_USERNS_LINE="-user.max_user_namespaces = 28633"
    fi
    sudo tee "$SYSCTL_DROPIN" >/dev/null <<EOF || abort "failed to write ${SYSCTL_DROPIN}"
# Homebrew's Linux build sandbox (rootless Bubblewrap) needs unprivileged
# user namespaces. Written by dljsjr/bootstrap. A leading '-' tells sysctl
# to ignore keys this kernel doesn't provide.
-kernel.unprivileged_userns_clone = 1
-kernel.apparmor_restrict_unprivileged_userns = 0
${MAX_USERNS_LINE}
EOF
    sudo sysctl -p "$SYSCTL_DROPIN" || warn "sysctl -p failed; settings will still land on next boot via sysctl.d"
fi
