[[ "$( type -t sudo::run || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function sudo::run() { # $0 <sudo-message> [<var>=<value> ...] [<command> [<command-options ...]]
    local -r messageIfPasswordRequired="$1"

    local -i exitCode

    shift 1
    : "${USER:="$( whoami )"}"

    if [[ $USER == root ]]
    then
        # case: sudo::run "" MYVAR=1 run-this
        while [[ $# -gt 0 && $1 == *=* ]]
        do
            declare "$1"
            shift 1
        done

        exitCode=0
        if [[ $# -gt 0 ]]
        then
            "$@"
            exitCode=$?
        fi

        return $exitCode
    fi

    if ! command -v sudo &>/dev/null
    then
        output::error "Trying to run command '$*' that requires root privileges but sudo is not installed and you're not root"

        return 1
    fi

    exitCode=0

    sudo::validate "$messageIfPasswordRequired" || exitCode=$?

    if [[ $exitCode -ne 0 ]]
    then
        output::error >&2 'Authentication failed.'

        return $exitCode
    fi

    sudo "$@" || exitCode=$?

    return $exitCode
}
declare -rf sudo::run

function sudo::validate() { # $0 <sudo-message>
    local -r messageIfPasswordRequired="$1"

    local -r bashOptions="$-"
    local -i exitCode

    : "${USER:="$( whoami )"}"

    [[ $USER != root ]] || return 0

    if ! command -v sudo &>/dev/null
    then
        output::error 'Non-root users need sudo package to be installed first.' >&2

        return 1
    fi

    # no password required (or password cache is valid)
    if sudo -n true &>/dev/null
    then
        return 0
    fi

    set +x
    output::note "Your linux account password is required to $messageIfPasswordRequired." >&2

    scrollingRegion::create --full-window --header-min-height 1 3

    exitCode=0

    # ask for sudo password
    sudo --validate || exitCode=$?

    scrollingRegion::restore
    # remove 'Your linux account ...'
    output::cleanPreviousLines 1
    set "-$bashOptions"

    return $exitCode
}
declare -rf sudo::validate

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

source "$PROJECT_ROOT/lib/output.lib.sh"
source "$PROJECT_ROOT/lib/scrolling-region.lib.sh"
