[[ "$( type -t coproc::register || true )" != 'function' ]] || return 0

declare -gi COPROC_PROCESS_ID

# ——— Functions definition —————————————————————————————————————————————————————

function coproc::register() { # $0 <pid>
    export COPROC_PROCESS_ID="$1"
}
declare -rf coproc::register

function coproc::waitForPrevious() { # $0
    [[ -v COPROC_PROCESS_ID ]] || return 0
    ps -p "$COPROC_PROCESS_ID" >/dev/null || return 0

    wait "$COPROC_PROCESS_ID"

    return 0
}
declare -rf coproc::waitForPrevious
