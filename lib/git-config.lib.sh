[[ "$( type -t gitConfig::get || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function gitConfig::get() { # $0 [-f <file>] [--global] <option>
    local -a fileOptions=() # not handling all options
    local -a extraOptions=() # not handling all options
    local    optionName
    local -i exitCode

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -f|--type)
                if [[ $# -eq 1 ]]
                then
                    output::error "${FUNCNAME[0]}: missing parameter for option '$1'" >&2

                    return 2
                fi
                ;;&
            --global) fileOptions+=("$1"); shift;;
            -f)
                fileOptions+=("$1")
                fileOptions+=("$2")
                shift 2
                ;;
            --type)
                extraOptions+=("$1")
                extraOptions+=("$2")
                shift 2
                ;;
            *) break;;
        esac
    done


    case "$#" in
        1) ;; # normal scenario
        0) output::error "${FUNCNAME[0]}: missing '<option>' argument" >&2; return 2;;
        *) output::error "${FUNCNAME[0]}: unknown argument '$2'" >&2; return 2;;
    esac

    optionName="$1"

    exitCode=0
    gitConfig::hasGetSetCommands || exitCode=$?

    case "$exitCode" in
        5) return $exitCode;; # git is not installed
        0) git config get "${fileOptions[@]}" "${extraOptions[@]}" "$optionName";;
        *) git config "${fileOptions[@]}" "${extraOptions[@]}" "$optionName";;
    esac
}
declare -rf gitConfig::get

function gitConfig::set() { # $0 [-f <file>] [--global] <option> <value>
    local -a fileOptions=() # not handling all options
    local -a extraOptions=() # not handling all options
    local    optionName optionValue
    local -i exitCode

    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -f|--type)
                if [[ $# -eq 1 ]]
                then
                    output::error "${FUNCNAME[0]}: missing parameter for option '$1'" >&2

                    return 2
                fi
                ;;&
            --global) fileOptions+=("$1"); shift;;
            -f)
                fileOptions+=("$1")
                fileOptions+=("$2")
                shift 2
                ;;
            --type)
                extraOptions+=("$1")
                extraOptions+=("$2")
                shift 2
                ;;
            *) break;;
        esac
    done

    case "$#" in
        2) ;; # normal scenario
        0) output::error "${FUNCNAME[0]}: missing '<option>' argument" >&2; return 2;;
        1) output::error "${FUNCNAME[0]}: missing '<value>' argument" >&2; return 2;;
        *) output::error "${FUNCNAME[0]}: unknown argument '$3'" >&2; return 2;;
    esac

    optionName="$1"
    optionValue="$2"

    exitCode=0
    gitConfig::hasGetSetCommands || exitCode=$?

    case "$exitCode" in
        5) return $exitCode;; # git is not installed
        0) git config set "${fileOptions[@]}" "${extraOptions[@]}" "$optionName" "$optionValue";;
        *) git config "${fileOptions[@]}" "${extraOptions[@]}" "$optionName" "$optionValue";;
    esac
}
declare -rf gitConfig::set

function gitConfig::hasGetSetCommands() {
    local versionText major minor bugfix

    if ! command -v git &>/dev/null
    then
        output::error 'git-config: git is not installed' >&2

        return 5
    fi

    versionText="$( git --version )"
    versionText="${versionText/git version /}"

    # shellcheck disable=SC2034
    IFS='.' read -r major minor bugfix <<<"$versionText"

    [[ $major -gt 2 || ( $major -eq 2 && $minor -ge 46 ) ]]
}
declare -rf gitConfig::hasGetSetCommands

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
