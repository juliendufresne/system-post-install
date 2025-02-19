[[ "$( type -t installSimplePackage || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function installSimplePackage() { # $0 <software-name> [<packages> ...]
    local -r softwareName="$1"

    shift 1

    local -i exitCode
    local    output
    local -a packages=()
    local    packageWord

    while [[ $# -gt 0 ]]
    do
        packages+=("$1")
        shift
    done

    packageWord='package'
    case ${#packages[@]} in
        0) packages+=("$softwareName") ;;
        1) ;;
        *) packageWord='packages'
    esac

    log::addMessage "install $softwareName"

    output::pending "installing $packageWord"
    log::addMessage "installing $packageWord"

    scrollingRegion::create --full-window 5

    exitCode=0
    output="$( mktemp )"
    packageManager::install "install $softwareName" "${packages[@]}" |& tee "$output" || exitCode=$?

    scrollingRegion::restore
    output::cleanPreviousLines 1

    if [[ $exitCode -ne 0 ]]
    then
        output::error "failed to install $softwareName"
        log::addMessage "failed to install $softwareName"

        output::showErrorOutputFromFile "$output" >&2
        log::addFile "$output"
    else
        output::success "$softwareName installation completed"
        log::addMessage "$softwareName installation completed"
    fi

    rm "$output"

    return $exitCode
}
declare -rf installSimplePackage

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
