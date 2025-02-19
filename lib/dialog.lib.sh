[[ "$( type -t dialog::whiptail || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function dialog::ask() { # $0 <title> <question> [<default>]
    local -r title="$1"
    local -r question="$2"
    local -r default="${3:-}"

    local -i minWidth=0
    local -a windowOptions=()
    local -i height width

    # min width depends on the default value
    ((minWidth = ${#default} > 0 ? ${#default} + 10 : 30))
    # space required for the box itself
    ((minWidth += 4))

    read -r height width < <( dialog::ensureWindowIsDisplayable "$question" 1 $minWidth )

    if [[ -n $title ]]
    then
        windowOptions+=('--title')
        windowOptions+=("$title")
    fi

    dialog::whiptail --separate-output \
            "${windowOptions[@]}" \
            --inputbox "$question" \
            $height $width "$default" 3>&1 1>&2 2>&3 || return $?

    return 0
}
declare -rf dialog::ask

function dialog::askPass() { # $0 <title> <question> [<input-size>]
    local -r  title="$1"
    local -r  question="$2"
    local -ri inputMinSize="${3:-30}"

    local -a  windowOptions=()
    local -i  height width

    read -r height width < <( dialog::ensureWindowIsDisplayable "$question" 1 $inputMinSize )

    if [[ -n $title ]]
    then
        windowOptions+=('--title')
        windowOptions+=("$title")
    fi

    dialog::whiptail --separate-output \
            "${windowOptions[@]}" \
            --passwordbox "$question" \
            $height $width 3>&1 1>&2 2>&3 || return $?

    return 0
}
declare -rf dialog::askPass

function dialog::checklistMenu() { # $0 <title> <text> [<tag1> <item1> <status>] ...
    local -r title="$1"
    local -r text="$2"
    shift 2

    local -a windowOptions=('--separate-output')

    dialog::ensureWindowIsDisplayable "" 5 60 >/dev/null

    if [[ -n $title ]]
    then
        windowOptions+=('--title')
        windowOptions+=("$title")
    fi

    windowOptions+=('--checklist')
    windowOptions+=("$text")


    dialog::whiptail "${windowOptions[@]}" \
            0 0 0 \
            "$@" 3>&1 1>&2 2>&3 || return $?

    return 0
}
declare -rf dialog::checklistMenu

# @internal
function dialog::computeRequiredWindowSize() { # $0 <text> [<extra-height>] [<min-width>]
    local -r text="$1"
    # extra height required for the box itself (ex: inputbox, passwordbox, ...)
    local -i extraHeight="${2:-0}"
    # ensure that an input/password box has enough space to write
    local -i minWidth="${3:-0}"

    local -i height width maxWidth
    local -i terminalHeight terminalWidth

    read -r terminalHeight terminalWidth < <( term::getSize )

    ((maxWidth = terminalWidth - 4))

    # minimum height to display a box with no content
    height=5
    # extra height required for the box itself (ex: inputbox, passwordbox, ...)
    ((height += extraHeight))

    width=$minWidth

    [[ $maxWidth -ge $minWidth ]] || ((maxWidth = minWidth))

    while IFS= read -r line
    do
        ((++height))
        if [[ ${#line} -gt $width ]]
        then
            width=${#line}
        fi
    done < <( fold -sw $maxWidth <<<"${text//\\n/$'\n'}" )

    printf '%d %d\n' $height $width
}
declare -rf dialog::computeRequiredWindowSize

function dialog::confirm() { # $0 <title> <question> [<default-answer>]
    local -r title="$1"
    local -r question="$2"
    local -r default="${3:-true}"
    local -a windowOptions=()

    dialog::ensureWindowIsDisplayable "$question" >/dev/null

    $default || windowOptions+=('--defaultno')
    if [[ -n $title ]]
    then
        windowOptions+=('--title')
        windowOptions+=("$title")
    fi

    dialog::whiptail "${windowOptions[@]}" --yesno "$question" 0 0
}
declare -rf dialog::confirm

# @internal
function dialog::ensureWindowIsDisplayable() { # $0 [<text>] [<extra-height>] [<min-width>]
    local -r text="${1:-}"
    local -i extraHeight="${2:-0}"
    local -i minWidth="${3:-0}"

    local -i requiredHeight requiredWidth
    local -i terminalHeight terminalWidth
    local -i maxAutoRecomputeTimes=600
    local -i autoRecomputeTimes=0

    while true
    do
        read -r requiredHeight requiredWidth < \
            <( dialog::computeRequiredWindowSize "$text" $extraHeight $minWidth )
        read -r terminalHeight terminalWidth < <( term::getSize )

        [[ $terminalHeight -lt $requiredHeight || $terminalWidth -lt $requiredWidth ]] || break

        # be smart: auto recompute for a period of time and if it still isn't
        #           enough then stop computing and ask for a user input to limit
        #           CPU usage.

        if [[ $autoRecomputeTimes -eq 0 ]]
        then
            output::color::yellow 'Screen or window too small. Please resize or abort.\n' >&2
        elif [[ $autoRecomputeTimes -eq $maxAutoRecomputeTimes ]]
        then
            autoRecomputeTimes=0
            output::pressKeyToContinue
            continue
        fi

        ((++autoRecomputeTimes))
        sleep 0.1
    done

    printf '%d %d\n' $requiredHeight $requiredWidth
}
declare -rf dialog::ensureWindowIsDisplayable

function dialog::hasDialogRequirements() { # $0
    command -v whiptail &>/dev/null
}
declare -rf dialog::hasDialogRequirements

function dialog::installDialogBox() { # $0
    local -i exitCode=0
    local    output

    ! dialog::hasDialogRequirements || return 0

    output::info 'Installing a dialog box'
    log::addMessage 'dialog box not found; installing'

    output="$( mktemp )"
    scrollingRegion::create --full-window --header-min-height 1 5
    packageManager::install 'install a dialog box' whiptail |& tee "$output" || exitCode=$?
    scrollingRegion::restore

    output::cleanPreviousLines 1
    if [[ $exitCode -ne 0 ]]
    then
        output::error 'failed to install a dialog box'
        log::addMessage 'failed to install a dialog box'

        output::showErrorOutputFromFile "$output" >&2
        log::addFile "$output"
    else
        log::addMessage 'dialog box installed'
    fi

    rm "$output"

    return $exitCode
}
declare -rf dialog::installDialogBox

function dialog::menu() { # $0 <title> <question> [<tag1> <menu1>]...
    local -r title="$1"
    local -r question="$2"

    shift 2

    local -a windowOptions=('--separate-output')

    dialog::ensureWindowIsDisplayable "$question" >/dev/null

    if [[ -n $title ]]
    then
        windowOptions+=('--title')
        windowOptions+=("$title")
    fi

    dialog::whiptail "${windowOptions[@]}" --menu "$question" 0 0 0 "$@" 3>&1 1>&2 2>&3 || return $?

    return 0
}
declare -rf dialog::menu

# @internal
function dialog::whiptail() { # $0 [<windowOptions> ...]
    local -i exitCode=0
    local    output

    if ! dialog::hasDialogRequirements
    then
        output="$( mktemp )"
        dialog::installDialogBox &>"$output" || exitCode=$?

        [[ $exitCode -eq 0 ]] || output::showErrorOutputFromFile "$output" >&2
        rm "$output"
        [[ $exitCode -eq 0 ]] || return $exitCode
    fi

    whiptail "$@" || exitCode=$?

    return $exitCode
}
declare -rf dialog::whiptail

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

source "$PROJECT_ROOT/lib/log.lib.sh"
source "$PROJECT_ROOT/lib/output.lib.sh"
source "$PROJECT_ROOT/lib/package-manager.lib.sh"
source "$PROJECT_ROOT/lib/scrolling-region.lib.sh"
source "$PROJECT_ROOT/lib/term.lib.sh"
