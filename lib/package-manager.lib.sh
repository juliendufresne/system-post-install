[[ "$( type -t packageManager::install || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function packageManager::clean() { # $0 <sudo-message>
    local -r requirePasswordWarningMessage="$1"

    local -i exitCode=0

    log::addMessage 'auto-remove apt packages'
    sudo::run "$requirePasswordWarningMessage" \
        DEBIAN_FRONTEND=noninteractive \
        apt-get \
            -y -q \
            --purge \
            autoremove |& log::tee true || exitCode=$?

    if [[ $exitCode -ne 0 ]]
    then
        log::addMessage "auto-remove apt packages failed (exit code '$exitCode')"

        return $exitCode
    fi
    log::addMessage 'auto-remove apt packages complete'

    log::addMessage 'cleaning apt packages'
    sudo::run "$requirePasswordWarningMessage" \
        DEBIAN_FRONTEND=noninteractive \
        apt-get \
            -y -q \
            clean |& log::tee true || exitCode=$?

    if [[ $exitCode -ne 0 ]]
    then
        log::addMessage "cleaning apt packages failed (exit code '$exitCode')"

        return $exitCode
    fi
    log::addMessage 'cleaning apt packages complete'

    return $exitCode
}
declare -rf packageManager::clean

function packageManager::install() { # $0 <sudo-message> [<package> ...]
    local    requirePasswordWarningMessage="$1"

    shift

    local -i exitCode=0
    local -a packages=()

    log::addMessage "${FUNCNAME[0]} $*"

    if [[ $# -eq 0 ]]
    then
        output::error "${FUNCNAME[0]}: missing package" >&2

        return 2
    fi

    for package in "$@"
    do
        if packageManager::isInstalled "$package"
        then
            log::addMessage "deselect package '$package' for installation as it's already installed"
            continue
        fi
        log::addMessage "select package '$package' for installation"
        packages+=("$package")
    done

    if [[ ${#packages[@]} -eq 0 ]]
    then
        log::addMessage 'no packages to install'

        return 0
    fi

    log::addMessage "installing packages '${packages[*]}'"

    sudo::run "$requirePasswordWarningMessage" \
        DEBIAN_FRONTEND=noninteractive \
        apt-get \
            -y -q \
            --no-install-recommends \
            --auto-remove \
            --update \
            install "${packages[@]}" |& log::tee || exitCode=$?

    if [[ $exitCode -ne 0 ]]
    then
        log::addMessage "installing packages '${packages[*]}' failed (exit code '$exitCode')"

        return $exitCode
    fi
    log::addMessage "installing packages '${packages[*]}' completed"

    packageManager::clean "$requirePasswordWarningMessage" || exitCode=$?

    return $exitCode
}
declare -rf packageManager::install

function packageManager::installRepository() { # $0 [--key-id <key>] [--key-url <url>] [--components <components>] [--suites <suites>] <package-name> <uri>
    local components suites
    local uri keyId keyURL keyring withKey=false
    local buildDir packageName requirePasswordWarningMessage
    local -i exitCode=0

    log::addMessage "${FUNCNAME[0]} $*"
    while [[ $# -gt 0 ]]
    do
        case "$1" in
            --key-id)
                if [[ $# -eq 1 ]]
                then
                    output::error "${FUNCNAME[0]}: missing required parameter for $1" >&2
                    packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

                    return 2
                fi
                if [[ -v keyURL ]]
                then
                    output::error "${FUNCNAME[0]}: conflict argument --key-url and $1" >&2
                    packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

                    return 2
                fi
                keyId="$2"
                withKey=true

                shift 2
                ;;
            --key-url)
                if [[ $# -eq 1 ]]
                then
                    output::error "${FUNCNAME[0]}: missing required parameter for $1" >&2
                    packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

                    return 2
                fi
                if [[ -v keyId ]]
                then
                    output::error "${FUNCNAME[0]}: conflict argument --key-id and $1" >&2
                    packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

                    return 2
                fi

                keyURL="$2"
                withKey=true

                shift 2
                ;;
            --components)
                if [[ $# -eq 1 ]]
                then
                    output::error "${FUNCNAME[0]}: missing required parameter for $1" >&2
                    packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

                    return 2
                fi
                components="$2"

                shift 2
                ;;
            --suites)
                if [[ $# -eq 1 ]]
                then
                    output::error "${FUNCNAME[0]}: missing required parameter for $1" >&2
                    packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

                    return 2
                fi
                suites="$2"

                shift 2
                ;;
            *)
                if [[ ! -v packageName ]]
                then
                    packageName="$1"
                elif [[ ! -v uri ]]
                then
                    uri="$1"
                else
                    output::error "${FUNCNAME[0]}: unknown argument '$1'" >&2
                    packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

                    return 2
                fi
                shift
                ;;
        esac
    done

    if [[ ! -v packageName ]]
    then
        log::addMessage 'missing package name'
        output::error "${FUNCNAME[0]}: missing package name" >&2
        packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

        return 2
    fi

    if [[ ! -v uri ]]
    then
        log::addMessage 'missing uri'
        output::error "${FUNCNAME[0]}: missing uri" >&2
        packageManager::installRepository::usage "${FUNCNAME[0]}" >&2

        return 2
    fi

    requirePasswordWarningMessage="install $packageName repository"

    if $withKey
    then
        log::addMessage 'preparing gpg key install'
        packageManager::install "$requirePasswordWarningMessage" gpg dirmngr gpg-agent ca-certificates || return $?
        keyring="/etc/apt/keyrings/$packageName.gpg"

        if [[ ! -d /etc/apt/keyrings ]]
        then
            sudo::run "$requirePasswordWarningMessage" \
                install -m 0755 -d "/etc/apt/keyrings" || return $?
        fi

        if [[ -v keyId && -n "$keyId" ]]
        then
            log::addMessage "installing gpg key '$keyId'"

            buildDir="$( mktemp -d )"
            gpg --homedir "$buildDir" \
                --no-default-keyring \
                --keyring "$buildDir/key.gpg" \
                --keyserver keyserver.ubuntu.com \
                --recv-keys "$keyId" && \
            sudo::run "$requirePasswordWarningMessage" \
                install -g root -o root -m 0644 "$buildDir/key.gpg" "$keyring" || exitCode=$?

            rm -r "$buildDir"

            [[ $exitCode -eq 0 ]] || return $exitCode
        elif [[ -v keyURL && -n "$keyURL" ]]
        then
            buildDir="$( mktemp -d )"

            log::addMessage "installing gpg key from url '$keyURL'"
            download::get "$keyURL" "$buildDir/tmp" && \
            gpg --dearmor <"$buildDir/tmp" > "$buildDir/key.gpg" && \
            sudo::run "$requirePasswordWarningMessage" \
                install -g root -o root -m 0644 "$buildDir/key.gpg" "$keyring" || exitCode=$?

            rm -r "$buildDir"

            [[ $exitCode -eq 0 ]] || return $exitCode
        fi
    fi


    [[ -v suites ]] || suites="$( . /etc/os-release && echo "$VERSION_CODENAME" )"
    [[ -v components ]] || components='main'

    {
        printf 'Types: deb\n'
        printf 'URIs: %s\n' "$uri"
        printf 'Suites: %s\n' "$suites"
        if [[ -n $components ]]
        then
            printf 'Components: %s\n' "$components"
        fi
        if [[ -v keyring ]]
        then
            printf 'Signed-By: %s\n' "$keyring"
        fi
        printf 'Architectures: %s\n' "$( dpkg --print-architecture )"
    } | sudo::run "$requirePasswordWarningMessage" tee /etc/apt/sources.list.d/"$packageName".sources > /dev/null

    return 0
}
declare -rf packageManager::installRepository

function packageManager::installRepository::usage() { # $0 <function-name>
    local -r functionName="$1"

    printf 'usage: '
    output::color::green "$functionName"
    printf '['
    output::color::yellow "--components $( output::color::underline "<components>")"
    printf '] ['
    output::color::yellow "--key-id $( output::color::underline "<key>")"
    printf '] ['
    output::color::yellow "--key-url $( output::color::underline "<url>")"
    printf '] ['
    output::color::yellow "--suites $( output::color::underline "<suites>")"
}
declare -rf packageManager::installRepository::usage

function packageManager::isInstalled() { # $0 [<package> ...]
    while [[ $# -gt 0 ]]
    do
        dpkg -s "$1" &>/dev/null || return 1
        shift
    done

    return 0
}
declare -rf packageManager::isInstalled

function packageManager::remove() { # $0 <sudo-message> [<package> ...]
    local -r requirePasswordWarningMessage="$1"
    local -a packages=()

    shift 1

    for package in "$@"
    do
        if packageManager::isInstalled "$package"
        then
            packages+=("$package")
        fi
    done

    if [[ ${#packages[@]} -gt 0 ]]
    then
        sudo::run "$requirePasswordWarningMessage" \
            DEBIAN_FRONTEND=noninteractive \
            apt-get \
                -y \
                --auto-remove \
                purge "${packages[@]}" |& log::tee

        packageManager::clean "$requirePasswordWarningMessage"
    fi
}
declare -rf packageManager::remove

function packageManager::snapInstall() { # $0 <sudo-message> [<package> ...]
    local -r requirePasswordWarningMessage="$1"

    shift 1

    if ! command -v snap &>/dev/null
    then
        packageManager::install "$requirePasswordWarningMessage" snapd
    fi

    sudo::run "$requirePasswordWarningMessage" snap install "$@"
}
declare -rf packageManager::snapInstall

function packageManager::upgrade() { # $0 <sudo-message>
    local -r requirePasswordWarningMessage="$1"

    sudo::run "$requirePasswordWarningMessage" \
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y -q --update dist-upgrade |& log::tee true
    packageManager::clean "$requirePasswordWarningMessage"
}
declare -rf packageManager::upgrade

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

source "$PROJECT_ROOT/lib/download.lib.sh"
source "$PROJECT_ROOT/lib/log.lib.sh"
source "$PROJECT_ROOT/lib/output.lib.sh"
source "$PROJECT_ROOT/lib/sudo.lib.sh"
