#!/usr/bin/env sh

if ! command -v age >/dev/null 2>&1
then
    info "Installing ${BOLD}age${RESET} from homebrew"
    brew install age
fi