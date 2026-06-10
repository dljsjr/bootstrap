#!/usr/bin/env sh

# apt preflight: Homebrew-on-Linux build prerequisites plus tools the common
# bootstrap.d steps silently assume (`unzip` for the op CLI .zip, `curl` and
# `git` everywhere). IaC-managed boxes generally provide all of this already;
# the loop below only acts on packages that are actually missing.
if command -v apt-get >/dev/null 2>&1
then
    APT_PREREQS="build-essential procps curl file git unzip"

    APT_MISSING=""
    for pkg in $APT_PREREQS
    do
        if ! dpkg -s "$pkg" >/dev/null 2>&1
        then
            APT_MISSING="$APT_MISSING $pkg"
        fi
    done

    if [ -n "$APT_MISSING" ]
    then
        info "Installing apt prerequisites:${BOLD}%s${RESET}" "$APT_MISSING"
        sudo apt-get update -qq || abort "apt-get update failed"
        # shellcheck disable=SC2086
        sudo apt-get install -y $APT_MISSING || abort "apt-get install failed"
    else
        debug "All apt prerequisites already present"
    fi
else
    warn "No apt-get on this Linux; ensure equivalents of: build-essential procps curl file git unzip"
fi
