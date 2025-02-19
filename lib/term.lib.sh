[[ "$( type -t term::getCursorPosition || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

declare -g TERM_SIZE
TERM_SIZE="$( stty size )"

# $0 var_name => var_name[0]=line; var_name[1]=col
# note: lines start at 1, columns at 1
function term::getCursorPosition() { # $0
    local -n _pos="$1"

    local oldStty

    exec < /dev/tty
    oldStty=$( stty -g )
    stty raw -echo min 0
    # escape sequence to get cursor current position
    # output \e[line;colR
    escapeSequence::cursor::getPosition > /dev/tty
    IFS=';' read -r -d R -a _pos
    stty "$oldStty"

    # line, strip off the \e[
    _pos[0]=${_pos[0]:2}
}
declare -rf term::getCursorPosition

function term::getSize() { # $0
    local -i lines columns
    local -i knowLines knownColumns

    [[ -v TERM_SIZE ]] || TERM_SIZE='-1 -1'

    read -r lines columns < <( stty size )
    read -r knowLines knownColumns <<<"$TERM_SIZE"

    if [[ $lines -ne $knowLines || $columns -ne $knownColumns ]]
    then
        # bugfix: stabilize term in case a window like whiptail got call before
        #         whiptail is known for changing the size of the terminal
        #         without the user resizing it.
        #         doing less than a second wasn't enough in my tests
        sleep 1
        # trust this new value
        TERM_SIZE="$( stty size )"
    fi

    export TERM_SIZE

    printf '%s\n' "$TERM_SIZE"

    return 0
}
declare -rf term::getSize

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
