[[ "$( type -t download::get || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function download::get() { # $0 <url> [<output-file>]
    local -r url="$1"
    local -r file="${2:--}"

    local -r directory="${file%/*}"
    local -i exitCode=0
    local    isNewFile=true

    log::addMessage "try to download url '$url' to file '$file'"

    download::installDownloader || return $?

    # create sub dir if necessary.
    # Directory is file when downloading to current dir.
    if [[ $directory != "$file" && ! -d $directory ]]
    then
        log::addMessage "create missing directory '$directory'"
        if ! mkdir -p "$directory"
        then
            log::addMessage "failed creating missing directory '$directory'"
            output::error "Could not create directory '$directory' to download '$url'."

            return 1
        fi
    fi

    if [[ $file != '-' && -f $file ]]
    then
        isNewFile=false
    fi

    if command -v curl &>/dev/null
    then
        log::addMessage 'using curl'
        curl -fsSLo "$file" "$url" 2> "$( log::getLogFile )" || exitCode=$?
    else
        log::addMessage 'using wget'
        wget --no-verbose -O "$file" "$url" 2> "$( log::getLogFile )" || exitCode=$?
    fi

    if [[ $exitCode -ne 0 ]]
    then
        output::error "Failed to download file '$url'"
        log::addMessage "Failed to download file '$url' (exit code: '$exitCode')"
        if $isNewFile && [[ -f "$file" ]]
        then
            rm "$file"
        fi
    fi

    return $exitCode
}
declare -rf download::get

function download::hasDownloaderRequirements() { # $0
    packageManager::isInstalled ca-certificates || return 1

    command -v curl &>/dev/null || command -v wget &>/dev/null
}
declare -rf download::hasDownloaderRequirements

function download::installDownloader() { # $0
    local -i exitCode=0
    local -a packages=()

    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null
    then
        packages+=('curl')
    fi

    if ! packageManager::isInstalled ca-certificates
    then
        packages+=('ca-certificates')
    fi

    [[ ${#packages[@]} -gt 0 ]] || return 0

    output::info 'Installing a downloader tool'
    log::addMessage "missing downloader tool package(s) ${packages[*]}"

    packageManager::install "install a downloader tool" "${packages[@]}" || exitCode=$?

    if [[ $exitCode -ne 0 ]]
    then
        output::error 'Failed to install a downloader tool'
        log::addMessage 'failed to install a downloader tool'
    fi

    return $exitCode
}
declare -rf download::installDownloader

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
