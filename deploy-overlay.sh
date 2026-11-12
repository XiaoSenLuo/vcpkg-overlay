#!/usr/bin/env bash
# Deploy this overlay repository into a vcpkg installation:
#   ports/      -> <vcpkg-root>/overlay/ports
#   toolchains/ -> <vcpkg-root>/scripts/toolchains
#   triplets/   -> <vcpkg-root>/triplets
# Existing files with the same name are renamed to <file-name>.origin;
# --restore deletes the deployed files and renames the *.origin ones back.
#
# Usage: ./deploy-overlay.sh --vcpkg-root <path> [--restore]
set -euo pipefail
shopt -s dotglob nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 --vcpkg-root <path> [--restore]"
    echo "  --vcpkg-root <path>  vcpkg installation root directory (required)"
    echo "  --restore            remove deployed files and restore *.origin backups"
}

VCPKG_ROOT=""
RESTORE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --vcpkg-root)
            [ $# -ge 2 ] || { echo "error: --vcpkg-root requires a value" >&2; exit 2; }
            VCPKG_ROOT="$2"; shift 2 ;;
        --vcpkg-root=*)
            VCPKG_ROOT="${1#*=}"; shift ;;
        --restore)
            RESTORE=1; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$VCPKG_ROOT" ]; then
    echo "error: --vcpkg-root is not specified." >&2
    echo "Please install vcpkg first (https://github.com/microsoft/vcpkg)," >&2
    echo "then pass its root directory with --vcpkg-root <path>." >&2
    exit 1
fi

if [ ! -d "$VCPKG_ROOT/scripts/toolchains" ]; then
    echo "error: '$VCPKG_ROOT' is not a vcpkg root (scripts/toolchains not found)." >&2
    exit 1
fi
VCPKG_ROOT="$(cd "$VCPKG_ROOT" && pwd)"

n_copied=0
n_reserved=0
n_removed=0
n_restored=0

# rename an existing destination entry to <name>.origin
reserve() {
    local target="$1"
    if [ -e "$target.origin" ]; then
        echo "note: '$target.origin' already exists, keeping it" >&2
    else
        mv "$target" "$target.origin"
        echo "reserved: $target -> $target.origin"
        n_reserved=$((n_reserved + 1))
    fi
}

deploy_tree() {
    local src="$1" dst="$2" entry name target
    mkdir -p "$dst"
    for entry in "$src"/*; do
        [ -e "$entry" ] || continue
        name="${entry##*/}"
        target="$dst/$name"
        if [ -d "$entry" ]; then
            if [ -e "$target" ] && [ ! -d "$target" ]; then
                reserve "$target"
            fi
            deploy_tree "$entry" "$target"
        else
            if [ -e "$target" ]; then
                reserve "$target"
            fi
            cp -p "$entry" "$target"
            echo "copied: $entry -> $target"
            n_copied=$((n_copied + 1))
        fi
    done
}

restore_tree() {
    local src="$1" dst="$2" entry name target
    [ -d "$dst" ] || return 0
    for entry in "$src"/*; do
        [ -e "$entry" ] || continue
        name="${entry##*/}"
        target="$dst/$name"
        if [ -d "$entry" ]; then
            restore_tree "$entry" "$target"
        else
            if [ -e "$target" ]; then
                rm -rf "$target"
                echo "removed: $target"
                n_removed=$((n_removed + 1))
            fi
            if [ -e "$target.origin" ]; then
                mv "$target.origin" "$target"
                echo "restored: $target.origin -> $target"
                n_restored=$((n_restored + 1))
            fi
        fi
    done
}

# remove empty sub-directories of $1 (bottom-up), keeping $1 itself
cleanup_empty_dirs() {
    local root="$1"
    [ -d "$root" ] || return 0
    find "$root" -mindepth 1 -depth -type d -empty -print -delete
}

# remove $1 only if it is an empty directory
rmdir_if_empty() {
    [ -d "$1" ] && rmdir "$1" 2>/dev/null || true
}

DST_PORTS="$VCPKG_ROOT/overlay/ports"
DST_TOOLCHAINS="$VCPKG_ROOT/scripts/toolchains"
DST_TRIPLETS="$VCPKG_ROOT/triplets"

if [ "$RESTORE" -eq 1 ]; then
    restore_tree "$SCRIPT_DIR/ports" "$DST_PORTS"
    restore_tree "$SCRIPT_DIR/toolchains" "$DST_TOOLCHAINS"
    restore_tree "$SCRIPT_DIR/triplets" "$DST_TRIPLETS"
    cleanup_empty_dirs "$DST_PORTS"
    rmdir_if_empty "$DST_PORTS"
    rmdir_if_empty "$VCPKG_ROOT/overlay"
    cleanup_empty_dirs "$DST_TOOLCHAINS"
    cleanup_empty_dirs "$DST_TRIPLETS"
    echo "restore finished: removed $n_removed file(s), restored $n_restored backup(s)"
else
    stale="$(find "$DST_PORTS" "$DST_TOOLCHAINS" "$DST_TRIPLETS" -name '*.origin' -print -quit 2>/dev/null)"
    if [ -n "$stale" ]; then
        echo "error: found '$stale' left by a previous deploy." >&2
        echo "Run '$0 --vcpkg-root <path> --restore' first, then deploy again." >&2
        exit 1
    fi
    deploy_tree "$SCRIPT_DIR/ports" "$DST_PORTS"
    deploy_tree "$SCRIPT_DIR/toolchains" "$DST_TOOLCHAINS"
    deploy_tree "$SCRIPT_DIR/triplets" "$DST_TRIPLETS"
    echo "deploy finished: copied $n_copied file(s), reserved $n_reserved original(s) as *.origin"
fi
