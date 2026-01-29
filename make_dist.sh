#!/usr/bin/env sh
#-DIST_IGNORE
if [ -z "$STATE_FILE" ]
then
    STATE_FILE="$(mktemp)"
    if ! [ -f "$STATE_FILE" ]
    then
        abort "failed to create temporary file for state tracking"
    fi
    export STATE_FILE
fi

OS_FLAVOR=
CPU_ARCH=
while [ $# -gt 0 ]
do
    case "$1" in
        --os)
            OS_FLAVOR="$2"
            shift
            ;;
        --arch)
            CPU_ARCH="$2"
            shift
            ;;
        *)
            printf "Unrecognized option: %s\n" "$1" >&2
            exit 1
            ;;
    esac
    shift
done

WORKDIR="$(/bin/pwd -P)"
export WORKDIR

SCRIPTDIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && /bin/pwd -P)"
export SCRIPTDIR

# source helper functions script
# shellcheck source=_functions.sh
. "$SCRIPTDIR/_functions.sh"
BOOTSTRAP_MAKE_DIST=true
export BOOTSTRAP_MAKE_DIST

if [ -z "$OS_FLAVOR" ]
then
    OS_FLAVOR="$(os_flavor)"
fi
export OS_FLAVOR

if [ -z "$CPU_ARCH" ]
then
    CPU_ARCH="$(cpu_arch)"
fi
export CPU_ARCH

MACHINE="${OS_FLAVOR}_${CPU_ARCH}"
export MACHINE

OS_FLAVOR_CONFDIR="$SCRIPTDIR/${OS_FLAVOR}"
export OS_FLAVOR_CONFDIR

doDirectoryInline() (
    if [ -f "${1}/bootstrap.sh" ]
    then
        doDistInline "${1}/bootstrap.sh"
    fi

    for script_file in "${1}"/*.sh
    do
        if ! [ "$(basename "$script_file")" = "bootstrap.sh" ]
        then
            doDistInline "$script_file"
        fi
    done

    if [ -d "${1}/bootstrap.d" ]
    then
        doDistInline "${1}/bootstrap.d"
    fi
)

doFileInline() (
    EMIT=true
    while IFS= read -r line || [ -n "$line" ]
    do
        if [ "$EMIT" = true ] && echo "$line" | grep -q '^#-BEGIN:'
        then
            EMIT=false
            import_target="$(eval echo "$(echo "$line" | sed -e 's/^#-BEGIN:\(.*\)$/\1/g')")"
            doDistInline "$import_target"
        elif [ "$EMIT" = false ] && echo "$line" | grep -q '^#-END:'
        then
            EMIT=true
        elif [ "$EMIT" = true ] && ! { { echo "$line" | grep -q '^#!'; } || { echo "$line" | grep -q '[[:blank:]]\{0,\}#\{1,\}[[:blank:]]\{0,\}shellcheck disable'; } }
        then
            rawprint "%s\n" "$line"
        fi
    done < "$1"
)

doDistInline() (
    if ! grep -q "$1" "$STATE_FILE"
    then
        echo "$1" >> "$STATE_FILE"
        if [ -f "$1" ] && !  grep -q "^#-DIST_IGNORE" "$1"
        then
            info "inlining file %s\n" "$1" >&2
            doFileInline "$1"
        elif [ -d "$1" ]
        then
            info "inlining directory %s\n" "$1" >&2
            doDirectoryInline "$1"
        fi
    fi
)

mkdir -p "${SCRIPTDIR}/dist"
OUTFILE="${SCRIPTDIR}/dist/boostrap-${MACHINE}.sh"
printf "creating dist %s\n" "$OUTFILE"

rawprint "#!/usr/bin/env sh\n" > "$OUTFILE"
doDistInline "${SCRIPTDIR}" >> "$OUTFILE"

cat - <<EOF > "${SCRIPTDIR}/bootstrap-dist.sh"
#!/usr/bin/env sh
#-DIST_IGNORE
set -eu

rawprint() {
    command printf "\$@"
}
$(tail -n +2 "${SCRIPTDIR}"/_functions.d/01-os_utils.sh)

MACHINE="\$(os_flavor)_\$(cpu_arch)"
/bin/sh -c "\$(curl -fsSL "https://raw.githubusercontent.com/dljsjr/bootstrap/refs/heads/main/dist/boostrap-\${MACHINE}.sh")"
EOF
