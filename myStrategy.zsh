#config
zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }

ZSH_AUTOSUGGEST_STRATEGY=my_default

_zsh_autosuggest_strategy_my_default() {
    # Reset options to defaults and enable LOCAL_OPTIONS
    emulate -L zsh

    # Enable globbing flags so that we can use (#m)
    setopt EXTENDED_GLOB

	# Escape backslashes and all of the glob operators so we can use
	# this string as a pattern to search the $history associative array.
	# - (#m) globbing flag enables setting references for match data
	# TODO: Use (b) flag when we can drop support for zsh older than v5.0.8
    local prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}"

    local cmd=${${(z)prefix}[1]}
    local arg=${${(z)prefix}[2]}
    typeset -g otherHint

    if [ $cmd = 'cd' -a -n "$arg" ]; then 
        local dirs=()
        local c=1
        for file in *; do
            if [ -d $file ]; then
                dirs[$c]=$file
                ((c++))
            fi
        done
        local dir=${dirs[(r)${arg}*]}  #查找当前目录
        if [ -n "$dir" ]; then 
            typeset -g suggestion="cd $dir"
            return
        else  #转成大写尝试
            dir=${dirs[(r)${(U)arg}*]}
            if [ -n "$dir" ]; then 
                BUFFER="cd ${(U)arg}"
                typeset -g suggestion="cd $dir"
                return
            fi
        fi
    fi

    local hint=${history[(r)${prefix}*]}
    local blank=' '
    #过滤无效记录
    typeset -g suggestion=""
    if (( $hint[(I)$blank] > 0 )); then
        [ -n "$(whence ${${(z)hint}[1]})" ] && typeset -g suggestion="$hint"
    else
        [ -n "$(whence $hint)" ] && typeset -g suggestion="$hint"
    fi
    #如果是历史记录是cd命令且目标目录不在当前目录下，则移除此提示
    if (( $#suggestion )) && (( $suggestion[(I)$blank] )) && [[ ${${(z)suggestion}[1]} == 'cd' ]] {
        local dir=${${(z)suggestion}[2]}
        dir="${dirs[(r)$dir]}"
        (( $#dir == 0 )) && typeset -g suggestion=""
    }

	# Get the history items that match
	# - (r) subscript flag makes the pattern match on values
}
