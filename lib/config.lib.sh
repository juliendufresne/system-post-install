[[ "$( type -t config::configFilePath || true )" != 'function' ]] || return 0

# ——— Functions definition —————————————————————————————————————————————————————

function config::configFilePath() { # $0
    printf '%s\n' "$PROJECT_ROOT/config.sh"
}
declare -rf config::configFilePath

function config::saveBool() { # $0 <var-name> <value>
    local name="$1"
    local value="$2"

    local configFile

    configFile="$( config::configFilePath )"

    if grep -q "declare $name=$value\$" "$configFile"
    then
        return 0
    fi

    if ! grep -q "declare $name=" "$configFile"
    then
        printf 'declare %s=%s\n' "$name" "$value" >> "$configFile"
    else
        sed -E -i 's/(declare '"$name"')=.*$/\1='"$value"'/' "$configFile" || return 0
    fi

    return 0
}
declare -rf config::saveBool

function config::shell::getDefault() { # $0
    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    [[ -v defaultShell ]] || local defaultShell='bash'

    printf '%s' "$defaultShell"
}
declare -rf config::shell::getDefault

function config::shell::saveDefault() { # $0 <value>
    local value="$1"

    local configFile

    configFile="$( config::configFilePath )"
    # shellcheck source=../config.sh
    source "$configFile"

    if [[ -v defaultShell && $defaultShell == "$value" ]]
    then
        return 0
    fi

    if ! grep -q 'declare defaultShell=' "$configFile"
    then
        printf 'declare defaultShell="%s"\n' "$value" >> "$configFile"
    else
        sed -E -i 's,declare defaultShell=.*$,declare defaultShell="'"$value"',' "$configFile" || return 0
    fi

    return 0
}
declare -rf config::shell::saveDefault

function config::software::choose() { # $0 <ref-array-var-name>
    local -n _selectedSoftwareList="$1"

    local -r bashOptions="$-"
    local -a menuOptions=()
    local -a softwareSettings
    local    configFile tmpConfigFile
    local    index selectedSoftwareName status

    _selectedSoftwareList=()

    if [[ "$( declare -p "${!_selectedSoftwareList}" )" != 'declare -a '* ]]
    then
        output::error "${FUNCNAME[0]}: first argument must be an indexed array."

        return 1
    fi

    configFile="$( config::configFilePath )"
    # shellcheck source=../config.sh
    source "$configFile"

    # »»» building menu ————————————————————————————————————————————————————————

    for ((index=0; index < ${#softwareSettings[@]}; index += 2))
    do
        menuOptions+=("${softwareSettings[$index]}")
        menuOptions+=("$( grep -e "^softwareSettings+=(\"${softwareSettings[$index]}\"" "$configFile" | sed 's/^.*#[[:space:]]*//' )")
        menuOptions+=("${softwareSettings[$index+1]}") # ON or OFF
    done

    # »»» pick software ————————————————————————————————————————————————————————

    if ! dialog::hasDialogRequirements
    then
        dialog::installDialogBox || return $?
    fi


    set +x
    # shellcheck disable=SC2207
    if ! _selectedSoftwareList=($( dialog::checklistMenu 'Software selection' 'Pick software to install' "${menuOptions[@]}" ))
    then
        set "-$bashOptions"
        return 221 # canceled
    fi
    set "-$bashOptions"

    # »»» updating config ——————————————————————————————————————————————————————

    # updating user choice
    tmpConfigFile="$( mktemp -u )"
    cp "$configFile" "$tmpConfigFile"

    for ((index=0; index < ${#softwareSettings[@]}; index += 2))
    do
        status='OFF'
        for selectedSoftwareName in "${_selectedSoftwareList[@]}"
        do
            if [[ ${softwareSettings[$index]} == "$selectedSoftwareName" ]]
            then
                status='ON'
                break
            fi
        done

        # no need to update if the choice is already default choice
        [[ ${softwareSettings[$index+1]} != "$status" ]] || continue

        # preserving comment alignment
        if [[ "$status" == 'OFF' ]]
        then
            status='"OFF")'
        else
            status='"ON")  '
        fi

        sed -E -i "s/^(softwareSettings\+=\(\"${softwareSettings[$index]}\" )\"(ON|OFF)\"\) /\1$status/" "$tmpConfigFile"
    done

    mv "$tmpConfigFile" "$configFile"

    return 0
}
declare -rf config::software::choose

function config::software::getPreference() { # $0 <ref-array-var-name>
    # shellcheck disable=SC2178
    local -n _selectedSoftwareList="$1"

    local -i index

    _selectedSoftwareList=()

    if [[ "$( declare -p "${!_selectedSoftwareList}" )" != 'declare -a '* ]]
    then
        output::error "${FUNCNAME[0]}: first argument must be an indexed array."

        return 1
    fi

    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    for ((index=0; index < ${#softwareSettings[@]}; index += 2))
    do
        if [[ ${softwareSettings[$index+1]} == 'ON' ]]
        then
            _selectedSoftwareList+=("${softwareSettings[$index]}")
        fi
    done

    return 0
}
declare -rf config::software::getPreference

function config::sudoPasswordLess::getPreference() { # $0
    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    [[ -v sudoPasswordLess ]] || local sudoPasswordLess=false

    printf '%s' "$sudoPasswordLess"
}
declare -rf config::sudoPasswordLess::getPreference

function config::sudoPasswordLess::savePreference() { # $0 <value>
    config::saveBool 'sudoPasswordLess' "$1"
}
declare -rf config::sudoPasswordLess::savePreference

function config::systemUpgrade::getPreference() { # $0
    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    [[ -v upgradeSystemPreference ]] || local upgradeSystemPreference=true

    printf '%s' "$upgradeSystemPreference"
}
declare -rf config::systemUpgrade::getPreference

function config::systemUpgrade::savePreference() { # $0 <value>
    config::saveBool 'upgradeSystemPreference' "$1"
}
declare -rf config::systemUpgrade::savePreference

function config::workspaceGenerateGPGKey::getPreference() { # $0
    local workspaceGenerateGPGKey

    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    [[ -v workspaceGenerateGPGKey ]] || local workspaceGenerateGPGKey=true

    printf '%s' "$workspaceGenerateGPGKey"
}
declare -rf config::workspaceGenerateGPGKey::getPreference

function config::workspaceGenerateGPGKey::savePreference() { # $0 <value>
    config::saveBool 'workspaceGenerateGPGKey' "$1"
}
declare -rf config::workspaceGenerateGPGKey::savePreference

function config::workspaceConfigureGitUser::getPreference() { # $0
    local workspaceConfigureGitUser

    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    [[ -v workspaceConfigureGitUser ]] || local workspaceConfigureGitUser=true

    printf '%s' "$workspaceConfigureGitUser"
}
declare -rf config::workspaceConfigureGitUser::getPreference

function config::workspaceConfigureGitUser::savePreference() { # $0 <value>
    config::saveBool 'workspaceConfigureGitUser' "$1"
}
declare -rf config::workspaceConfigureGitUser::savePreference

function config::workspaceGenerateSSHKey::getPreference() { # $0
    local workspaceGenerateSSHKey

    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    [[ -v workspaceGenerateSSHKey ]] || local workspaceGenerateSSHKey=true

    printf '%s' "$workspaceGenerateSSHKey"
}
declare -rf config::workspaceGenerateSSHKey::getPreference

function config::workspaceGenerateSSHKey::savePreference() { # $0 <value>
    config::saveBool 'workspaceGenerateSSHKey' "$1"
}
declare -rf config::workspaceGenerateSSHKey::savePreference

function config::workspaceRootDir::getPreference() { # $0
    local workspaceRootDir
    # shellcheck source=../config.sh
    source "$( config::configFilePath )"

    [[ -v workspaceRootDir ]] || local workspaceRootDir="$HOME"

    printf '%s' "$workspaceRootDir"
}
declare -rf config::workspaceRootDir::getPreference

function config::workspaceRootDir::savePreference() { # $0 <value>
    local value="$1"

    local configFile

    configFile="$( config::configFilePath )"
    # replace home directory to HOME variable
    value="${value/$HOME/\$HOME}"

    # can't source the config file otherwise HOME variable will be expanded
    if grep -q 'declare workspaceRootDir="'"$value"'"$' "$configFile"
    then
        return 0
    fi

    if ! grep -q 'declare workspaceRootDir=' "$configFile"
    then
        printf 'declare workspaceRootDir="%s"\n' "$value" >> "$configFile"
    else
        sed -E -i 's,declare workspaceRootDir=.*$,declare workspaceRootDir="'"$value"'",' "$configFile" || return 0
    fi

    return 0
}
declare -rf config::workspaceRootDir::savePreference

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

source "$PROJECT_ROOT/lib/dialog.lib.sh"
source "$PROJECT_ROOT/lib/output.lib.sh"
