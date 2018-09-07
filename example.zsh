# You can put files here to add functionality separated per file, which
# will be ignored by git.
# Files on the custom/ directory will be automatically loaded by the init
# script, in alphabetical order.

# For example: add yourself some shortcuts to projects you often work on.
#
# brainstormr=~/Projects/development/planetargon/brainstormr
# cd $brainstormr
#

# zsh config
ZSH_AUTOSUGGEST_STRATEGY=match_prev_cmd
zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }

alias axcbuild='osascript -e "tell application \"Xcode\" to build active workspace document"'
alias axcrun='osascript -e "tell application \"Xcode\" to run active workspace document"'

function xcode() {
    if [ -z $1 ]; then
        open /Applications/Xcode.app
    else
        open -a Xcode $1
    fi
}
