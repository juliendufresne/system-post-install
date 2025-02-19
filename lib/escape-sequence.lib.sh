[[ "$( type -t escapeSequence::bgcolor || true )" != 'function' ]] || return 0

# For a list of escape code:
#    man console_codes
#    or
#    https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797

# ——— Functions definition —————————————————————————————————————————————————————

function escapeSequence::bgcolor() { # $0 [<int-color>]
    if [[ $# -eq 0 ]]
    then
        printf $'\e''[49m'
    else
        printf $'\e''[48;5;%dm' "$1"
    fi
}
declare -rf escapeSequence::bgcolor

function escapeSequence::color() { # $0 [<int-color>]
    if [[ $# -eq 0 ]]
    then
        printf $'\e''[39m'
    else
        printf $'\e''[38;5;%dm' "$1"
    fi
}
declare -rf escapeSequence::color

# output \e[line;colR
function escapeSequence::cursor::getPosition() { # $0
    printf $'\e''[6n'
}
declare -rf escapeSequence::cursor::getPosition

function escapeSequence::cursor::hide() { # $0
    printf $'\e''[?25l'
}
declare -rf escapeSequence::cursor::hide

# moves cursor one line down, first column, but doesn't scroll
function escapeSequence::cursor::moveDown() { # $0
    printf $'\e''[1E'
}
declare -rf escapeSequence::cursor::moveDown

# moves cursor one line up, scrolling if needed
function escapeSequence::cursor::moveUp() { # $0
    printf $'\e''M'
}
declare -rf escapeSequence::cursor::moveUp

function escapeSequence::cursor::moveToColumn() { # $0 <column-number>
    printf $'\e''[%dG' "$1"
}
declare -rf escapeSequence::cursor::moveToColumn

function escapeSequence::cursor::moveToFirstColumn() { # $0
    escapeSequence::cursor::moveToColumn 1
}
declare -rf escapeSequence::cursor::moveToFirstColumn

function escapeSequence::cursor::moveToPosition() { # $0 <line-number> <column-number>
    printf $'\e''[%d;%dH' "$1" "$2"
}
declare -rf escapeSequence::cursor::moveToPosition

function escapeSequence::cursor::visible() { # $0
    printf $'\e''[?25h'
}
declare -rf escapeSequence::cursor::visible

function escapeSequence::eraseCurrentLine() { # $0
    printf $'\e''[2K'
}
declare -rf escapeSequence::eraseCurrentLine

function escapeSequence::graphic::underline() { # $0
    printf $'\e''[4m'
}
declare -rf escapeSequence::graphic::underline

function escapeSequence::graphic::underlineReset() { # $0
    printf $'\e''[24m'
}
declare -rf escapeSequence::graphic::underlineReset

function escapeSequence::removeAll() { # $0 [<text> ...]
    local content

    shopt -s extglob
    if [[ $# -eq 0 ]]
    then
        while IFS= read -r content
        do
            content="${content//$'\e'[M78]/}"
            printf '%b\n' "${content//$'\e'\[*([0-9;?])[a-zA-Z]/}"
        done
    fi

    while [[ $# -gt 0 ]]
    do
        content="${1//$'\e'[M78]/}"
        printf '%b\n' "${content//$'\e'\[*([0-9;?])[a-zA-Z]/}"
        shift
    done
}
declare -rf escapeSequence::removeAll

function escapeSequence::removeNonColor() { # $0 [<text> ...]
    local content

    shopt -s extglob
    if [[ $# -eq 0 ]]
    then
        while IFS= read -r content
        do
            content="${content//$'\e'[M78]/}"
            printf '%b\n' "${content//$'\e'\[*([0-9;?])[a-ln-zA-Z]/}"
        done
    fi

    while [[ $# -gt 0 ]]
    do
        content="${1//$'\e'[M78]/}"
        printf '%b\n' "${content//$'\e'\[*([0-9;?])[a-ln-zA-Z]/}"
        shift
    done
}
declare -rf escapeSequence::removeNonColor

function escapeSequence::scrollingRegion::create() { # $0 <first-line> <last-line>
    local -i firstLine="$1"
    local -i lastLine="$2"

    printf >&2 $'\e''[%d;%dr' $firstLine $lastLine
}
declare -rf escapeSequence::scrollingRegion::create

function escapeSequence::scrollingRegion::reset() { # $0
    printf >&2 $'\e''[r'
}
declare -rf escapeSequence::scrollingRegion::reset
