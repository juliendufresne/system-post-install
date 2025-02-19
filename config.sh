# shellcheck disable=SC2034

# using indexed array as associative array don't preserve ordering
declare -a softwareSettings
# "ON" means it's installed by default
# "OFF" means it's not installed by default
softwareSettings+=("discord" "OFF")            # Chat for Communities and Friends
softwareSettings+=("docker-desktop" "ON")      # build and share containerized applications
softwareSettings+=("filezilla" "OFF")          # Full-featured graphical FTP/FTPS/SFTP client
softwareSettings+=("fish" "ON")                # command-line shell for modern systems
softwareSettings+=("git" "ON")                 # fast, scalable, distributed revision control system
softwareSettings+=("gpg" "ON")                 # tool for secure communication and data storage
softwareSettings+=("htop" "ON")                # interactive processes viewer
softwareSettings+=("httpie" "OFF")             # CLI, cURL-like tool for humans
softwareSettings+=("jetbrains-toolbox" "ON")   # complete IDE
softwareSettings+=("keeweb" "ON")              # Free Password Manager Compatible with KeePass
softwareSettings+=("meld" "ON")                # graphical tool to diff and merge files
softwareSettings+=("openssh-client" "ON")      # secure shell (SSH) client
softwareSettings+=("pass" "ON")                # the standard unix password manager
softwareSettings+=("slack-desktop" "OFF")      # Slack Desktop
softwareSettings+=("spotify" "ON")             # music for everyone
softwareSettings+=("sublime-text" "ON")        # sophisticated text editor
softwareSettings+=("terminator" "ON")          # multiple GNOME terminals in one window
softwareSettings+=("tree" "ON")                # displays an indented directory tree, in color
softwareSettings+=("vim" "ON")                 # Vi IMproved - enhanced vi editor
softwareSettings+=("vlc" "ON")                 # multimedia player and streamer

declare sudoPasswordLess=false

declare upgradeSystemPreference=true

# can not use `command -v fish` as it's probably not installed yet
declare defaultShell="fish"

declare workspaceRootDir="$HOME/Workspace"
declare workspaceConfigureGitUser=true
declare workspaceGenerateGPGKey=true
declare workspaceGenerateSSHKey=true
