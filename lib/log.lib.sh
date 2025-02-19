[[ "$( type -t log::addMessage || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function log::addMessage() { # $0 <text>
    local -r message="$1"

    log::defineLogVar

    if [[ ! -v CALLER ]]
    then
        local CALLER="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]};${FUNCNAME[1]}"
    fi

    # timestamp
    # date
    # script-file
    # calling-file:calling-line-number
    # calling-function
    # message
    {
        log::printDate
        printf ';'
        log::printCorrelationId
        printf ';'
        printf '%s;' "${BASH_SOURCE[-1]##*/}"
        printf '%s;' "$CALLER"
        escapeSequence::removeAll "$message"
#        printf '\n'
    } >>"$LOG_FILE"
}
declare -rf log::addMessage

function log::addFile() { # $0 [<file> ...]
    local content

    while [[ $# -gt 0 ]]
    do
        log::addMessage "Content of file '$1'"
        while IFS= read -r content
        do
            log::addMessage "$content"
        done <"$1"
        shift
    done
}
declare -rf log::addFile

# @internal
function log::defineLogVar() { # $0
    if [[ ! -v LOG_FILE ]]
    then
        local filename projectRootDir

        filename="$( realpath "$0" )"

        projectRootDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

        filename="${filename//$projectRootDir\//}"
        filename="${filename//\//-}"
        filename="${filename%%.*}"
        declare -g LOG_FILE
        LOG_FILE="$projectRootDir/var/log/$filename.log"
        export LOG_FILE

        if [[ ! -d "${LOG_FILE%/*}" ]] && ! mkdir -p "${LOG_FILE%/*}"
        then
            output::error "Unable to create log dir ${LOG_FILE%/*}"

            return 1
        fi
    fi
}
declare -rf log::defineLogVar

function log::getLogFile() { # $0
    log::defineLogVar

    printf '%s\n' "$LOG_FILE"
}
declare -rf log::getLogFile

function log::printCorrelationId() { # $0
    if [[ ! -v LOG_CORRELATION_ID ]]
    then
        declare -g LOG_CORRELATION_ID
        # generates a better unique correlation id if tools are (unlikely) present
        if command -v openssl &>/dev/null && command -v xxd &>/dev/null && command -v base32 &>/dev/null
        then
            printf -v LOG_CORRELATION_ID '%010X%s' "$(($( date -u +%s ) * 1000))" "$( openssl rand -out /dev/stdout -hex 10 | xxd -r -p | base32 | tr -d '=' | head -c 16 )"
        else
            LOG_CORRELATION_ID="$( mktemp -u XXXXXXXXXXXX )"
        fi
        # is this necessary?
        export LOG_CORRELATION_ID
    fi

    printf '%s' "$LOG_CORRELATION_ID"
}
declare -rf log::printCorrelationId

function log::printDate() { # $0
    printf '%s' "$( date -u +'%s;%Y-%m-%d %H:%M:%S' )"
}
declare -rf log::printDate

function log::tee() { # $0 [<bool-silenced>]
    local -r isQuiet="${1:-false}"

    local content
    local opt="$-"

    set +x
    if [[ -p /dev/stdin ]]
    then
        CALLER="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]};${FUNCNAME[1]}"
        export CALLER
        while IFS= read -r content
        do
            $isQuiet || printf >&2 '%b\n' "$content"
            log::addMessage "$content"
        done
        unset -v CALLER
    fi

    set "-$opt"
}
declare -rf log::tee

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

source "$PROJECT_ROOT/lib/escape-sequence.lib.sh"
source "$PROJECT_ROOT/lib/output.lib.sh"
