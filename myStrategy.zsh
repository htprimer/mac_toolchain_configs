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

#重写显示方法
_zsh_autosuggest_suggest() {
    local suggestion="$1"

    if [[ -n "$suggestion" ]] && (( $#BUFFER )); then
        # local complete=$'\ncomplete'
        # todo 研究方向键选择
        local complete=''
        typeset -g linecmd="${suggestion#$BUFFER}"
        POSTDISPLAY="$linecmd$complete"
    else
        unset POSTDISPLAY
    fi
}

#重写接受方法
_zsh_autosuggest_accept() {
    local -i max_cursor_pos=$#BUFFER

    # When vicmd keymap is active, the cursor can't move all the way
    # to the end of the buffer
    if [[ "$KEYMAP" = "vicmd" ]]; then
        max_cursor_pos=$((max_cursor_pos - 1))
    fi

    # Only accept if the cursor is at the end of the buffer
    if [[ $CURSOR = $max_cursor_pos ]]; then
        # Add the suggestion to the buffer
        BUFFER="$BUFFER$linecmd"

        # Remove the suggestion
        unset POSTDISPLAY
        unset linecmd 

        # Move the cursor to the end of the buffer
        CURSOR=${#BUFFER}
    fi

    _zsh_autosuggest_invoke_original_widget $@
}
