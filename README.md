# bootstrap 🪄 👢

My cross-platform bootstrap scripts. In a nutshell, these scripts do the super low-level plumbing
that needs to happen before dotfiles can be applied. Supports Linux and macOS.

## POSIX Compabitility

The scripts here all use the shebang `#!/usr/bin/env sh`, and when calling out to POSIX-compliant tools
such as `sed` or `grep`, we attempt to use them in the most POSIX-compliant way possible. No Bash/ZSH'isms,
we use `$()` intead of backticks, we use POSIX-compliant `test` syntax, globbing syntax, pattern matching,
`.` instead of `source`, etc.

That also means that we strive to use [Posix BRE](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html#tag_09_03)
for `grep`/`sed`, and we avoid GNU extensions to POSIX commands that can be found in the GNU `coreutils`.

## High-Level Overview

This script does a small handful of things:

1. Ensures that `homebrew` (<https://brew.sh>) is installed
2. Ensures that `mise` (<https://mise.jdx.dev>)is installed
3. Ensures that the 1Password CLI (<https://developer.1password.com/docs/cli/>) is installed
4. Ensures that `age` (<https://github.com/FiloSottile/age>) is installed
5. Export SSH keys from 1Password (via the CLI) to local disk
6. Ensures that `chezmoi` (<https://www.chezmoi.io/>) is installed
7. Bootstraps `chezmoi` dotfiles or grab (and optionally apply) `chezmoi` dotfiles from a provided location

## Usage

### Quick Start

1. Clone the repo
2. Ensure the main `bootstrap.sh` file in the repo root is executable
3. Run the main `bootstrap.sh` file in the repo root

### Advanced Usage

Many of the bootstrapping steps can have some of their behavior modified using flags.

For example, you can typically control how something is installed if there are multiple options. As an example,
you can control whether or not things like `mise` or `chezmoi` are installed using their `curl | sh` installers,
or via `homebrew`.

Use `./bootstrap.sh --help` for more information on configuring behavior.

If a tool has its own installer, and that's the installtion method that is used, then you *should* likely be able
to use that installer's env var options as well. See the install documentation for individual tools for more
information.

## Internals Overview

### Repository Layout

```console
./
├── _functions.d/
├── bootstrap.d/
├── darwin/
│   ├── bootstrap.d/
│   └── bootstrap.sh
├── linux/
│   ├── bootstrap.d/
│   └── bootstrap.sh
├── _functions.sh
├── bootstrap.sh*
└── README.md
```

### Overview of Files

`./bootstrap.sh` is the entrypoint of the script. It handles argument parsing and establishing the environment used
by the rest of the configuration scripts.

`_functions.sh` establishes a handful of utility functions; it also automatically sourceses the files in the `./_functions.d`
directory.

### File Execution Order

After `./bootstrap.sh` sets up the execution environment for the bootstrapping scripts, it will execute the files in
`bootstrap.d` as well as any OS-specific files located in their respective directories. OS-specific configurations can contain
a root `bootstrap.sh`, and they can also contain their own `bootstrap.d` directories.

- on macOS, the OS-specific configs live in the `darwin` directory
- on Linux, the OS-specific configs live in the `linux` directory

We utilize the convention of sorting files alphanumerically and using 2-digit prefixes to control execution order.

> [!IMPORTANT]
> Note that the sorting here is *alphanumeric*, not numeric. That means that `10` comes *before* `2`, which is
> why all script files should use a two-digit prefix to control priority; a leading `0` is used for single digit
> priorities, i.e., `02` instead of `2`.

The files in `bootstrap.d` are executed before the OS-specific files.

In other words, this is the file execution order:

1. `bootstrap.sh` will import `_functions.sh` and `_functions.d/*.sh` early in execution
2. `bootstrap.sh` will configure the execution environment
3. `bootstrap.sh` will execute all of the scripts in `bootstrap.d/` in alphanumerical order
4. `bootstrap.sh` will execute `<os flavor>/bootstrap.sh` if it exists
5. `bootstrap.sh` will execute `<os flavor>/bootstrap.d/*.sh` in alphanumerical order, if any exist
6. `bootstrap.sh` will call `chezmoi init --apply` (or whatever chezmoi command is configured via the script flags)

### Logging/Printing

`_functions.sh` establishes a message formatting system for reporting on events during script execution, availailble to all scripts.

The following functions are available:

1. `info` for informational logs
2. `warn` for warning logs
3. `error` for reporting critical errors
4. `abort` for reporting a fatal error and then immediately exiting with return code `1`
5. `debug` for debug messages, which are *not* printed by default
6. `printf` is aliased to `info`
7. `rawprint` provides access to the unaliased/original `printf`
8. `linebreak` is a helper function for inserting a blank line if and only if log messages have been emitted
   since the last time `linebreak` was called

There is no log level filtering outside of whether or not debug logs are printed. Debug logging is enabled with  `DEBUG_BOOTSTRAP=1`

Additionally, the following variables are also available for ANSI text coloring:

```shell
# Activate bold foreground/text
BOLD

# Activate red foreground/text
RED

# Activate green foreground/text
GREEN

# Activate yellow foreground/text
YELLOW

# Activate blue foreground/text
BLUE

# Activate magenta foreground/text
MAGENTA

# Activate cyan foreground/text
CYAN

# Activate white foreground/text
WHITE

# Reset the foreground color/bold/etc. to normal
RESET
```

### Execution Environment

Command options/arguments are parsed and propagated to other scripts using environment variables, but *after* utility functions
have been imported. In other words, the following environment variables are `export`ed by `bootstrap.sh` before other scripts are executed,
but they are *not* available to the `_functions` utlities, as those are imported before the environment is configured.

```shell
# The current directory of the shell session that the command was invoked from (i.e. `$PWD` or `/bin/pwd`)
export WORKDIR

# Absolute canonical path to the parent directory of the top-level `./bootstrap.sh` script on disk
export SCRIPTDIR

# A temporary dir created with `mktemp -d` for storing scratch files
export DLDIR

# Either `darwin` or `linux`
export OS_FLAVOR

# Normalized string representing the CPU Architecture; either `arm32`, `arm64`, or `amd64` (other architectures aren't supported)
export CPU_ARCH

# String combining the OS and Arch in the form `${OS_FLAVOR}_${CPU_ARCH}, e.g. `darwin_arm64` or `linux_amd64`
export MACHINE

# The positional argument that will be passed to `chezmoi init`
export CHEZMOI_DOTFILES_ARG

# Directory to install the `chezmoi` binary when using the curl | sh installation method
export CHEZMOI_INSTALL_PATH

# 0 or 1, whether or not to pass `--apply` to `chezmoi` (default 1)
export CHEZMOI_APPLY

# 0 or 1, whether or not to pass `--purge` to `chezmoi` (default 0)
export PURGE

# 0 or 1, whether or not to pass `--purge-binary` to `chezmoi` (default 0)
export PURGE_BINARY

# 0 or 1, whether or not to install `mise` using `brew` (default 0)
export BREW_MISE

# 0 or 1, whether or not to install `chezmoi` using `brew` (default 0)
export BREW_CHEZMOI

# 0 or 1, whether or not to install `chezmoi` using `mise use --global` (default 0)
export MISE_CHEZMOI

# directory to install the OP CLI binary if using the .zip installation method
export OP_CLI_INSTALL_PATH

# 0 or 1, whether or not to install `op` using `homebrew` (default 0)
export BREW_OP_CLI

# 0 or 1, whether or not to install `op` using the macOS .pkg installer (default 0)
export PKG_OP_CLI

# Optional, The URL of the 1Password sign-in server to use
export OP_SIGN_IN_ADDRESS

# Optional, The email address for the 1Password account
export OP_EMAIL

# Optional, The password for the 1Password account
export OP_PASSWORD

# Optional, The secret key for the 1Password account
export OP_SECRET_KEY

# 0 or 1, whether or not to download SSH private keys to disk in addition to the public keys (default 0)
export DOWNLOAD_PRIVATE_KEYS
```
