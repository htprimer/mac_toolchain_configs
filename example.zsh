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

alias axcbuild='osascript -e "tell application \"Xcode\" to build active workspace document"'
alias axcrun='osascript -e "tell application \"Xcode\" to run active workspace document"'

function debug() {
    osascript -e "display dialog \"$1 $2 $3\"" >> /dev/null
}

function xcode() {
    if (( $#1 <= 0 )) {
        open /Applications/Xcode.app
    } elif [[ $1 == 'space' ]] {
        open -a Xcode *.xcworkspace
    } elif [[ $1 == 'project' ]] {
        open -a Xcode *.xcodeproj
    } elif [[ $1 == 'quit' ]] {
        osascript -e "tell application \"Xcode\" to run quit"
    }  else
        open -a Xcode $1
    fi
}
