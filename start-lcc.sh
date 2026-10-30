#!/bin/sh
# vim: ft=sh:ts=4:sw=4:et:ai:cin

usage() {
    echo "USAGE: $(basename $0) [-n] [-p CONKY_PATH]"
}

conky_bin="conky"
pause_flag="--pause=3"
magic_id="0ce31833f8f0bae3" # truncated md5sum of 'lean-conky-config'

while getopts "np:rh" opt; do
    case $opt in
    n) # no-waiting
        pause_flag=""
        ;;
    p) # path to conky binary
        conky_bin=$(realpath -- "$OPTARG")
        if [ -x "$conky_bin" ]; then
            echo "Conky binary path: ${conky_bin}"
        else
            echo "ERROR: ${conky_bin} is not executable, path to Conky binary needed\n" >&2
            usage
            exit 1
        fi
        ;;
    r) # reload
        pkill -SIGUSR1 -f $magic_id && echo "Reloading Conky/LCC..."
        exit
        ;;
    h) # help
        usage
        exit
        ;;
    \?)
        echo "ERROR: Invalid option: -$OPTARG\n" >&2
        usage
        exit 2
        ;;
    esac
done
shift "$((OPTIND - 1))"

cd "$(dirname "$0")"

# Check Conky before stopping a running panel, so a failed start keeps it.
if [ "$conky_bin" = "conky" ]; then
    system_conky=$(command -v conky 2>/dev/null)
    if [ -z "$system_conky" ]; then
        echo "ERROR: Conky is not installed." >&2
        echo "  Arch / CachyOS / EndeavourOS / Omarchy:  sudo pacman -S conky" >&2
        echo "  Debian / Ubuntu:                         sudo apt install conky-all" >&2
        echo "  Fedora:                                  sudo dnf install conky" >&2
        exit 1
    fi
fi

pkill -f "conky.*\s-- $magic_id"
font/install

# Conky's Wayland output asserts in set_font() when it runs before the fonts
# are loaded, which happens once at startup, so distro builds (asserts on)
# abort. tools/patch-conky-wayland copies the system binary to ./conky-wayland
# and makes that assert a plain return (details in the tool). It finds the code
# by its shape, so Arch, CachyOS (x86-64-v3/v4) and later builds all work.
# conky-wayland.source records which system binary the copy came from (path +
# checksum: pacman keeps the package's old build date, so -nt is unreliable);
# any change to the system Conky re-patches.
if [ "$conky_bin" = "conky" ]; then
    patched="$(pwd)/conky-wayland"
    stamp="$patched.source"
    source_id="$system_conky $(cksum < "$system_conky")"
    if [ ! -x "$patched" ] || [ "$(cat "$stamp" 2>/dev/null)" != "$source_id" ]; then
        rm -f "$patched" "$stamp"
        if ! command -v python3 >/dev/null 2>&1; then
            echo "WARNING: python3 not found, cannot apply the Wayland font fix; using $system_conky" >&2
        else
            python3 tools/patch-conky-wayland "$system_conky" "$patched"
            case $? in
            0) echo "$source_id" > "$stamp" ;;
            3)
                echo "WARNING: this Conky build does not match the Wayland font fix; using $system_conky." >&2
                echo "         On X11 that is fine. On Wayland, if Conky aborts at start, please open an issue" >&2
                echo "         with the output of: conky --version" >&2
                ;;
            *) echo "WARNING: Wayland font fix failed; using $system_conky" >&2 ;;
            esac
        fi
    fi
    if [ -x "$patched" ] && [ -f "$stamp" ]; then
        conky_bin="$patched"
    else
        conky_bin="$system_conky"
    fi
fi

[ -z "$pause_flag" ] && echo "Starting Conky..." || echo "Conky waiting 3 seconds to start..."
if "$conky_bin" --daemonize --quiet "$pause_flag" --config=./conky.conf -- $magic_id; then
    echo "Started"
else
    echo "Failed"
fi
