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

cd $(dirname $0)
pkill -f "conky.*\s-- $magic_id"
font/install

# Conky 1.25's Wayland set_font aborts when the font list is still empty.
# That call happens once, before load_fonts. The copy below turns that
# abort into a return. A newer /usr/bin/conky replaces the copy.
if [ "$conky_bin" = "conky" ]; then
    system_conky=/usr/bin/conky
    conky_bin="$(pwd)/conky-wayland"
    if [ ! -f "$conky_bin" ] || [ "$system_conky" -nt "$conky_bin" ]; then
        cp "$system_conky" "$conky_bin"
        python3 - "$conky_bin" << 'PY'
import sys
path = sys.argv[1]
data = bytearray(open(path, "rb").read())
old = bytes.fromhex("0f834225f1ff")
new = bytes.fromhex("0f8326000000")
found = data.find(old)
if found < 0:
    sys.exit("conky-wayland: set_font assert pattern not found; package layout changed")
data[found:found + len(old)] = new
open(path, "wb").write(data)
PY
        chmod +x "$conky_bin"
    fi
fi

[ -z "$pause_flag" ] && echo "Starting Conky..." || echo "Conky waiting 3 seconds to start..."
if "$conky_bin" --daemonize --quiet "$pause_flag" --config=./conky.conf -- $magic_id; then
    echo "Started"
else
    echo "Failed"
fi
