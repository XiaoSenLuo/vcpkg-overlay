#!/usr/bin/env bash
# Cross-validation matrix for the deploy scripts: deploy with {sh,bat,ps1}
# x restore with {sh,bat,ps1} = 9 combinations, all against a real vcpkg root.
# Every cell must end byte-identical to its pre-deploy snapshot (file list +
# sha1 of every file in the three destination trees).
#
# Usage: ./cross-test.sh <vcpkg-root>     (e.g. /e/Work/LinuxProject/vcpkg
#                                          or E:\Work\LinuxProject\vcpkg)
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WINROOT="${1:?usage: cross-test.sh <vcpkg-root>}"
ROOT="$(printf '%s' "$WINROOT" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/\L\1|')"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

snapshot() { # $1 = output file: sorted "<sha1>  <path>" of the three dest trees
    local roots="" r
    for r in overlay scripts/toolchains triplets; do
        [ -e "$ROOT/$r" ] && roots="$roots $r"
    done
    (cd "$ROOT" && find $roots -type f | sort |
        while IFS= read -r f; do sha1sum "$f"; done) > "$1"
}

deploy() {
    case "$1" in
        sh)  (cd "$REPO" && ./deploy-overlay.sh --vcpkg-root "$WINROOT") ;;
        bat) (cd "$REPO" && cmd //c "deploy-overlay.bat --vcpkg-root $WINROOT") ;;
        ps1) (cd "$REPO" && powershell -NoProfile -ExecutionPolicy Bypass -File deploy-overlay.ps1 --vcpkg-root "$WINROOT") ;;
    esac
}

restore() {
    case "$1" in
        sh)  (cd "$REPO" && ./deploy-overlay.sh --vcpkg-root "$WINROOT" --restore) ;;
        bat) (cd "$REPO" && cmd //c "deploy-overlay.bat --vcpkg-root $WINROOT --restore") ;;
        ps1) (cd "$REPO" && powershell -NoProfile -ExecutionPolicy Bypass -File deploy-overlay.ps1 --vcpkg-root "$WINROOT" --restore) ;;
    esac
}

# verify: every repo source file is deployed with identical content, every
# *.origin keeps the exact pre-deploy content of the file it replaced
check_deployed() { # $1 = pre-snapshot
    local rel dest src_hash dst_hash fails=0 expect_origin=0
    declare -A PRE
    while IFS= read -r line; do
        local h rest p
        h="${line%% *}"
        rest="${line#* }"          # "*path" or " path"
        p="${rest#\*}"; p="${p# }" # strip binary-star marker / leading space
        PRE["$p"]="$h"
    done < "$1"
    while IFS= read -r rel; do
        case "$rel" in
            ports/*)      dest="overlay/${rel}" ;;
            toolchains/*) dest="scripts/${rel}" ;;
            triplets/*)   dest="$rel" ;;
        esac
        if [ -n "${PRE[$dest]-}" ]; then expect_origin=$((expect_origin + 1)); fi
        src_hash="$(sha1sum "$REPO/$rel" | cut -d' ' -f1)"
        if [ ! -f "$ROOT/$dest" ]; then
            echo "  MISSING deployed file: $dest"; fails=1; continue
        fi
        dst_hash="$(sha1sum "$ROOT/$dest" | cut -d' ' -f1)"
        [ "$src_hash" = "$dst_hash" ] || { echo "  DIFF deployed file: $dest"; fails=1; }
    done < <(cd "$REPO" && find ports toolchains triplets -type f | sort)

    local n_origin=0
    while IFS= read -r o; do
        [ -n "$o" ] || continue
        n_origin=$((n_origin + 1))
        local base="${o%.origin}" want have
        want="${PRE[$base]-}"
        [ -n "$want" ] || { echo "  ORIGIN without pre-state: $o"; fails=1; continue; }
        have="$(sha1sum "$ROOT/$o" | cut -d' ' -f1)"
        [ "$want" = "$have" ] || { echo "  ORIGIN content mismatch: $o"; fails=1; }
    done < <(cd "$ROOT" && find overlay scripts/toolchains triplets -name '*.origin' | sort)
    [ "$n_origin" -eq "$expect_origin" ] ||
        { echo "  ORIGIN count $n_origin != expected $expect_origin"; fails=1; }
    return $fails
}

check_restored() { # $1 = pre-snapshot
    snapshot "$TMP/post.txt"
    if diff -q "$1" "$TMP/post.txt" >/dev/null; then return 0; fi
    echo "  TREE differs from pre-deploy snapshot:"
    diff "$1" "$TMP/post.txt" | head -10
    return 1
}

num() { grep -oE "$1 [0-9]+" | grep -oE "[0-9]+" | head -1; }

BASELINE_STATUS="$(git -C "$ROOT" status --porcelain 2>/dev/null || true)"
snapshot "$TMP/baseline.txt"

echo "== cross-test matrix on $WINROOT"
printf "%-6s %-6s %-24s %-24s %s\n" DEPLOY RESTORE DEPLOY-LOG RESTORE-LOG RESULT
overall=0
for d in sh bat ps1; do
    for r in sh bat ps1; do
        cp "$TMP/baseline.txt" "$TMP/pre.txt"
        dlog="$(deploy "$d" 2>&1)"; drc=$?
        if [ $drc -ne 0 ]; then
            printf "%-6s %-6s %-24s %-24s %s\n" "$d" "$r" "EXIT=$drc" "-" "FAIL"
            overall=1; continue
        fi
        dsum="$(echo "$dlog" | tail -1 | num 'copied')copied/$(echo "$dlog" | tail -1 | num 'reserved')reserved"
        if ! check_deployed "$TMP/pre.txt"; then
            printf "%-6s %-6s %-24s %-24s %s\n" "$d" "$r" "$dsum" "-" "FAIL(deployed-state)"
            restore "$r" >/dev/null 2>&1; overall=1; continue
        fi
        rlog="$(restore "$r" 2>&1)"; rrc=$?
        if [ $rrc -ne 0 ]; then
            printf "%-6s %-6s %-24s %-24s %s\n" "$d" "$r" "$dsum" "EXIT=$rrc" "FAIL"
            overall=1; continue
        fi
        rsum="$(echo "$rlog" | tail -1 | num 'removed')removed/$(echo "$rlog" | tail -1 | num 'restored')restored"
        if check_restored "$TMP/pre.txt"; then verdict=PASS; else verdict=FAIL; overall=1; fi
        printf "%-6s %-6s %-24s %-24s %s\n" "$d" "$r" "$dsum" "$rsum" "$verdict"
    done
done

final_status="$(git -C "$ROOT" status --porcelain 2>/dev/null || true)"
if [ "$final_status" = "$BASELINE_STATUS" ]; then
    echo "== final vcpkg-root state matches the initial baseline"
else
    echo "== FATAL: vcpkg root drifted from the initial baseline:"
    diff <(printf '%s\n' "$BASELINE_STATUS") <(printf '%s\n' "$final_status") | head -10
    overall=1
fi
exit $overall
