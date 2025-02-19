[[ "$( type -t output::error || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

# »»» Colors ———————————————————————————————————————————————————————————————————

# shellcheck disable=SC2120
function output::bgcolor::green() { # $0 [<text> ...]
    output::colorizeBackground 2 "$@"
}
declare -rf output::bgcolor::green

# shellcheck disable=SC2120
function output::bgcolor::red() { # $0 [<text> ...]
    output::colorizeBackground 1 "$@"
}
declare -rf output::bgcolor::red

function output::bgcolor::reset() { # $0
    escapeSequence::bgcolor
}
declare -rf output::bgcolor::reset

# shellcheck disable=SC2120
function output::bgcolor::yellow() { # $0 [<text> ...]
    output::colorizeBackground 3 "$@"
}
declare -rf output::bgcolor::yellow

function output::color::reset() { # $0
    escapeSequence::color
}
declare -rf output::color::reset

# shellcheck disable=SC2120
function output::color::black() { # $0 [<text> ...]
    output::colorize 0 "$@"
}
declare -rf output::color::black

# shellcheck disable=SC2120
function output::color::blue() { # $0 [<text> ...]
    output::colorize 12 "$@"
}
declare -rf output::color::blue

# shellcheck disable=SC2120
function output::color::green() { # $0 [<text> ...]
    output::colorize 2 "$@"
}
declare -rf output::color::green

# shellcheck disable=SC2120
function output::color::red() { # $0 [<text> ...]
    output::colorize 1 "$@"
}
declare -rf output::color::red

# shellcheck disable=SC2120
function output::color::white() { # $0 [<text> ...]
    output::colorize 7 "$@"
}
declare -rf output::color::white

# shellcheck disable=SC2120
function output::color::yellow() { # $0 [<text> ...]
    output::colorize 3 "$@"
}
declare -rf output::color::yellow

function output::colorize() { # $0 <color-code> [<text> ...]
    local -ri color="$1"

    shift

    local isFirstLine

    if [[ $# -eq 0 ]]
    then
        escapeSequence::color $color

        return 0
    fi

    while [[ $# -gt 0 ]]
    do
        isFirstLine=true
        while IFS= read -r content
        do
            if $isFirstLine
            then
                isFirstLine=false
            else
                printf '\n'
            fi

            escapeSequence::color $color
            printf '%s' "$content"
            escapeSequence::color # reset
        done <<<"${1//\\n/$'\n'}"
        shift
    done
}
declare -rf output::colorize

function output::colorizeBackground() { # $0 <color-code> [<text> ...]
    local -ri color="$1"

    shift

    local isFirstLine

    if [[ $# -eq 0 ]]
    then
        escapeSequence::bgcolor $color

        return 0
    fi

    while [[ $# -gt 0 ]]
    do
        isFirstLine=true
        while IFS= read -r content
        do
            if $isFirstLine
            then
                isFirstLine=false
            else
                printf '\n'
            fi
            escapeSequence::bgcolor $color
            printf '%s' "$content"
            escapeSequence::bgcolor # reset
        done <<<"${1//\\n/$'\n'}"
        shift
    done
}
declare -rf output::colorizeBackground

function output::underline() { # $0 [<text> ...]
    if [[ $# -eq 0 ]]
    then
        escapeSequence::graphic::underline

        return 0
    fi

    while [[ $# -gt 0 ]]
    do
        while IFS= read -r content
        do
            escapeSequence::graphic::underline
            printf '%s' "$content"
            escapeSequence::graphic::underlineReset
            printf '\n'
        done <<<"$1"
        shift
    done
}
declare -rf output::underline

function output::underlineReset() { # $0
    escapeSequence::graphic::underlineReset
}
declare -rf output::underlineReset

# »»» Blocks ———————————————————————————————————————————————————————————————————

function output::block() { # $0 <type> <prefix> <padding> <style> <style-reset> [text ...]
    local    type="$1"
    local -r prefix="$2"
    local -r padding="$3"
    local -r style="$4"
    local -r styleReset="$5"

    shift 5

    local -a messages=()
    local -i lineLength prefixLength currentLineLength
    local -i terminalWidth firstLineIndex messageIndex
    local    message
    local    lineIndentation

    read -r terminalWidth < <( term::getSize | awk '{ print $2 }' )
    ((lineLength = terminalWidth > 120 ? 120 : terminalWidth))
    unset -v terminalWidth

    prefixLength=0
    lineIndentation=
    if [[ -n "$type" ]]
    then
        type="[$type] "
        prefixLength="$( printf '%s' "$type" | wc -m )"
        lineIndentation="$( printf '%-*s' "$prefixLength" ' ' )"
    fi

    prefixLength+="$( escapeSequence::removeAll "$prefix" | wc -m )"
    ((--prefixLength)) || true # removes the end line count

    while [[ $# -gt 0 ]]
    do
        messageIndex=0
        while IFS= read -r message
        do
            messageIndex=1
            messages+=("$message")
        done < <( escapeSequence::removeAll "$1" | fold -sw "$((lineLength - prefixLength))" )

        shift

        if [[ $# -gt 0 && $messageIndex -eq 1 ]]
        then
            # interline
            messages+=('')
        fi
    done

    firstLineIndex=0
    if $padding
    then
        messages=('' "${messages[@]}" '')
        firstLineIndex=1
    fi

    for ((messageIndex=0; messageIndex < ${#messages[@]}; ++messageIndex))
    do
        message="$prefix"
        if [[ -n "$type" ]]
        then
            if [[ $messageIndex -eq $firstLineIndex ]]
            then
                message+="$type"
            else
                message+="$lineIndentation"
            fi
        fi
        message+="${messages[$messageIndex]}"

        # pad right
        currentLineLength="$( escapeSequence::removeAll "$message" | wc -m )"
        ((--currentLineLength)) || true # removes the end line count
        [[ $currentLineLength -ge lineLength ]] || message+="$( printf '%-*s' "$((lineLength - currentLineLength))" " " )"

        printf '%b%s%b'$'\n' "$style" "$message" "$styleReset"
    done
}
declare -rf output::block

function output::caution() { # $0 [<text> ...]
    output::block 'CAUTION' ' ! ' true "$( output::bgcolor::red )$( output::color::white )" "$( output::color::reset )$( output::bgcolor::reset )" "$@"
}
declare -rf output::caution

function output::error() { # $0 [<text> ...]
    output::block 'ERROR' ' ' true "$( output::bgcolor::red )$( output::color::white )" "$( output::color::reset )$( output::bgcolor::reset )" "$@"
}
declare -rf output::error

function output::info() { # $0 [<text> ...]
    output::block 'INFO' ' ' false "$( output::color::green )" "$( output::color::reset )" "$@"
}
declare -rf output::info

function output::note() { # $0 [<text> ...]
    output::block 'NOTE' ' ! ' false "$( output::color::yellow )" "$( output::color::reset )" "$@"
}
declare -rf output::note

function output::success() { # $0 [<text> ...]
    output::block 'SUCCESS' ' ' true "$( output::bgcolor::green )$( output::color::white )" "$( output::color::reset )$( output::bgcolor::reset )" "$@"
}
declare -rf output::success

function output::warning() { # $0 [<text> ...]
    output::block 'WARNING' ' ' true "$( output::bgcolor::yellow )$( output::color::black )" "$( output::color::reset )$( output::bgcolor::reset )" "$@"
}
declare -rf output::warning

# »»» List Item ————————————————————————————————————————————————————————————————

function output::listItem() { # $0 <emote> <pad-length> <style> <style-reset> <text>
    local -r  emote="$1"
    local -ri prefixLength="$2"
    local -r  style="$3"
    local -r  styleReset="$4"
    local -r  text="$5"

    printf '%b' "$style"
    printf '%-*s' "$prefixLength" " "
    printf '%b  ' "$emote"
    # no color handling for now
    printf '%s' "$text"
    printf '%b' "$styleReset"

    printf $'\n'
}
declare -rf output::listItem

function output::listItemError() { # $0 <text> [<pad-length>]
    local -r  text="$1"
    local -ri prefixLength="${2:-2}"

    output::listItem "❌" "$prefixLength" "$( output::color::red )" "$( output::color::reset )" "$text"
}
declare -rf output::listItemError

function output::listItemPending() { # $0 <text> [<pad-length>]
    local -r  text="$1"
    local -ri prefixLength="${2:-2}"

    output::listItem "⏳" "$prefixLength" "$( output::color::blue )" "$( output::color::reset )" "$text"
}
declare -rf output::listItemPending

function output::listItemSuccess() { # $0 <text> [<pad-length>]
    local -r  text="$1"
    local -ri prefixLength="${2:-2}"

    output::listItem "✅" "$prefixLength" "$( output::color::green )" "$( output::color::reset )" "$text"
}
declare -rf output::listItemSuccess

function output::listItemWarning() { # $0 <text> [<pad-length>]
    local -r  text="$1"
    local -ri prefixLength="${2:-2}"

    output::listItem "⚠️" "$prefixLength" "$( output::color::yellow )" "$( output::color::reset )" "$text"
}
declare -rf output::listItemWarning

# »»» Other ————————————————————————————————————————————————————————————————————

function output::cleanPreviousLines() { # $0 [<nb-lines>]
    local -ri lines="${1:-1}"

    local -i index

    for ((index=0; index < lines; ++index))
    do
        escapeSequence::cursor::moveUp
        escapeSequence::cursor::moveToFirstColumn
        escapeSequence::eraseCurrentLine
    done
}
declare -rf output::cleanPreviousLines

function output::link() { # $0 url [text]
    local url="$1"
    local text="${2:-$url}"

    printf '\e]8;;%s\e\\%s\e]8;;\e\\\n' "$url" "$text"
}
declare -rf output::link

function output::listing() { # $0 [text ...]
    while [[ $# -gt 0 ]]
    do
        printf '* %s\n' "$1"
        shift
    done
}
declare -rf output::listing

function output::pad() { # $0 <pad-length> [text ...]
    local -i padLength="${1:-0}"

    shift 1

    local indentationLine content

    indentationLine="$( printf '%-*s' $padLength ' ' )"

    while [[ $# -gt 0 ]]
    do
        while IFS= read -r content
        do
            printf '%s%s\n' "$indentationLine" "$content"
        done <<<"$1"
        shift
    done
}
declare -rf output::pad

function output::pending() { # $0 [<text> ...]
    local content

    while [[ $# -gt 0 ]]
    do
        while IFS= read -r content
        do
            printf '%b%s%b\n' "$( output::color::blue )" "$content" "$( output::color::reset )"
        done <<<"$1"
        shift
    done
}
declare -rf output::pending

function output::pressKeyToContinue() { # $0
    printf 'Press any key to continue'
    read -n 1 -s -r
    printf $'\n'
}
declare -rf output::pressKeyToContinue

function output::section() { # $0 <section-name>
    local -i sectionLength

    output::color::yellow "$1"
    printf $'\n'

    sectionLength="$( printf '%s' "$1" | wc -m )"

    output::color::yellow
    printf '%-*s' "$sectionLength" ' ' | tr ' ' '-'
    output::color::reset
    printf $'\n'
}
declare -rf output::section

function output::showErrorOutputFromFile() { # $0 <file> [<pad-length>]
    local -r file="$1"

    local prefix=
    if [[ $# -gt 1 ]]
    then
        local -ir padLength="$2"
        prefix="$( printf '%-*s' "$padLength" ' ' )"
    fi
    escapeSequence::removeNonColor <"$file" | sed -e "s/^/$prefix$( output::color::red "> " )/"
}
declare -rf output::showErrorOutputFromFile

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
source "$PROJECT_ROOT/lib/term.lib.sh"
