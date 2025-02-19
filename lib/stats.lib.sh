[[ "$( type -t stats::run || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function stats::_doRun() { # $0 <step-description>
    local -r description="$1"

    if [[ ! -v STATS_DIR ]]
    then
        STATS_DIR="$PROJECT_ROOT/var"
    fi

    if [[ ! -v STATS_SECTION ]]
    then
        STATS_SECTION="${0##*/} $( date -u +'%Y-%m-%d %H:%M:%S' )"
    fi

    [[ -d $STATS_DIR ]] || mkdir "$STATS_DIR"

    export STATS_DIR STATS_SECTION

    sudo::run 'run stats' \
        STATS_DIR="$STATS_DIR" \
        STATS_SECTION="$STATS_SECTION" \
        "$PROJECT_ROOT/libexec/fs-stats" "$description" || true

    log::addMessage "'$description' completed"

    return 0
}
declare -rf stats::_doRun

function stats::run() { # $0 <step-description>
    local -r description="$1"

    if stats::shouldRun
    then
        log::addMessage "'$description' started"
        stats::_doRun "$description"
    fi
}
declare -rf stats::run

function stats::runAsync() { # $0 <step-description>
    local -r description="$1"
    local    process

    stats::shouldRun || return 0

    # validate sudo cache to be able to run asynchronously without password
    sudo::validate 'run stats'

    coproc::waitForPrevious
    # shellcheck disable=SC2034
    coproc process { stats::_doRun "$description"; }

    if [[ -v process_PID ]]
    then
        coproc::register "$process_PID"
        export STATS_RUNNING_PID="$process_PID"
        log::addMessage "'$description' started asynchronously (PID: $STATS_RUNNING_PID)"
    else
        log::addMessage "'$description' started asynchronously"
    fi
}
declare -rf stats::runAsync

function stats::shouldRun() { # $0
    [[ -v WITH_STATS ]] && $WITH_STATS
}
declare -rf stats::shouldRun

function stats::wait() { # $0
    [[ -v STATS_RUNNING_PID ]] || return 0
    ps -p "$STATS_RUNNING_PID" >/dev/null || return 0

    log::addMessage "Waiting on stats script to complete (PID: $STATS_RUNNING_PID)"
    wait "$STATS_RUNNING_PID"

    return 0
}
declare -rf stats::wait

# ——— Dependencies —————————————————————————————————————————————————————————————

if [[ ! -v PROJECT_ROOT ]]
then
    declare -g PROJECT_ROOT
    PROJECT_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
elif [[ $PROJECT_ROOT != "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )" ]]
then
    printf 'Wrong path for PROJECT_ROOT variables. Abort.\n' >&2
    exit 1
fi

source "$PROJECT_ROOT/lib/coproc.lib.sh"
source "$PROJECT_ROOT/lib/log.lib.sh"
source "$PROJECT_ROOT/lib/sudo.lib.sh"
