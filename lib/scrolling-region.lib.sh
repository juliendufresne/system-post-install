[[ "$( type -t scrollingRegion::create || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function scrollingRegion::create() { # $0 [--full-window] [--max] [--header-min-height <height>] [<height>]
    local -i requestedHeight=1
    local -i headerMinHeight=1
    # window is the outside scope: could be the entire terminal or
    # another scrolling region
    local -i windowFirstLine windowLastLine
    local -i regionFirstLine regionLastLine regionHeight
    local    fullWindow takeAllSpace
    local -a options=()
    local    interactiveChoice
    local -a cursorPosition
    local -i currentLine

    takeAllSpace=false
    fullWindow=false
    while [[ $# -gt 0 ]]
    do
        options+=("$1")
        case "$1" in
            --full-window) # reach the end of the window/outer-region even if requiredHeight is shorter
                fullWindow=true
                shift
                ;;
            --max) # one step further: move the window to leave only headerMinHeight lines at the top
                takeAllSpace=true
                fullWindow=true
                shift
                ;;
            --header-min-height)
                if [[ $# -eq 1 ]]
                then
                    output::error "${FUNCNAME[0]}: --max-height require a parameter." >&2
                    scrollingRegion::create::usage "${FUNCNAME[0]}" >&2
                    # developer error => exit
                    exit 1
                fi
                headerMinHeight="$2"
                # window requires at least 1 line out of scroll region
                ((headerMinHeight = headerMinHeight < 1 ? 1 : headerMinHeight))
                options+=("$2")
                shift 2
                ;;
            *)
                requestedHeight=$1
                shift
                ;;
        esac
    done

    # »»» get window ———————————————————————————————————————————————————————————

    log::addMessage "called with options = ${options[*]}"

    escapeSequence::cursor::hide
    if [[ -v SCROLLING_REGION && -n ${SCROLLING_REGION##*|} ]] # outer region
    then
        term::getCursorPosition cursorPosition
        escapeSequence::scrollingRegion::reset
        escapeSequence::cursor::moveToPosition "${cursorPosition[0]}" "${cursorPosition[1]}"

        IFS=';' read -r windowFirstLine windowLastLine <<<"${SCROLLING_REGION##*|}"
        log::addMessage "found an outer region; windowFirstLine = $windowFirstLine ; windowLastLine = $windowLastLine"
    else
        log::addMessage 'full terminal mode'
        SCROLLING_REGION=
        while true
        do
            windowFirstLine=1
            read -rd ' ' windowLastLine < <( term::getSize )
            log::addMessage "terminal height = $windowLastLine"
            log::addMessage "enough space? requestedHeight = $requestedHeight ; windowLastLine = $windowLastLine ; headerMinHeight = $headerMinHeight"
            # do we have enough space?
            ((requestedHeight + headerMinHeight > windowLastLine)) || break # this is counter-intuitive
            log::addMessage 'not enough space'

            [[ -t 0 ]] || break # non interactive => we force no scroll region

            # interactive mode => we can ask the user what he/she wants

            {
                output::color::yellow
                printf 'Screen or window too small (%d lines). Please resize. Need at least %d lines.' \
                    "$windowLastLine" "$((requestedHeight + headerMinHeight))"
                output::color::reset
                printf '\n'

                output::color::green 'force'
                printf ' to continue without resizing or press '
                output::color::green '[ENTER]'
                printf ' when you resized.\n'
            } >&2

            read -r interactiveChoice

            [[ $interactiveChoice != 'force' ]] || break
        done
    fi
    unset -v interactiveChoice

    # »»» enough space? ————————————————————————————————————————————————————————

    if ! ((requestedHeight + headerMinHeight < windowLastLine - windowFirstLine + 1))
    then
        # not enough space and resizing terminal would not change anything
        # => log + duplicate outer region
        log::addMessage "not enough space to create inner region '${options[*]}. Duplicating outer region"
        SCROLLING_REGION+="|$windowFirstLine;$windowLastLine"
        term::getCursorPosition cursorPosition
        escapeSequence::scrollingRegion::create $windowFirstLine $windowLastLine
        escapeSequence::cursor::moveToPosition "${cursorPosition[0]}" "${cursorPosition[1]}"
        escapeSequence::cursor::visible

        return 0
    fi

    # »»» move cursor to beginning of line —————————————————————————————————————

    # get cursor current position
    term::getCursorPosition cursorPosition
    log::addMessage "cursorPosition = ${cursorPosition[*]}"
    # let's be kind, cursor is not on a fresh line so let's move it there.
    if [[ ${cursorPosition[1]} -gt 1 ]]
    then
        if [[ ${cursorPosition[0]} -eq $windowLastLine ]]
        then
            # reached the bottom of window, we will stay on the same
            # terminal line but the terminal/outer region has moved
            printf '\n'
        else
            # move to next line
            escapeSequence::cursor::moveDown
            ((++cursorPosition[0]))
        fi
    fi
    escapeSequence::cursor::moveToFirstColumn

    # »»» find new region last line ————————————————————————————————————————————

    # move (and clear) to the bottom of windowLastLine, computing the lines taken
    regionLastLine=${cursorPosition[0]}
    regionHeight=1
    escapeSequence::eraseCurrentLine
    for ((currentLine=cursorPosition[0] + 1; currentLine <= windowLastLine; ++currentLine))
    do
        if [[ $regionHeight -eq $requestedHeight ]]
        then
            if ! $fullWindow
            then
                log::addMessage 'reached requestedHeight and not full window mode. stop'
                break
            fi
            log::addMessage 'reached requestedHeight'
        fi
        escapeSequence::cursor::moveDown
        escapeSequence::eraseCurrentLine
        ((++regionHeight))
        ((++regionLastLine))

        log::addMessage "moved down. regionHeight = $regionHeight ; regionLastLine = $regionLastLine"
    done

    # »»» moving window to ensure requestedHeight lines ————————————————————————

    # we reached the end of the terminal/window. Scrolling one line at a time
    while [[ $regionHeight -lt $requestedHeight ]]
    do
        log::addMessage 'need more space than the window gave us willingly. Moving one line further.'
        printf '\n'
        escapeSequence::eraseCurrentLine
        ((++regionHeight))
    done

    log::addMessage "regionLastLine = $regionLastLine"
    ((regionFirstLine=regionLastLine - regionHeight + 1)) || true
    log::addMessage "regionFirstLine = $regionFirstLine"

    # we have the right regionHeight. Do we need to go further?
    while $takeAllSpace && ((regionHeight + headerMinHeight < windowLastLine - windowFirstLine + 1))
    do
        printf '\n'
        escapeSequence::eraseCurrentLine
        ((++regionHeight))
        ((--regionFirstLine)) || true
        log::addMessage "take all the space possible. regionFirstLine = $regionFirstLine ; regionHeight = $regionHeight ; headerMinHeight = $headerMinHeight ; windowFirstLine = $windowFirstLine ; windowLastLine = $windowLastLine"
    done

    # define the region
    escapeSequence::scrollingRegion::create $regionFirstLine $regionLastLine
    # move to first line of the new region
    escapeSequence::cursor::moveToPosition $regionFirstLine 0
    escapeSequence::cursor::visible

    log::addMessage "defining the new region. regionFirstLine = $regionFirstLine ; regionLastLine = $regionLastLine"

    SCROLLING_REGION+="|$regionFirstLine;$regionLastLine"
    log::addMessage "list of scrolling regions: $SCROLLING_REGION"

    return 0
}
declare -rf scrollingRegion::create

function scrollingRegion::create::usage() { # $0 <function-name>
    local -r functionName="$1"

    printf 'usage: '
    output::color::green "$functionName"
    printf ' ['
    output::color::yellow '--full-window'
    printf '] ['
    output::color::yellow '--max'
    printf '] ['
    output::color::yellow "--header-min-height $( output::underline "<height>")"
    printf '] ['
    output::color::yellow '<height>'
    printf ']\n'
}
declare -rf scrollingRegion::create::usage

function scrollingRegion::restore() { # $0
    local -i beginRegionLine endRegionLine line
    local -i previousRegionBeginLine previousRegionEndLine line
    local    currentRegion

    if [[ ! -v SCROLLING_REGION ]]
    then
        output::error 'You must start a scrolling region before restoring it.' >&2

        return 1
    fi
    currentRegion="${SCROLLING_REGION##*|}"
    SCROLLING_REGION="${SCROLLING_REGION%|*}"

    log::addMessage "currentRegion = $currentRegion ; SCROLLING_REGION = $SCROLLING_REGION"

    IFS=';' read -r beginRegionLine endRegionLine <<<"$currentRegion"

    escapeSequence::cursor::hide
    # Clears the entire region and
    # position the cursor to the beginning of the region
    for ((line=endRegionLine; line >= beginRegionLine; --line))
    do
        escapeSequence::cursor::moveToPosition "$line" 0
        escapeSequence::eraseCurrentLine
    done

    log::addMessage 'reset'
    escapeSequence::scrollingRegion::reset
    if [[ -n $SCROLLING_REGION ]]
    then
        IFS=';' read -r previousRegionBeginLine previousRegionEndLine <<<"${SCROLLING_REGION##*|}"
        escapeSequence::scrollingRegion::create "$previousRegionBeginLine" "$previousRegionEndLine"
        log::addMessage "recreate previous region (previousRegionBeginLine = $previousRegionBeginLine, previousRegionEndLine = $previousRegionEndLine)"
    fi
    escapeSequence::cursor::moveToPosition "$beginRegionLine" 0
    escapeSequence::cursor::visible
}
declare -rf scrollingRegion::restore

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
source "$PROJECT_ROOT/lib/log.lib.sh"
source "$PROJECT_ROOT/lib/output.lib.sh"

# format "|begin:end|begin:end"
declare -g SCROLLING_REGION

export SCROLLING_REGION
