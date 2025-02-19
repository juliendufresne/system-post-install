[[ "$( type -t softwareParseOpt || true )" != 'function' ]] || return 0

declare -gi LIST_ITEM_INDENT=2
declare -g  USE_DEFAULT=false # semi interactive mode

# ——— Functions definition —————————————————————————————————————————————————————

function softwareParseOpt() {
    while [[ $# -gt 0 ]]
    do
        case "$1" in
            --indent)
                if [[ $# -eq 1 ]]
                then
                    output::error "${0##*/}: missing parameter for option '$1'" >&2

                    return 2
                fi
                LIST_ITEM_INDENT="$2"
                shift 2
                ;;
            --default) USE_DEFAULT=true; shift;;
            -*) output::error "${0##*/}: unknown option '$1'" >&2; return 2;;
            *)  output::error "${0##*/}: unknown argument '$1'" >&2; return 2;;
        esac
    done

    export LIST_ITEM_INDENT USE_DEFAULT
}
declare -rf softwareParseOpt

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
